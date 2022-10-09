---
title: 'Docker Swarm を試す – その2'
date: Wed, 16 Mar 2016 15:42:09 +0000
draft: false
tags: ['Docker', 'Swarm']
---

[前回](/2016/03/evaluate-docker-swarm-part1/) の続きです。

```
$ docker info
Containers: 8
 Running: 4
 Paused: 0
 Stopped: 4
Images: 8
Server Version: swarm/1.1.3
Role: primary
Strategy: spread
Filters: health, port, dependency, affinity, constraint
Nodes: 2
 agent1: 192.168.99.101:2376
  └ Status: Healthy
  └ Containers: 3
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 1.021 GiB
  └ Labels: executiondriver=native-0.2, kernelversion=4.1.19-boot2docker, operatingsystem=Boot2Docker 1.10.3 (TCL 6.4.1); master : 625117e - Thu Mar 10 22:09:02 UTC 2016, provider=virtualbox, storagedriver=aufs
  └ Error: (none)
  └ UpdatedAt: 2016-03-16T15:06:45Z
 agent2: 192.168.99.102:2376
  └ Status: Healthy
  └ Containers: 5
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 1.021 GiB
  └ Labels: executiondriver=native-0.2, kernelversion=4.1.19-boot2docker, operatingsystem=Boot2Docker 1.10.3 (TCL 6.4.1); master : 625117e - Thu Mar 10 22:09:02 UTC 2016, provider=virtualbox, storagedriver=aufs
  └ Error: (none)
  └ UpdatedAt: 2016-03-16T15:06:39Z
Plugins: 
 Volume: 
 Network: 
Kernel Version: 4.1.19-boot2docker
Operating System: linux
Architecture: amd64
CPUs: 2
Total Memory: 2.043 GiB
Name: f64f0f79da4d
```

Swarm クラスタができたのでここに docker-compose でなにか起動してみます。
[http://www.slideshare.net/zembutsu/introduction-to-docker-compose-and-swarm](http://www.slideshare.net/zembutsu/introduction-to-docker-compose-and-swarm) の zembutsu さん資料にある rocket.chat を実行してみましょう。
[https://github.com/RocketChat/Rocket.Chat/blob/master/docker-compose.yml](https://github.com/RocketChat/Rocket.Chat/blob/master/docker-compose.yml)

```yaml
mongo:
  image: mongo
  command: mongod --smallfiles --oplogSize 128

rocketchat:
  image: rocketchat/rocket.chat:latest
  environment:
    - PORT=3000
    - ROOT_URL=http://localhost:3000
    - MONGO_URL=mongodb://mongo:27017/rocketchat
  links:
    - mongo:mongo
  ports:
    - 3000:3000
```

これで `docker-compose up -d` を実行すれば起動するはず... が

```
$ docker-compose up -d
Traceback (most recent call last):
  File "<string>", line 3, in <module>
  File "/code/compose/cli/main.py", line 54, in main
  File "/code/compose/cli/docopt_command.py", line 23, in sys_dispatch
  File "/code/compose/cli/docopt_command.py", line 26, in dispatch
  File "/code/compose/cli/main.py", line 169, in perform_command
  File "/code/compose/cli/command.py", line 53, in project_from_options
  File "/code/compose/cli/command.py", line 89, in get_project
  File "/code/compose/cli/command.py", line 70, in get_client
  File "/code/compose/cli/docker_client.py", line 28, in docker_client
  File "/code/.tox/py27/lib/python2.7/site-packages/docker/client.py", line 50, in __init__
docker.errors.TLSParameterError: If using TLS, the base_url argument must begin with "https://".. TLS configurations should map the Docker CLI client configurations. See http://docs.docker.com/examples/https/ for API details.
docker-compose returned -1
```

む... DOCKER\_HOST という環境変数を

```
$ DOCKER_HOST=$(docker-machine ip manager):3376
$ echo $DOCKER_HOST
192.168.99.100:3376
```

と設定していましたが、docker-compose で使う場合は https:// をつける必要があるようです。([Problem when using the DOCKER\_HOST variable in combination with docker-compose and https:// #894](https://github.com/docker/docker-py/issues/894))

```
$ DOCKER_HOST=https://$(docker-machine ip manager):3376
$ echo $DOCKER_HOST
https://192.168.99.100:3376
```

```
$ docker-compose up -d
Pulling mongo (mongo:latest)...
agent1: Pulling mongo:latest... : downloaded
agent2: Pulling mongo:latest... : downloaded
Creating rocketchat_mongo_1
Pulling rocketchat (rocketchat/rocket.chat:latest)...
agent1: Pulling rocketchat/rocket.chat:latest... : downloaded
agent2: Pulling rocketchat/rocket.chat:latest... : downloaded
Creating rocketchat_rocketchat_1
```

今度は起動したようです。が、

```
$ docker ps
Invalid bind address format: https://192.168.99.100:3376

```

`docker` コマンドでは https:// がついているとダメなようです...

```
$ DOCKER_HOST=$(docker-machine ip manager):3376 docker ps
CONTAINER ID        IMAGE                           COMMAND                  CREATED             STATUS              PORTS                           NAMES
7a057da5bd26        rocketchat/rocket.chat:latest   "node main.js"           32 minutes ago      Up 32 minutes       192.168.99.102:3000->3000/tcp   agent2/rocketchat_rocketchat_1
470f403c7c04        mongo                           "/entrypoint.sh mongo"   33 minutes ago      Up 33 minutes       27017/tcp                       agent2/rocketchat_mongo_1,agent2/rocketchat_rocketchat_1/mongo,agent2/rocketchat_rocketchat_1/mongo_1,agent2/rocketchat_rocketchat_1/rocketchat_mongo_1
```

nodejs のアプリも mongo DB も agent2 側で起動してますね。docker-compose の塊は同じノードで実行される仕様なのか、たまたまなのかは要確認。
http://192.168.99.102:3000/ にアクセスすると Rocket.chat にアクセスできました。

{{< figure src="Rocket.Chat_.png" >}}

{{< figure src="Rocket.Chat2_.png" >}}

```
$ docker-compose logs
Attaching to rocketchat_rocketchat_1, rocketchat_mongo_1
rocketchat_1 | Updating process.env.MAIL_URL
rocketchat_1 | ufs: store created at 
rocketchat_1 | ufs: temp directory created at /tmp/ufs
rocketchat_1 | Updating process.env.MAIL_URL
rocketchat_1 | configuring push
rocketchat_1 | Using GridFS for Avatar storage
rocketchat_1 | ➔ System ➔ startup
rocketchat_1 | ➔ +---------------------------------------+
rocketchat_1 | ➔ |             SERVER RUNNING            |
rocketchat_1 | ➔ +---------------------------------------+
rocketchat_1 | ➔ |                                       |
rocketchat_1 | ➔ |       Version: 0.22.0                 |
rocketchat_1 | ➔ |  Process Port: 3000                   |
rocketchat_1 | ➔ |      Site URL: http://localhost:3000  |
rocketchat_1 | ➔ |                                       |
rocketchat_1 | ➔ +---------------------------------------+
rocketchat_1 | {"line":"71","file":"percolate_synced-cron.js","message":"SyncedCron: Scheduled \"Generate and save statistics\" next run @Wed Mar 16 2016 14:58:45 GMT+0000 (UTC)","time":{"$date":1458140325979},"level":"info"}
mongo_1      | 2016-03-16T14:57:06.297+0000 I CONTROL  [initandlisten] MongoDB starting : pid=1 port=27017 dbpath=/data/db 64-bit host=470f403c7c04
mongo_1      | 2016-03-16T14:57:06.298+0000 I CONTROL  [initandlisten] db version v3.2.4
mongo_1      | 2016-03-16T14:57:06.298+0000 I CONTROL  [initandlisten] git version: e2ee9ffcf9f5a94fad76802e28cc978718bb7a30
mongo_1      | 2016-03-16T14:57:06.298+0000 I CONTROL  [initandlisten] OpenSSL version: OpenSSL 1.0.1e 11 Feb 2013
mongo_1      | 2016-03-16T14:57:06.298+0000 I CONTROL  [initandlisten] allocator: tcmalloc
mongo_1      | 2016-03-16T14:57:06.298+0000 I CONTROL  [initandlisten] modules: none
mongo_1      | 2016-03-16T14:57:06.298+0000 I CONTROL  [initandlisten] build environment:
mongo_1      | 2016-03-16T14:57:06.298+0000 I CONTROL  [initandlisten]     distmod: debian71
mongo_1      | 2016-03-16T14:57:06.298+0000 I CONTROL  [initandlisten]     distarch: x86_64
mongo_1      | 2016-03-16T14:57:06.298+0000 I CONTROL  [initandlisten]     target_arch: x86_64
...
```
