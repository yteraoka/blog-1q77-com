---
title: 'Docker Swarm mode を知る (Swarm on Windows)'
date: Tue, 20 Mar 2018 15:02:17 +0000
draft: false
tags: ['Docker', 'Portainer', 'Swarm', 'Windows']
---

Docker Swarm を Windows 上に構築してみます。 [https://docs.docker.com/get-started/part4/](https://docs.docker.com/get-started/part4/) にドキュメントがありました。私の家の Laptop は Windows Pro じゃないから VirtualBox 使うやつです。

### Docker Machine を2台作成

```
docker-machine create --driver virtualbox myvm1
docker-machine create --driver virtualbox myvm2
```

```
$ docker-machine ls
NAME      ACTIVE   DRIVER       STATE     URL                         SWARM   DOCKER        ERRORS
default   -        virtualbox   Stopped                                       Unknown
myvm1     *        virtualbox   Running   tcp://192.168.99.100:2376           v17.12.1-ce
myvm2     -        virtualbox   Running   tcp://192.168.99.101:2376           v17.12.1-ce
```

### Swarm の初期化と node の追加

myvm1 で swarm init

```
$ docker-machine ssh myvm1 "docker swarm init --advertise-addr \$(ip a s eth1 | grep 'inet ' | awk '{print \$2}' | sed 's/\/.*//')"
Swarm initialized: current node (u6otahnn4p9q72p734vcmtskt) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join --token SWMTKN-1-4pwif80w4dgtdrb7zo2j6bq1v22cun6cn4ftt1fj99tx5nlhmh-dl0ikqtubkk2ejkx5tvh99ul0 192.168.99.100:2377

To add a manager to this swarm, run 'docker swarm join-token manager' and follow the instructions.
```

myvm2 を swarm に worker として参加させる

```
$ docker-machine ssh myvm2 "docker swarm join --token SWMTKN-1-4pwif80w4dgtdrb7zo2j6bq1v22cun6cn4ftt1fj99tx5nlhmh-dl0ikqtubkk2ejkx5tvh99ul0 192.168.99.100:2377"
This node joined a swarm as a worker.
```

完成！！

```
$ docker-machine ssh myvm1 docker node ls
ID                            HOSTNAME            STATUS              AVAILABILITY        MANAGER STATUS
u6otahnn4p9q72p734vcmtskt *   myvm1               Ready               Active              Leader
su7h7svkmocwvrp55u3xygjd4     myvm2               Ready               Active
```

SSH しなくても環境変数を設定すれば docker コマンドで確認できます（Windows だけど git-bash だから eval です）。

```
$ eval $(docker-machine env myvm1)
$ docker node ls
ID                            HOSTNAME            STATUS              AVAILABILITY        MANAGER STATUS
u6otahnn4p9q72p734vcmtskt *   myvm1               Ready               Active              Leader
su7h7svkmocwvrp55u3xygjd4     myvm2               Ready               Active
```

### demo アプリを stack で deploy する

[前回](https://blog.1q77.com/2018/03/docker-swarm-mode-2/)の [stackdemo](https://github.com/yteraoka/stackdemo) を stack で deploy してみます。

```
$ docker stack deploy --compose-file docker-compose.yml stackdemo
Ignoring unsupported options: build

Creating network stackdemo_default
Creating service stackdemo_web
Creating service stackdemo_redis
```

できましたね。

```
$ docker stack ls
NAME                SERVICES
stackdemo           2
```

```
$ docker stack ps stackdemo
ID                  NAME                IMAGE                      NODE                DESIRED STATE       CURRENT STATE             ERROR               PORTS
rlh00omfhh6g        stackdemo_redis.1   redis:alpine               myvm1               Running             Running 32 seconds ago
4e07tj4g36u9        stackdemo_web.1     yteraoka/stackdemo:0.0.4   myvm2               Running             Starting 28 seconds ago
```

どちらの node の 8000 番ポートにアクセスしても mesh routing によってアクセスできます。

```
$ curl -s http://192.168.99.100:8000/
Hello World! I have been seen 1 times.
version: 0.0.4
$ curl -s http://192.168.99.101:8000/
Hello World! I have been seen 2 times.
version: 0.0.4
```

### Portainer を stack で deploy する

次に [Portainer](https://hub.docker.com/r/portainer/portainer/) を stack で deploy してみます。[https://github.com/portainer/portainer-compose](https://github.com/portainer/portainer-compose) にある `docker-stack.yml` を使いますが、`port` のところをちょっといじります。

```diff
$ git diff
diff --git a/docker-stack.yml b/docker-stack.yml
index b54df0e..c18e063 100644
--- a/docker-stack.yml
+++ b/docker-stack.yml
@@ -4,7 +4,7 @@ services:
   portainer:
     image: portainer/portainer
     ports:
-      - "9000"
+      - "9000:9000"
     networks:
       - portainer-net
     volumes:
```

```
$ git clone https://github.com/portainer/portainer-compose.git
Cloning into 'portainer-compose'...
remote: Counting objects: 71, done.
remote: Total 71 (delta 0), reused 0 (delta 0), pack-reused 71
Unpacking objects: 100% (71/71), done.
$ cd portainer-compose/
$ docker stack deploy --compose-file docker-stack.yml portainer
Creating network portainer_portainer-net
Creating service portainer_portainer
```

[http://192.168.99.100:9000](http://192.168.99.100:9000) にアクセスすると Portainer にアクセスできます。

Dashboard はこんな感じ

{{< figure src="portainer-dashboard.png" caption="Portainer Dashboard" >}}

Swarm Visualizer なんてのもありました

{{< figure src="portainer-swarm-visualizer.png" caption="Portainer Swarm Visualizer" >}}
