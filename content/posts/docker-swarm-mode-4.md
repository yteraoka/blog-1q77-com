---
title: 'Docker Swarm mode を知る (secret)'
date: Sat, 24 Mar 2018 15:59:18 +0000
draft: false
tags: ['Docker', 'Swarm']
---

今回は [docker secret](https://docs.docker.com/engine/reference/commandline/secret/) を使ってみます。 [Manage sensitive data with Docker secrets](https://docs.docker.com/engine/swarm/secrets/) に使い方が書かれています。Kubernetes の [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/) とかなり似てます。 `docker secret` コマンドの syntax は次のようになってます。

```
$ docker secret --help

Usage:  docker secret COMMAND

Manage Docker secrets

Options:
      --help   Print usage

Commands:
  create      Create a secret from a file or STDIN as content
  inspect     Display detailed information on one or more secrets
  ls          List secrets
  rm          Remove one or more secrets

Run 'docker secret COMMAND --help' for more information on a command.
```

### Secret の登録

`docker secret create` で作成します。ファイルの中身を値として登録するか、ファイルの path として "`-`" を指定することで標準入力から値を読み取って登録します。

```
$ docker secret create --help

Usage:  docker secret create [OPTIONS] SECRET [file|-]

Create a secret from a file or STDIN as content

Options:
  -d, --driver string   Secret driver
      --help            Print usage
  -l, --label list      Secret labels
```

登録時に表示される文字列は作成した secret を指す ID です。

```
$ echo password | docker secret create mypass -
mhop3cx9kk5xuz4b95nokvzov
```

```
$ docker secret ls
ID                          NAME                DRIVER              CREATED             UPDATED
mhop3cx9kk5xuz4b95nokvzov   mypass                                  5 seconds ago       5 seconds ago
```

`docker secret inspect` で secret のメタ情報が確認ができます

```
$ docker secret inspect mypass
[
    {
        "ID": "mhop3cx9kk5xuz4b95nokvzov",
        "Version": {
            "Index": 16
        },
        "CreatedAt": "2018-03-24T14:41:50.123712806Z",
        "UpdatedAt": "2018-03-24T14:41:50.123712806Z",
        "Spec": {
            "Name": "mypass",
            "Labels": {}
        }
    }
]
```

ID でも名前でも確認できます。

```
$ docker secret inspect mhop3cx9kk5xuz4b95nokvzov
[
    {
        "ID": "mhop3cx9kk5xuz4b95nokvzov",
        "Version": {
            "Index": 16
        },
        "CreatedAt": "2018-03-24T14:41:50.123712806Z",
        "UpdatedAt": "2018-03-24T14:41:50.123712806Z",
        "Spec": {
            "Name": "mypass",
            "Labels": {}
        }
    }
]
```

同名の `secret` を複数作成することはできません

```
$ echo hogehoge | docker secret create mypass -
Error response from daemon: rpc error: code = AlreadyExists desc = secret mypass already exists
```

では値を更新したい場合はどうするかというと、`secret` は `service` で使うわけですが、どの secret をどんな名前で参照させるかを指定できるようになっているため、まず `app_passwd_v1` を `passwd` として参照するようにしておき、`docker service update` で `app_passwd_v2` を `passwd` で参照するように `service` を更新します。

### Service から secret を参照する

`secret` は `docker run` で起動するコンテナでは使えず、`service` を使う必要があります。

```
$ docker service create --detach --name nginx --secret mypass nginx:latest
wxmhxc0po5fxzbfh2i84ug2nf
```

```
$ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
622efaa68880        nginx:latest        "nginx -g 'daemon ..."   56 seconds ago      Up 56 seconds       80/tcp              nginx.1.zfcqa0ofjygrxe30jm1ftjb89
```

`/run/secrets/` に secret 名のファイルができます

```
$ docker exec 622efaa68880 cat //run/secrets/mypass
password
```

(Windows の git-bash を使ってるので無駄な "/" があります)

#### Service が参照する secret を入れ替える

先程説明した方法で `mypass` を更新してみます 新しく `mypass2` という名前の `secret` を作成する

```
$ echo hogehoge | docker secret create mypass2 -
6kuu6o995snvokzudp1m5y7f1
```

先程は `--secret` で `secret` 名を指定しただけでした。これは `secret` 名をそのまま `/run/secrets/` 下のファイル名として参照させることになりますが、`source` と `target` を別に指定することで `secret` 名と参照名を別にできます。

```
$ docker service update --secret-add source=mypass2,target=mypass --secret-rm mypass nginx
nginx
```

service が更新され、コンテナが生まれ変わりました

```
$ docker service ps nginx
ID                  NAME                IMAGE               NODE                DESIRED STATE       CURRENT STATE             ERROR               PORTS
rmj99vdjpipe        nginx.1             nginx:latest        myvm1               Running             Running 42 seconds ago
zfcqa0ofjygr         \_ nginx.1         nginx:latest        myvm1               Shutdown            Shutdown 43 seconds ago
```

`docker ps` で container id を確認して

```
$ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED              STATUS              PORTS               NAMES
7198b32c47a0        nginx:latest        "nginx -g 'daemon ..."   About a minute ago   Up About a minute   80/tcp              nginx.1.rmj99vdjpipevrhpo2walrmm2
```

`mypass` を確認してみます。更新されてますね。

```
$ docker exec 7198b32c47a0 cat //run/secrets/mypass
hogehoge
```

`docker service inspect` で確認してみます

```
$ docker service inspect nginx | jq .[].Spec.TaskTemplate.ContainerSpec.Secrets
[
  {
    "File": {
      "Name": "mypass",
      "UID": "0",
      "GID": "0",
      "Mode": 292
    },
    "SecretID": "6kuu6o995snvokzudp1m5y7f1",
    "SecretName": "mypass2"
  }
]
```

service は PreviousSpec に一つ前の情報も持っているのですね

```
$ docker service inspect nginx | jq .[].PreviousSpec.TaskTemplate.ContainerSpec.Secrets
[
  {
    "File": {
      "Name": "mypass",
      "UID": "0",
      "GID": "0",
      "Mode": 292
    },
    "SecretID": "mhop3cx9kk5xuz4b95nokvzov",
    "SecretName": "mypass"
  }
]
```

### Stack で secret を使う

次の内容で `docker-compose.yml` を用意します

```
version: '3.1'

services:
   db:
     image: mysql:latest
     volumes:
       - db_data:/var/lib/mysql
     environment:
       MYSQL_ROOT_PASSWORD_FILE: /run/secrets/db_root_password
       MYSQL_DATABASE: wordpress
       MYSQL_USER: wordpress
       MYSQL_PASSWORD_FILE: /run/secrets/db_password
     secrets:
       - db_root_password
       - db_password

   wordpress:
     depends_on:
       - db
     image: wordpress:latest
     ports:
       - "8000:80"
     environment:
       WORDPRESS_DB_HOST: db:3306
       WORDPRESS_DB_USER: wordpress
       WORDPRESS_DB_PASSWORD_FILE: /run/secrets/db_password
     secrets:
       - db_password


secrets:
   db_password:
     file: db_password.txt
   db_root_password:
     file: db_root_password.txt

volumes:
    db_data:
```

`db_password.txt`, `db_root_password.txt` というパスワードの書かれたファイルを用意して `docker stack deploy` で deploy します

```
$ docker stack deploy --compose-file docker-compose.yml secrets-test
Creating network secrets-test_default
Creating service secrets-test_wordpress
Creating service secrets-test_db
```

`secret` が作成されています `stack` 名が `secret` 名の prefix として付加されていますね

```
$ docker secret ls
ID                          NAME                            DRIVER              CREATED             UPDATED
mhop3cx9kk5xuz4b95nokvzov   mypass                                              About an hour ago   About an hour ago
6kuu6o995snvokzudp1m5y7f1   mypass2                                             16 minutes ago      16 minutes ago
jl70yk1b4ydo5rhc5mol7pybp   secrets-test_db_password                            20 seconds ago      20 seconds ago
in18f83ord099qiu2q8r4ctkc   secrets-test_db_root_password                       20 seconds ago      20 seconds ago
```

`docker ps` で container id を確認

```
$ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
c9ae594886b9        mysql:latest        "docker-entrypoint..."   3 minutes ago       Up 3 minutes        3306/tcp            secrets-test_db.1.35sznd2qiyucfstwepz85o22h
7198b32c47a0        nginx:latest        "nginx -g 'daemon ..."   18 minutes ago      Up 18 minutes       80/tcp              nginx.1.rmj99vdjpipevrhpo2walrmm2
```

ファイルがありますね

```
$ docker exec c9ae594886b9 ls //run/secrets/
db_password
db_root_password
```

中身も確認できました

```
$ docker exec c9ae594886b9 cat //run/secrets/db_password
DbAppPass
```

```
$ docker exec c9ae594886b9 cat //run/secrets/db_root_password
DbRootPass
```

パスワードファイルを書き換えて deploy すると secret のパスワードは更新されるでしょうか？

```
$ cat db_password.txt
DbAppPass2
```

```
$ docker stack deploy --compose-file docker-compose.yml  secrets-test
failed to update secret secrets-test_db_password: Error response from daemon: rpc error: code = InvalidArgument desc = only updates to Labels are allowed
```

ダメでした... `services` の `secrets` には [LONG SYNTAX](https://docs.docker.com/compose/compose-file/#long-syntax-2) があり、`source`, `target`, `uid`, `gid`, `mode` が指定可能でした。そこで、`docker-compose.yml` を次のように書き換えて deploy すると更新できました。

```
version: '3.1'

services:
   db:
     image: mysql:latest
     volumes:
       - db_data:/var/lib/mysql
     environment:
       MYSQL_ROOT_PASSWORD_FILE: /run/secrets/db_root_password
       MYSQL_DATABASE: wordpress
       MYSQL_USER: wordpress
       MYSQL_PASSWORD_FILE: /run/secrets/db_password
     secrets:
       - db_root_password
       - source: db_password2
         target: db_password

   wordpress:
     depends_on:
       - db
     image: wordpress:latest
     ports:
       - "8000:80"
     environment:
       WORDPRESS_DB_HOST: db:3306
       WORDPRESS_DB_USER: wordpress
       WORDPRESS_DB_PASSWORD_FILE: /run/secrets/db_password
     secrets:
       - source: db_password2
         target: db_password


secrets:
   db_password2:
     file: db_password2.txt
   db_root_password:
     file: db_root_password.txt

volumes:
    db_data:
```

更新のため、再 deploy

```
$ docker stack deploy --compose-file docker-compose.yml  secrets-test
Updating service secrets-test_db (id: thimv598po993rnbetm85z7kt)
Updating service secrets-test_wordpress (id: jkje0u6n7z690zm0y34p9j2go)
```

secret が増えました

```
$ docker secret ls
ID                          NAME                            DRIVER              CREATED             UPDATED
mhop3cx9kk5xuz4b95nokvzov   mypass                                              About an hour ago   About an hour ago
6kuu6o995snvokzudp1m5y7f1   mypass2                                             31 minutes ago      31 minutes ago
jl70yk1b4ydo5rhc5mol7pybp   secrets-test_db_password                            15 minutes ago      15 minutes ago
m8drh3ldgnt0vstft2xewte78   secrets-test_db_password2                           39 seconds ago      39 seconds ago
in18f83ord099qiu2q8r4ctkc   secrets-test_db_root_password                       15 minutes ago      39 seconds ago
```

コンテナが更新されて

```
$ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
722657b03d5f        mysql:latest        "docker-entrypoint..."   42 seconds ago      Up 36 seconds       3306/tcp            secrets-test_db.1.mw3wxtfgagoei3bxd8c3yfsh5
7198b32c47a0        nginx:latest        "nginx -g 'daemon ..."   29 minutes ago      Up 29 minutes       80/tcp              nginx.1.rmj99vdjpipevrhpo2walrmm2
```

パスワードも更新されました。まあ、コンテナ起動時にこの変更が DB に反映されるのかというのは別問題だけどね

```
$ docker exec 722657b03d5f cat //run/secrets/db_password
DbAppPass2
```

以上
