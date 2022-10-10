---
title: 'Docker Swarm mode を知る (stack)'
date: Sat, 17 Mar 2018 16:11:55 +0000
draft: false
tags: ['Docker', 'Swarm']
---

### docker-compose で stack を deploy する

[https://docs.docker.com/engine/swarm/stack-deploy/](https://docs.docker.com/engine/swarm/stack-deploy/) にあるサンプルアプリ、設定を用いて実際に動かしてみます。使ったコードは [https://github.com/yteraoka/stackdemo](https://github.com/yteraoka/stackdemo) に、イメージは [https://hub.docker.com/r/yteraoka/stackdemo/](https://hub.docker.com/r/yteraoka/stackdemo/) に。 次の内容の `docker-compose.yml` を用意し

```yaml
version: '3'

services:
  web:
    image: yteraoka/stackdemo
    build: .
    ports:
      - "8000:8000"
  redis:
    image: redis:alpine
```

`docker stack deploy` の `--compose-file` で指定して実行すると `docker-compose up` のような出力がされ、stack が作成されます ところで、上記のように YAML を書いておくと `docker-compose build` で image の build ができ、`docker-compose push` でその image を push できちゃうんですね。`image` に tag まで指定しておけばその tag がつけられる。便利！

```
root@swarm1:~/stackdemo# docker stack deploy --compose-file docker-compose.yml stackdemo
Ignoring unsupported options: build

Creating network stackdemo_default
Creating service stackdemo_web
Creating service stackdemo_redis
root@swarm1:~/stackdemo#
```

`docker stack ls` で stack に一覧が確認できます。各 stack にいくつの service が含まれるかも表示されます

```
root@swarm1:~/stackdemo# docker stack ls
NAME                SERVICES
stackdemo           2
root@swarm1:~/stackdemo#
```

web と redis のサービスが作成されています

```
root@swarm1:~/stackdemo# docker service ls
ID                  NAME                MODE                REPLICAS            IMAGE                       PORTS
tidm24xf7r2d        stackdemo_redis     replicated          1/1                 redis:alpine        
iv6u57cs5wfo        stackdemo_web       replicated          1/1                 yteraoka/stackdemo:latest   *:8000->8000/tcp
root@swarm1:~/stackdemo#
```

`docker stack ps` で指定 stack で実行されているコンテナ一覧が確認できます

```
root@swarm1:~/stackdemo# docker stack ps stackdemo
ID                  NAME                IMAGE                       NODE                DESIRED STATE       CURRENT STATE           ERROR               PORTS
o19qsdbdlkzq        stackdemo_redis.1   redis:alpine                swarm2              Running             Running 2 minutes ago
bua5sbi9t8di        stackdemo_web.1     yteraoka/stackdemo:latest   swarm1              Running             Running 2 minutes ago
root@swarm1:~/stackdemo#
```

`docker service ps` でサービス単位でも確認できます

```
root@swarm1:~/stackdemo# docker service ps stackdemo_web
ID                  NAME                IMAGE                       NODE                DESIRED STATE       CURRENT STATE                ERROR               PORTS
bua5sbi9t8di        stackdemo_web.1     yteraoka/stackdemo:latest   swarm1              Running             Running about a minute ago
root@swarm1:~/stackdemo#
```

```
root@swarm1:~/stackdemo# docker service ps stackdemo_redis
ID                  NAME                IMAGE               NODE                DESIRED STATE       CURRENT STATE                ERROR               PORTS
o19qsdbdlkzq        stackdemo_redis.1   redis:alpine        swarm2              Running             Running about a minute ago
root@swarm1:~/stackdemo#
```

`docker service logs` でサービスのコンテナ全部のログをまとめて確認できます、レプリカ数が複数になるとどのコンテナにアクセスが来るかわからないのでこれができると便利

```
root@swarm3:~# docker service logs -f stackdemo_web
stackdemo_web.1.bua5sbi9t8di@swarm1    |  * Running on http://0.0.0.0:8000/ (Press CTRL+C to quit)
stackdemo_web.1.bua5sbi9t8di@swarm1    |  * Restarting with stat
stackdemo_web.1.bua5sbi9t8di@swarm1    |  * Debugger is active!
stackdemo_web.1.bua5sbi9t8di@swarm1    |  * Debugger PIN: 298-511-468
stackdemo_web.1.bua5sbi9t8di@swarm1    | 10.255.0.2 - - [17/Mar/2018 10:07:01] "GET / HTTP/1.1" 200 -
stackdemo_web.1.bua5sbi9t8di@swarm1    | 10.255.0.2 - - [17/Mar/2018 10:07:02] "GET /favicon.ico HTTP/1.1" 404 -
stackdemo_web.1.bua5sbi9t8di@swarm1    | 10.255.0.2 - - [17/Mar/2018 10:07:51] "GET / HTTP/1.1" 200 -
stackdemo_web.1.bua5sbi9t8di@swarm1    | 10.255.0.2 - - [17/Mar/2018 10:07:51] "GET / HTTP/1.1" 200 -
```

ここまでのコマンドは manager node で実行する必要があります。worker node でも実行できる `docker ps` ではその node で動いているコンテナしか確認できません

```
root@swarm1:~/stackdemo# docker ps
CONTAINER ID        IMAGE                       COMMAND             CREATED             STATUS              PORTS               NAMES
c760d3d1d55e        yteraoka/stackdemo:latest   "python app.py"     11 seconds ago      Up 10 seconds                           stackdemo_web.1.bua5sbi9t8dimdiqnog0ukct8
root@swarm1:~/stackdemo#
```

### Service の更新

`stack` を使わないで作った `service` は `docker service update` でイメージの入れ替えなどを行いますが、`stack` の場合は `docker-compose.yml` を書き換えて作成時と同じコマンド `docker stack deploy --compose-file docker-compose.yml` を実行することで変更のあったサービスだけ更新が行われます 今回、redis を使っていますが、redis の方をいじらなければコンテナの入れ替えなどは行われないため web のアプリ側が新しくなってもデータは残っています レプリカ数やローリングアップデートに関する設定は [deploy](https://docs.docker.com/compose/compose-file/#deploy) という設定で行います レプリカ数を 3 にしてみます

```
root@swarm1:~/stackdemo# git diff docker-compose.yml
diff --git a/docker-compose.yml b/docker-compose.yml
index 5be7bcb..df3d5c8 100644
--- a/docker-compose.yml
+++ b/docker-compose.yml
@@ -6,5 +6,7 @@ services:
     build: .
     ports:
       - "8000:8000"
+    deploy:
+      replicas: 3
   redis:
     image: redis:alpine
root@swarm1:~/stackdemo#
```

更新のために `docker stack deploy` を再度実行します

```
root@swarm1:~/stackdemo# docker stack deploy --compose-file docker-compose.yml stackdemo
Ignoring unsupported options: build

Updating service stackdemo_web (id: iv6u57cs5wfo4tuuhle6dl7kv)
Updating service stackdemo_redis (id: tidm24xf7r2dqexa82wfiwrfu)
root@swarm1:~/stackdemo#
```

`stackdemo_web` に2つのコンテナが追加されました

```
root@swarm1:~/stackdemo# docker stack ps stackdemo
ID                  NAME                IMAGE                       NODE                DESIRED STATE       CURRENT STATE                    ERROR               PORTS
o19qsdbdlkzq        stackdemo_redis.1   redis:alpine                swarm2              Running             Running 2 hours ago
bua5sbi9t8di        stackdemo_web.1     yteraoka/stackdemo:latest   swarm1              Running             Running 2 hours ago
umzedgj5vhew        stackdemo_web.2     yteraoka/stackdemo:latest   swarm3              Running             Preparing 8 seconds ago
v4cbfc1kpnud        stackdemo_web.3     yteraoka/stackdemo:latest   swarm2              Running             Running less than a second ago
root@swarm1:~/stackdemo#
```

なかなか便利そうですね。stack の削除は `docker stack rm STACKNAME` です。
