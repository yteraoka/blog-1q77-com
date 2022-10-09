---
title: 'Docker Toolbox for Windows の使い方'
date: Sun, 26 Nov 2017 14:05:38 +0000
draft: false
tags: ['Docker', 'VirtualBox', 'Windows']
---

普段使いの家の端末を Windows にしてみたので、使い勝手改善中。 Docker Toolbox for Windows についてのメモ。 インストールについては公式ドキュメントを参照 [Install Docker Toolbox on Windows](https://docs.docker.com/toolbox/toolbox_install_windows/) VirtualBox がインストールされ、ゲスト OS としての Linux を docker machine として使います。 デスクトップに「Docker Quickstart Terminal」というショートカットが作成されており、これを開くと

```
"C:\\Program Files\\Git\\bin\\bash.exe" --login -i "C:\\Program Files\\Docker Toolbox\\start.sh"
```

というコマンドが実行されます。 この bash 環境では `/` が

```
C:\\Program Files\\Git
```

になっており、`mingw64/`、`bin/`、`usr/bin/` に各種 unix コマンドが入ってます。 `start.sh` は docker-machine が存在しなければ作成し、起動していなければ起動して docker-machine env で得られる環境変数をセットした状態にしてくれます。 ですからこの bash 内ではすぐに docker コマンドでコンテナの起動などができます。 docker コンテナは boot2docker イメージから作られた仮想サーバー内で実行されるため、コンテナの使用するメモリなどはこの仮想サーバーの上限の影響を受けます。 次のように docker-machine create を行うことでメモリやストレージのサイズを指定可能です。もちろん、作成後に直接 VirtualBox 上の設定を変更することも可能。

```
$ docker-machine create --driver virtualbox --virtualbox-memory 2048 --virtualbox-disk-size 40000 {machine-name}
```

「Docker Quickstart Terminal」を使わずともコマンドプロンプトや PowerShell からも操作可能です。もちろん [Cmder](/2017/11/using-cmder/) でも。docker コマンドを使うには環境変数の設定が必要ですが、`docker-machine env {machine-name}` で出力されるものを指定します。 Windows ではコメントとして次のような出力もされます。

```
REM Run this command to configure your shell:
REM     @FOR /f "tokens=*" %i IN ('docker-machine env') DO @%i
```

2行目の `@FOR /f "tokens=*" %i IN ('docker-machine env') DO @%i` をコピペするだけで一括で設定されます。

```
docker run -it -d -P --rm nginx
```

とすれば nginx コンテナが起動され `docker ps` で port がわかる（`docker port CONTAINER_NAME` でも可）

```
CONTAINER ID  IMAGE  COMMAND                 CREATED        STATUS        PORTS                  NAMES
f8942efa52e8  nginx  "nginx -g 'daemon ..."  7 seconds ago  Up 3 seconds  0.0.0.0:32768->80/tcp 
 modest_volhard
```

`docker-machine ip` で docker ホストのIPアドレスがわかるため、これを組み合わせることで http://192.168.99.100:3276/ で nginx にアクセスできることがわかる。

* [Docker Machine command-line reference](https://docs.docker.com/machine/reference/)
* [Docker Machine driver reference (Oracle VirtualBox)](https://docs.docker.com/machine/drivers/virtualbox/)
