---
title: 'Single node docker swarm でお手軽 rolling update'
date: Sat, 13 Oct 2018 05:00:02 +0000
draft: false
tags: ['Docker', 'Swarm']
---

https://kazeburo.hatenablog.com/entry/2018/10/09/174111

という記事をみて、次のようなブコメを書いたのですが実際には試したことがなかったのでやってみることにしました。

{{< x user="yteraoka" id="1050039408705994752" >}}


### 実行するアプリの準備

次のような構成のものを構築します

{{< figure src="single-node-docker-swarm.png" caption="構成" >}}

Global mode は kubernetes での DaemonSet のようなモードで、各ノードで起動されます。今回は1ノードしか用意しませんが、あとからノードを追加した場合にそのまま LB や DNS Round robin に追加できます。

### Docker swarm のセットアップ

セットアップと言ってもシングルノードなので docker がインストールされていれば次の1コマンドで完了です。node 追加の予定がないので listen-addr を 127.0.0.1 にしてあります。

```
docker swarm init --advertise-addr 127.0.0.1 --listen-addr 127.0.0.1:2377
```

`docker info` コマンドで swarm モードが有効になっているかどうかを確認できます

```
# docker info | grep ^Swarm
Swarm: active
```

[docker swarm init](https://docs.docker.com/engine/reference/commandline/swarm_init/)

### docker-compse でテスト

Swarm の [stack](https://docs.docker.com/engine/reference/commandline/stack/), [service](https://docs.docker.com/engine/reference/commandline/service/) は [docker-compose.yml](https://docs.docker.com/compose/compose-file/) からも作れるので、まず、[docker-compose](https://docs.docker.com/compose/) で動く状態にしてみます。コードは [https://github.com/yteraoka/single-node-swarm-test](https://github.com/yteraoka/single-node-swarm-test) に置いてあります。

```
git clone https://github.com/yteraoka/single-node-swarm-test.git
cd single-node-swarm-test
docker-compose up
```

```
# docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS                  PORTS                NAMES
d7f2b3a76c26        myapp-app:1.0.0     "./app"                  2 minutes ago       Up 2 minutes (healthy)                        single-node-swarm-test_app_1
ef520dbf910e        myapp-web:1.0.0     "nginx -g 'daemon of…"   2 minutes ago       Up 2 minutes (healthy)   0.0.0.0:80->80/tcp   single-node-swarm-test_web_1
```

起動したらブラウザで port 80 の `/` にアクセスすると

```
Version: 1.0.0
Hostname: d7f2b3a76c26
```

というのが返ってくるはずです。Hostname は app の Container ID です。`/color` にアクセスすると背景が緑色になります。あとでイメージの更新をする際にわかりやすいように色をつけてみました。

* [How services work](https://docs.docker.com/engine/swarm/how-swarm-mode-works/services/)
* [Deploy services to a swarm](https://docs.docker.com/engine/swarm/services/)

動作確認できたら Ctrl-C で停止して `docker-compose down` で不要なコンテナを削除します

### Stack の作成

service では build 済みのイメージファイルが必要です。今回は先程 `docker-compose up` を実行した際に build されているのでそれが使えます。なにか書き換えた場合は `docker-compose build` を実行することでイメージが作成されます

```
docker stack deploy --compose-file docker-compose.yml myapp
```

▼ `docker ps` で起動コンテナを確認

```
# docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS                           PORTS                NAMES
ea742c69bd61        myapp-web:1.0.0     "nginx -g 'daemon of…"   4 seconds ago       Up 3 seconds (health: starting)   0.0.0.0:80->80/tcp   myapp_web.2jqq8twdy8x549tyl0i2yokst.kenbu7e7519nk54tkeld20s4u
7fa3f88bb36f        myapp-app:1.0.0     "./app"                  8 seconds ago       Up 7 seconds (health: starting)                        myapp_app.2.6tmaj4j37srfn5lxqu836h0w1
4777a3a0d76d        myapp-app:1.0.0     "./app"                  8 seconds ago       Up 7 seconds (health: starting)                        myapp_app.1.h08cosodbi870jjt5555bart7
```

▼ stack の一覧確認

```
# docker stack ls
NAME                SERVICES            ORCHESTRATOR
myapp               2                   Swarm

```

▼ stack のコンテナを確認（nginx コンテナの HEALTHCHECK を見直す余地があるかな)

```
# docker stack ps myapp
ID                  NAME                                      IMAGE               NODE               DESIRED STATE       CURRENT STATE            ERROR                       PORTS
3thdglvcpbt5        myapp_web.2jqq8twdy8x549tyl0i2yokst       myapp-web:1.0.0     swarm              Running             Starting 2 seconds ago
rd3gxvhbvpuk         \_ myapp_web.2jqq8twdy8x549tyl0i2yokst   myapp-web:1.0.0     swarm              Shutdown            Failed 7 seconds ago     "task: non-zero exit (1)"
yia37uy212na         \_ myapp_web.2jqq8twdy8x549tyl0i2yokst   myapp-web:1.0.0     swarm              Shutdown            Failed 18 seconds ago    "task: non-zero exit (1)"
kenbu7e7519n         \_ myapp_web.2jqq8twdy8x549tyl0i2yokst   myapp-web:1.0.0     swarm              Shutdown            Failed 29 seconds ago    "task: non-zero exit (1)"
h08cosodbi87        myapp_app.1                               myapp-app:1.0.0     swarm              Running             Running 7 seconds ago
6tmaj4j37srf        myapp_app.2                               myapp-app:1.0.0     swarm              Running             Running 7 seconds ago
```

▼ stack 内の service の一覧確認

```
# docker stack services myapp
ID                  NAME                MODE                REPLICAS            IMAGE              PORTS
oup9x86rr54q        myapp_app           replicated          2/2                 myapp-app:1.0.0
qmk60m0sytxn        myapp_web           global              1/1                 myapp-web:1.0.0
```

▼ stack を限定しない service の一覧確認

```
# docker service ls
ID                  NAME                MODE                REPLICAS            IMAGE              PORTS
oup9x86rr54q        myapp_app           replicated          2/2                 myapp-app:1.0.0
qmk60m0sytxn        myapp_web           global              1/1                 myapp-web:1.0.0
```

### 新しい docker image の作成

[docker-compose.yml](https://github.com/yteraoka/single-node-swarm-test/blob/master/docker-compose.yml) を書き換えて新しいイメージファイルをビルドします。 app イメージのバージョンを 1.0.1 に書き換え、先程の背景色を緑から赤に変更します。

```diff
diff --git a/docker-compose.yml b/docker-compose.yml
index bc8bba3..5199cfe 100644
--- a/docker-compose.yml
+++ b/docker-compose.yml
@@ -15,13 +15,13 @@ services:
         protocol: tcp
         mode: host
   app:
-    image: myapp-app:1.0.0
+    image: myapp-app:1.0.1
     build:
       context: ./app
       dockerfile: Dockerfile
       args:
-        VERSION: 1.0.0
-        COLOR: green
+        VERSION: 1.0.1
+        COLOR: red
     networks:
       - overlay
     deploy:
```

▼ 書き換えたら `docker-compose build` でイメージをビルドします。(build-arg で渡す変数を go の compile 時に指定する変数として使ってアプリにバージョンとか色を埋め込んでます)

```
# docker-compose build
...
Successfully built 9cb764797c20
Successfully tagged myapp-app:1.0.1
```

```
# docker image ls | grep myapp-app
myapp-app           1.0.1               9cb764797c20        23 seconds ago      10.8MB
myapp-app           1.0.0               ca6303e343e2        About an hour ago   10.8MB
```

余談：今回、テストアプリを Go で書いたので、イメージを小さくするために [multistage-build](https://docs.docker.com/develop/develop-images/multistage-build/) を試してみました。scratch じゃなくて alpine をベースにしましたけど

### イメージの入れ替え

`docker service update` でイメージを入れ替えます

```
docker service update myapp_app --image myapp-app:1.0.1
```

WARNING が出ていますが、これは本来 swarm は複数 node で実行されるものなので、image は registry にアップしてねということですね (`docker service create --name registry --publish published=5000,target=5000 registry:2` で swarm 内に registry サービスを作って、`docker-compose push` でプッシュすることも可能 `docker-compose.yml` はイジる必要があります)

```
# docker service update myapp_app --image myapp-app:1.0.1
image myapp-app:1.0.1 could not be accessed on a registry to record
its digest. Each node will access myapp-app:1.0.1 independently,
possibly leading to different nodes running different
versions of the image.

myapp_app
overall progress: 0 out of 2 tasks
1/2: starting
2/2:
```

順に入れ替えられていきます

```
myapp_app
overall progress: 2 out of 2 tasks
1/2: running
2/2: running
verify: Service converged
```

▼ `docker service ps` で更新などの履歴が確認できます

```
# docker service ps myapp_app
ID                  NAME                IMAGE               NODE                DESIRED STATE      CURRENT STATE            ERROR               PORTS
iu6nmiijnxby        myapp_app.1         myapp-app:1.0.1     swarm               Running            Running 2 minutes ago
h08cosodbi87         \_ myapp_app.1     myapp-app:1.0.0     swarm               Shutdown           Shutdown 2 minutes ago
896sinhjy4r4        myapp_app.2         myapp-app:1.0.1     swarm               Running            Running 2 minutes ago
6tmaj4j37srf         \_ myapp_app.2     myapp-app:1.0.0     swarm               Shutdown           Shutdown 3 minutes ago
```

これでまた port 80 の `/color` にアクセスすると背景が赤色になっています。バージョンの部分も 1.0.1 になっています

```
Version: 1.0.1
Hostname: 0597b98c6ff4
```

しかし、Chrome でアクセスすると2つの app コンテナが起動しているのに毎回同じ Hostname (Container ID) しか表示されません。これは毎回 `/favicon.ico` へもアクセスしていて、2 アクセスずつしているからでした

`docker service update` には他にもたくさん[オプション](https://docs.docker.com/engine/reference/commandline/service_update/#options)があります

stack を使っているので docker-compose.yml の image を書き換える、もしくは環境変数で指定することにして、再度 `docker stack deploy` を実行することでも image の更新が可能です。さらに、image だけじゃなくて replica 数だったり、メモリのリミットとか各種設定の更新にも使えます。deploy.update\_config.order を start-first にしておくと replicas が 1 の場合にも downtime をなくせます。

### rollback

新しいバージョンがそもそも起動しないとかであれば自動で rollback させたりもできるようですが、そうではないなんらかの不具合があって一つ前のバージョンに戻したいという場合は

```
docker service rollback myapp_app
```

とするだけで戻せます。ただし、一つ前に戻すだけで、rollback 後の一つ前は戻す必要のあった問題のあるバージョンになるので2度続けて実行するのは危険です。イメージ入れ替えだけだから前のバージョンがわかっているなら (`docker service ps myapp_app` すればわかる) そのイメージを指定するのが良いかも

### 実行コンテナ数を増減させる

service で実行するコンテナの数は `docker service scale` で変更することができます。2つだった app コンテナを 3 つにしてみます

```
docker service scale myapp_app=3
```

```
# docker service ps myapp_app
ID                  NAME                IMAGE               NODE                DESIRED STATE      CURRENT STATE             ERROR               PORTS
iu6nmiijnxby        myapp_app.1         myapp-app:1.0.1     swarm               Running            Running 9 minutes ago
h08cosodbi87         \_ myapp_app.1     myapp-app:1.0.0     swarm               Shutdown           Shutdown 9 minutes ago
896sinhjy4r4        myapp_app.2         myapp-app:1.0.1     swarm               Running            Running 9 minutes ago
6tmaj4j37srf         \_ myapp_app.2     myapp-app:1.0.0     swarm               Shutdown           Shutdown 10 minutes ago
bi3v0wo0m1fi        myapp_app.3         myapp-app:1.0.1     swarm               Running            Running 13 seconds ago
```

コンテナが3つになったので、Chrome でもアクセスの度に Hostname (Container ID) が変わることが確認できます

更新は順番に行われますが、同時にいくつのコンテナを入れ替えるのか(`--update-parallelism`)、更新間隔(`--update-delay`)をどうするかなども調整可能です。 エラーが続く場合に自動でロールバックさせる機能もあります(`--update-failure-action`など)。

* [Apply rolling updates to a service](https://docs.docker.com/engine/swarm/swarm-tutorial/rolling-update/)

### イメージ更新時に downtime はある？

```
while : ; do
  curl -so /dev/null -w "%{http_code} %{time_total}\n" -m 5 http://localhost/
done
```

を実行しながらイメージの更新をしてみてもダウンタイムはありませんでした。 が、nginx コンテナの HEALTHCHECK 実行時になんかレスポンスが悪くなるのが気になるな。 `docker events` で見てると、このログが出るときにレスポンスが1秒超えることがある。なんでだろ？

```
2018-10-13T04:31:04.542378009Z container exec_create: /bin/sh -c curl -f http://127.0.0.1/healthcheck || exit 1 fc4105bc721c89956d358d078d8f689110e68cd0b02d3e48fd4074cb7d0f635f (com.docker.stack.namespace=myapp, com.docker.swarm.node.id=2jqq8twdy8x549tyl0i2yokst, com.docker.swarm.service.id=qmk60m0sytxnqlpgwz483hq58, com.docker.swarm.service.name=myapp_web, com.docker.swarm.task=, com.docker.swarm.task.id=3thdglvcpbt5i5bac38k8nrcq, com.docker.swarm.task.name=myapp_web.2jqq8twdy8x549tyl0i2yokst.3thdglvcpbt5i5bac38k8nrcq, execID=3387082ab0c7e6c1b8f9ff0f1b73003e975c4ccb83dfb3d99144e9951d88d65b, image=myapp-web:1.0.0, maintainer=NGINX Docker Maintainers , name=myapp_web.2jqq8twdy8x549tyl0i2yokst.3thdglvcpbt5i5bac38k8nrcq)
2018-10-13T04:31:04.542511350Z container exec_start: /bin/sh -c curl -f http://127.0.0.1/healthcheck || exit 1 fc4105bc721c89956d358d078d8f689110e68cd0b02d3e48fd4074cb7d0f635f (com.docker.stack.namespace=myapp, com.docker.swarm.node.id=2jqq8twdy8x549tyl0i2yokst, com.docker.swarm.service.id=qmk60m0sytxnqlpgwz483hq58, com.docker.swarm.service.name=myapp_web, com.docker.swarm.task=, com.docker.swarm.task.id=3thdglvcpbt5i5bac38k8nrcq, com.docker.swarm.task.name=myapp_web.2jqq8twdy8x549tyl0i2yokst.3thdglvcpbt5i5bac38k8nrcq, execID=3387082ab0c7e6c1b8f9ff0f1b73003e975c4ccb83dfb3d99144e9951d88d65b, image=myapp-web:1.0.0, maintainer=NGINX Docker Maintainers , name=myapp_web.2jqq8twdy8x549tyl0i2yokst.3thdglvcpbt5i5bac38k8nrcq)
2018-10-13T04:31:04.644207191Z container exec_die fc4105bc721c89956d358d078d8f689110e68cd0b02d3e48fd4074cb7d0f635f (com.docker.stack.namespace=myapp, com.docker.swarm.node.id=2jqq8twdy8x549tyl0i2yokst, com.docker.swarm.service.id=qmk60m0sytxnqlpgwz483hq58, com.docker.swarm.service.name=myapp_web, com.docker.swarm.task=, com.docker.swarm.task.id=3thdglvcpbt5i5bac38k8nrcq, com.docker.swarm.task.name=myapp_web.2jqq8twdy8x549tyl0i2yokst.3thdglvcpbt5i5bac38k8nrcq, execID=3387082ab0c7e6c1b8f9ff0f1b73003e975c4ccb83dfb3d99144e9951d88d65b, exitCode=0, image=myapp-web:1.0.0, maintainer=NGINX Docker Maintainers , name=myapp_web.2jqq8twdy8x549tyl0i2yokst.3thdglvcpbt5i5bac38k8nrcq) 
```

### さらに

swarm config を使うと nginx の設定はイメージを変更したり、ホスト側のファイルをマウントしなくても `docker service update` で更新できそう [Store configuration data using Docker Configs](https://docs.docker.com/engine/swarm/configs/)

しばらく見ていなかったけど swarm も意外と使えるのかな？ Sidecar とかが使えないのを割り切れば。
