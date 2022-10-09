---
title: 'Docker Swarm を試す - その１'
date: Tue, 15 Mar 2016 15:22:50 +0000
draft: false
tags: ['Docker', 'Swarm']
---

[Evaluate Swarm in a sandbox](https://docs.docker.com/swarm/install-w-machine/) を参考に Docker Swarm を試してみます。

### Swarm クラスタを構築するための docker machine を作成する

#### docker-machine の現状確認

```
$ docker-machine  ls
NAME      ACTIVE   DRIVER       STATE     URL   SWARM   DOCKER    ERRORS
default   -        virtualbox   Stopped                 Unknown   
```

今は不要なので削除しちゃう（残したままでも問題ない）

```
$ docker-machine rm default
About to remove default
Are you sure? (y/n): y
Successfully removed default
```

#### マネージャー用サーバー (manager) 作成

```
$ docker-machine create -d virtualbox manager
Running pre-create checks...
(manager) Default Boot2Docker ISO is out-of-date, downloading the latest release...
(manager) Latest release for github.com/boot2docker/boot2docker is v1.10.3
(manager) Downloading /home/ytera/.docker/machine/cache/boot2docker.iso from https://github.com/boot2docker/boot2docker/releases/download/v1.10.3/boot2docker.iso...
(manager) 0%....10%....20%....30%....40%....50%....60%....70%....80%....90%....100%
Creating machine...
(manager) Copying /home/ytera/.docker/machine/cache/boot2docker.iso to /home/ytera/.docker/machine/machines/manager/boot2docker.iso...
(manager) Creating VirtualBox VM...
(manager) Creating SSH key...
(manager) Starting the VM...
(manager) Check network to re-create if needed...
(manager) Waiting for an IP...
Waiting for machine to be running, this may take a few minutes...
Detecting operating system of created instance...
Waiting for SSH to be available...
Detecting the provisioner...
Provisioning with boot2docker...
Copying certs to the local machine directory...
Copying certs to the remote machine...
Setting Docker configuration on the remote daemon...
Checking connection to Docker...
Docker is up and running!
To see how to connect your Docker Client to the Docker Engine running on this virtual machine, run: docker-machine env manager
```

#### エージェント用サーバーを2台 (agent1, agent2) 作成する

```
$ docker-machine create -d virtualbox agent1
Running pre-create checks...
Creating machine...
(agent1) Copying /home/ytera/.docker/machine/cache/boot2docker.iso to /home/ytera/.docker/machine/machines/agent1/boot2docker.iso...
(agent1) Creating VirtualBox VM...
(agent1) Creating SSH key...
(agent1) Starting the VM...
(agent1) Check network to re-create if needed...
(agent1) Waiting for an IP...
Waiting for machine to be running, this may take a few minutes...
Detecting operating system of created instance...
Waiting for SSH to be available...
Detecting the provisioner...
Provisioning with boot2docker...
Copying certs to the local machine directory...
Copying certs to the remote machine...
Setting Docker configuration on the remote daemon...
Checking connection to Docker...
Docker is up and running!
To see how to connect your Docker Client to the Docker Engine running on this virtual machine, run: docker-machine env agent1
```

```
$ docker-machine create -d virtualbox agent2
Running pre-create checks...
Creating machine...
(agent2) Copying /home/ytera/.docker/machine/cache/boot2docker.iso to /home/ytera/.docker/machine/machines/agent2/boot2docker.iso...
(agent2) Creating VirtualBox VM...
(agent2) Creating SSH key...
(agent2) Starting the VM...
(agent2) Check network to re-create if needed...
(agent2) Waiting for an IP...
Waiting for machine to be running, this may take a few minutes...
Detecting operating system of created instance...
Waiting for SSH to be available...
Detecting the provisioner...
Provisioning with boot2docker...
Copying certs to the local machine directory...
Copying certs to the remote machine...
Setting Docker configuration on the remote daemon...
Checking connection to Docker...
Docker is up and running!
To see how to connect your Docker Client to the Docker Engine running on this virtual machine, run: docker-machine env agent2
```

#### 作成した docker machine の確認

```
$ docker-machine ls
NAME      ACTIVE   DRIVER       STATE     URL                         SWARM   DOCKER    ERRORS
agent1    -        virtualbox   Running   tcp://192.168.99.101:2376           v1.10.3   
agent2    -        virtualbox   Running   tcp://192.168.99.102:2376           v1.10.3   
manager   -        virtualbox   Running   tcp://192.168.99.100:2376           v1.10.3   
```

### Swarm ディスカバリトークンの作成

docker コマンドで manager サーバーの操作をするように環境変数を設定する

```
$ eval $(docker-machine env manager)
$ printenv | grep DOCKER
DOCKER\_HOST=tcp://192.168.99.100:2376
DOCKER\_MACHINE\_NAME=manager
DOCKER\_TLS\_VERIFY=1
DOCKER\_CERT\_PATH=/home/ytera/.docker/machine/machines/manager
```

Swarm クラスタ用のユニークID（ディスカバリトークン）を生成する

```
$ docker run --rm swarm create
Unable to find image 'swarm:latest' locally
latest: Pulling from library/swarm
25da0aa87182: Pull complete 
45707a9f4c2b: Pull complete 
7f0c09406c8f: Pull complete 
a3ed95caeb02: Pull complete 
Digest: sha256:5f2b4066b2f7e97a326a8bfcfa623be26ce45c26ffa18ea63f01de045d2238f3
Status: Downloaded newer image for swarm:latest
2aba3c5381a6783e37980a8ef90fa41a
```

`2aba3c5381a6783e37980a8ef90fa41a` がディスカバリトークンになります。どこか安全な場所にメモっておきます。 docker コマンドに `--rm` を指定して実行したので create コマンド実行後すぐに実行したイメージが削除されています。

```
$ docker ps -a
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
```

### Swarm マネージャとノードを作成する

docker-machine の状態確認

```
$ docker-machine ls
NAME      ACTIVE   DRIVER       STATE     URL                         SWARM   DOCKER    ERRORS
agent1    -        virtualbox   Running   tcp://192.168.99.101:2376           v1.10.3   
agent2    -        virtualbox   Running   tcp://192.168.99.102:2376           v1.10.3   
manager   *        virtualbox   Running   tcp://192.168.99.100:2376           v1.10.3   
```

次のようにして manager を起動します。manager マシンの 3376 ポートを container の 3376 ポートにマッピングしています。`/var/lib/boot2docker` を container の `/certs` にマウントしています。先ほど生成したディスカバリトークンを `token://` で指定しています。

```
$ docker run -d -p 3376:3376 -t -v /var/lib/boot2docker:/certs:ro \
    swarm manage -H 0.0.0.0:3376 --tlsverify \
    --tlscacert=/certs/ca.pem --tlscert=/certs/server.pem \
    --tlskey=/certs/server-key.pem \
    token://2aba3c5381a6783e37980a8ef90fa41a
17ba16d89bda270965e534474fd06d5698bcde0aa14397403fb2e970612cd763
```

`/var/lib/boot2docker` とは docker-machine で作成した boot2docker サーバーの `/var/lib/boot2docker` です。次のように manager マシンに ssh でログインすると確認できます。

```
$ docker-machine ssh manager
                        ##         .
                  ## ## ##        ==
               ## ## ## ## ##    ===
           /"""""""""""""""""\___/ ===
      ~~~ {~~ ~~~~ ~~~ ~~~~ ~~~ ~ /  ===- ~~~
           \______ o           __/
             \    \         __/
              \____\_______/
 _                 _   ____     _            _
| |__   ___   ___ | |_|___ \ __| | ___   ___| | _____ _ __
| '_ \ / _ \ / _ \| __| __) / _` |/ _ \ / __| |/ / _ \ '__|
| |_) | (_) | (_) | |_ / __/ (_| | (_) | (__|   <  __/ |
|_.__/ \___/ \___/ \__|_____\__,_|\___/ \___|_|\_\___|_|
Boot2Docker version 1.10.3, build master : 625117e - Thu Mar 10 22:09:02 UTC 2016
Docker version 1.10.3, build 20f81dd
docker@manager:~$ sudo ls /var/lib/boot2docker/
ca.pem          etc             profile         server.pem      tls
docker.log      log             server-key.pem  ssh             userdata.tar
docker@manager:~$
```

manager コンテナが起動していることを確認してみます。

```
$ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED              STATUS              PORTS                              NAMES
17ba16d89bda        swarm               "/swarm manage -H 0.0"   About a minute ago   Up About a minute   2375/tcp, 0.0.0.0:3376->3376/tcp   lonely_ritchie

```

続いて agent1 の操作に移ります docker コマンドの接続先を agent1 に切り替えます

```
$ eval $(docker-machine env agent1)
```

swarm コンテナを先ほどのディスカバリトークンを使って join させます

```
$ docker run -d swarm join --addr=$(docker-machine ip agent1):2376 \
    token://2aba3c5381a6783e37980a8ef90fa41a
Unable to find image 'swarm:latest' locally
latest: Pulling from library/swarm
25da0aa87182: Pull complete 
45707a9f4c2b: Pull complete 
7f0c09406c8f: Pull complete 
a3ed95caeb02: Pull complete 
Digest: sha256:5f2b4066b2f7e97a326a8bfcfa623be26ce45c26ffa18ea63f01de045d2238f3
Status: Downloaded newer image for swarm:latest
171d5b1abb2c3840b831591a2c4fb231e68703bb2b3a05237cae84e6682e433f
```

さらに agent2

```
$ eval $(docker-machine env agent2)
```

```
$ docker run -d swarm join --addr=$(docker-machine ip agent2):2376 \
    token://2aba3c5381a6783e37980a8ef90fa41a
Unable to find image 'swarm:latest' locally
latest: Pulling from library/swarm
25da0aa87182: Pull complete 
45707a9f4c2b: Pull complete 
7f0c09406c8f: Pull complete 
a3ed95caeb02: Pull complete 
Digest: sha256:5f2b4066b2f7e97a326a8bfcfa623be26ce45c26ffa18ea63f01de045d2238f3
Status: Downloaded newer image for swarm:latest
3f5c29f68c65334607622a89cafde0268d229ec365646326cd15ef60b5b06f42
```

agent は manager に対してオレはこの IP と Port で待ってるからよろしくって参加している感じだけどマルチキャストでも使ってるのかな？後で調べよう。 → [Docker Hub as a hosted discovery service を使ってました](/2016/03/evaluate-docker-swarm-part3/)

### Swarm マネージャの管理

```
$ DOCKER_HOST=$(docker-machine ip manager):3376
```

```
$ docker info
Containers: 2
 Running: 2
 Paused: 0
 Stopped: 0
Images: 2
Server Version: swarm/1.1.3
Role: primary
Strategy: spread
Filters: health, port, dependency, affinity, constraint
Nodes: 2
 agent1: 192.168.99.101:2376
  └ Status: Healthy
  └ Containers: 1
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 1.021 GiB
  └ Labels: executiondriver=native-0.2, kernelversion=4.1.19-boot2docker, operatingsystem=Boot2Docker 1.10.3 (TCL 6.4.1); master : 625117e - Thu Mar 10 22:09:02 UTC 2016, provider=virtualbox, storagedriver=aufs
  └ Error: (none)
  └ UpdatedAt: 2016-03-15T15:05:38Z
 agent2: 192.168.99.102:2376
  └ Status: Healthy
  └ Containers: 1
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 1.021 GiB
  └ Labels: executiondriver=native-0.2, kernelversion=4.1.19-boot2docker, operatingsystem=Boot2Docker 1.10.3 (TCL 6.4.1); master : 625117e - Thu Mar 10 22:09:02 UTC 2016, provider=virtualbox, storagedriver=aufs
  └ Error: (none)
  └ UpdatedAt: 2016-03-15T15:05:59Z
Plugins: 
 Volume: 
 Network: 
Kernel Version: 4.1.19-boot2docker
Operating System: linux
Architecture: amd64
CPUs: 2
Total Memory: 2.043 GiB
Name: 17ba16d89bda
```

agent1, agent2 の Swarm クラスタが構成されているっぽいですね。

```
$ docker ps
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
```

試しに hello-world コンテナを実行してみます

```
$ docker run hello-world

Hello from Docker.
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker Hub account:
 https://hub.docker.com

For more examples and ideas, visit:
 https://docs.docker.com/userguide/
```

agent1 上で実行されたようです。

```
$ docker ps -a
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS                     PORTS               NAMES
0c20dcb512c7        hello-world         "/hello"                 8 seconds ago       Exited (0) 7 seconds ago                       agent1/naughty_jennings
3f5c29f68c65        swarm               "/swarm join --addr=1"   9 minutes ago       Up 9 minutes               2375/tcp            agent2/thirsty_yonath
171d5b1abb2c        swarm               "/swarm join --addr=1"   11 minutes ago      Up 11 minutes              2375/tcp            agent1/amazing_ride
```

まだまだ Swarm のことはわからないが [Evaluate Swarm in a sandbox](https://docs.docker.com/swarm/install-w-machine/) ページの内容はこれで終わり。
[Docker Swarm](https://docs.docker.com/swarm/) を順に試していこう。

[Docker Swarm を試す – その2](/2016/03/evaluate-docker-swarm-part2/)
