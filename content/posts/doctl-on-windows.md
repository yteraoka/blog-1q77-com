---
title: 'Windows で doctl を使う'
date: Wed, 20 Dec 2017 15:27:08 +0000
draft: false
tags: ['DigitalOcean', 'Windows']
---

DigitalOcean にはサーバーの作成、削除などの操作をコマンドラインで行うツール [https://github.com/digitalocean/doctl](https://github.com/digitalocean/doctl) があります。 Linux での使い方は過去にも書いてきました。近頃 Windows 使いとなっているので Windows で git-bash から使おうと思いました。 doctl は go で書かれており、マルチプラットフォームのバイナリが用意されているので Windows 用をダウンロードして展開すればすぐに使えます。 私の環境では $PATH に `/c/Users/ytera/bin` が入っていたので `doctl.exe` をそこに置きました。 そして `doctl auth init` を実行すれば token を聞かれて `$HOME/.config/doctl/config.yaml` が作成されるはずでしたが `git-bash` では期待の動作となりませんでした...

```
$ doctl auth init
initialize configuration

Usage:
  doctl auth init [flags]

Flags:
  -h, --help   help for init

Global Flags:
  -t, --access-token string   API V2 Access Token
  -u, --api-url string        Override default API V2 endpoint
  -c, --config string         config file (default is $HOME/.config/doctl/config.yaml)
  -o, --output string         output format [text|json] (default "text")
      --trace                 trace api access
  -v, --verbose               verbose output

Error: unable to read DigitalOcean access token: unknown terminal
```

そこで `cmd.exe` から実行してみました

```
C:\Users\ytera\bin>doctl auth init
DigitalOcean access token: bc522054e5045088a089321ca4e900de33ae383b692bbe1f3507bf50a4747513

Validating token... OK
```

(もちろん上記の token はダミーです `dd if=/dev/urandom count=1 bs=512 | sha256sum` てな感じで生成) さて、`config.yaml` はいずこに？ `C:\Users\ytera\.config` とか `C:\Users\ytera\_config` といったフォルダは存在しません。 答えは `LOCALAPPDATA=C:\Users\ytera\AppData\Local` でした。 `C:\Users\ytera\AppData\Local\doctl\config\config.yaml` ここまでできたら以降は `git-bash` からでも操作できました。 実は `git-bash` でも `winpty` を使えば良いのでした。

```
$ winpty doctl auth init
DigitalOcean access token: bc522054e5045088a089321ca4e900de33ae383b692bbe1f3507bf50a4747513

Validating token... OK
```

### イメージの確認

Docker のサーバーを立ち上げたいのでインストール済みのイメージ（アプリケーション）を使います

```
$ doctl compute image list-application --public
ID          Name                               Type        Distribution    Slug                   Public    Min Disk
24232319    Ruby-on-Rails on 16.04             snapshot    Ubuntu          ruby-on-rails-16-04    true      20
24976861    Dokku 0.9.4 on 16.04               snapshot    Ubuntu          dokku-16-04            true      20
25399919    Discourse 2.0.20170531 on 16.04    snapshot    Ubuntu          discourse-16-04        true      40
27223373    MongoDB 3.4.7 on 16.04             snapshot    Ubuntu          mongodb-16-04          true      20
27419663    Machine Learning and AI            snapshot    Ubuntu          ml-16-04               true      20
27768998    MySQL on 16.04                     snapshot    Ubuntu          mysql-16-04            true      20
28008792    GitLab 10.0.0-ce.0 on 16.04        snapshot    Ubuntu          gitlab-16-04           true      60
29160863    NodeJS 6.11.5 on 16.04             snapshot    Ubuntu          node-16-04             true      20
29160891    Ghost on 16.04                     snapshot    Ubuntu          ghost-16-04            true      30
29160892    LAMP on 16.04                      snapshot    Ubuntu          lamp-16-04             true      20
29160902    Django 1.8.7 on 16.04              snapshot    Ubuntu          django-16-04           true      20
29160903    Docker 17.09.0-ce on 16.04         snapshot    Ubuntu          docker-16-04           true      20
29160904    PhpMyAdmin on 16.04                snapshot    Ubuntu          phpmyadmin-16-04       true      20
29160905    WordPress 4.8.3 on 16.04           snapshot    Ubuntu          wordpress-16-04        true      30
29160933    MEAN on 16.04                      snapshot    Ubuntu          mean-16-04             true      30
29161212    LEMP on 16.04                      snapshot    Ubuntu          lemp-16-04             true      20
```

作成時にイメージ(`--image`)として `docker-16-04` を指定すれば Docker インストール済みの Ubuntu 16.04 が起動します

### 公開鍵の登録

```
$ doctl compute ssh-key import vaio-win --public-key-file ~/.ssh/id_rsa.pub
ID          Name        FingerPrint
12345678    vaio-win    91:ad:57:b2:f6:23:e3:41:0d:3d:a8:e6:fb:a8:a3:33
```

### Droplet の作成

```
doctl compute droplet create testsv01 \
  --image docker-16-04 \
  --region sgp1 \
  --size 2gb \
  --ssh-keys 12345678
```

`--wait` をつけると起動してくるまで待たされます `doctl compute droplet list` で droplet のリストが確認できます。`Status` が `new` から `active` になれば ssh でログインできます region は `doctl compute region list` で、size は `doctl compute size list` で確認できます

### SSH でログイン

Linux であれば `doctl compute ssh testsv01` で普通に使えるのですが、git-bash からは winpty をかます必要がありました。 ががが、ローカルエコーが効かない(?)ので諦めて `doctl compute droplet list --format Name,PublicIPv4` で IP アドレスを確認して普通に ssh します。 DigitalOcean では作成直後は root ユーザーで ssh します。```
ssh root@xxx.xxx.xxx.xxx
```

### サーバーの削除

停止しててもお金がかかるので不要になったら削除する

```
$ doctl compute droplet delete testsv01
Warning: Are you sure you want to delete droplet(s) (y/N) ? y
```

### 参考資料

[How To Use Doctl, the Official DigitalOcean Command-Line Client](https://www.digitalocean.com/community/tutorials/how-to-use-doctl-the-official-digitalocean-command-line-client)
