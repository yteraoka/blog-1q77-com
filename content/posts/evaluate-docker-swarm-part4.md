---
title: 'Docker Swarm を試す – その4'
date: Sun, 20 Mar 2016 15:29:45 +0000
draft: false
tags: ['Docker', 'Linux', 'Swarm']
---

今回は [Get started with multi-host networking](https://docs.docker.com/engine/userguide/networking/get-started-overlay/) に沿ってマルチホストでのオーバーレイネットワークを試してみます。

### KVS として Consul を立ち上げる

まず mh-keystore という名前（名前はなんでも良い）の docker-machine を作成します。

```
$ docker-machine create -d virtualbox mh-keystore
Running pre-create checks...
Creating machine...
(mh-keystore) Copying /home/ytera/.docker/machine/cache/boot2docker.iso to /home/ytera/.docker/machine/machines/mh-keystore/boot2docker.iso...
(mh-keystore) Creating VirtualBox VM...
(mh-keystore) Creating SSH key...
(mh-keystore) Starting the VM...
(mh-keystore) Check network to re-create if needed...
(mh-keystore) Waiting for an IP...
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
To see how to connect your Docker Client to the Docker Engine running on this virtual machine, run: docker-machine env mh-keystore
```

環境変数を設定して

```
$ eval "$(docker-machine env mh-keystore)"
```

Consul コンテナを起動します

```
$ docker run -d \
>     -p "8500:8500" \
>     -h "consul" \
>     progrium/consul -server -bootstrap
Unable to find image 'progrium/consul:latest' locally
latest: Pulling from progrium/consul
c862d82a67a2: Pull complete 
0e7f3c08384e: Pull complete 
0e221e32327a: Pull complete 
09a952464e47: Pull complete 
60a1b927414d: Pull complete 
4c9f46b5ccce: Pull complete 
417d86672aa4: Pull complete 
b0d47ad24447: Pull complete 
fd5300bd53f0: Pull complete 
a3ed95caeb02: Pull complete 
d023b445076e: Pull complete 
ba8851f89e33: Pull complete 
5d1cefca2a28: Pull complete 
Digest: sha256:8cc8023462905929df9a79ff67ee435a36848ce7a10f18d6d0faba9306b97274
Status: Downloaded newer image for progrium/consul:latest
2fe1bbb97506bd1aa975230125f26b0b1fd666a54f819769a28a99a981aceb21
```

```
$ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                                                                            NAMES
2fe1bbb97506        progrium/consul     "/bin/start -server -"   25 seconds ago      Up 24 seconds       53/tcp, 53/udp, 8300-8302/tcp, 8400/tcp, 8301-8302/udp, 0.0.0.0:8500->8500/tcp   admiring_brahmagupta
```

### Consul を使った Swarm クラスタを立ち上げる

[Docker Swarm を試す – その１](/2016/03/evaluate-docker-swarm-part1/) で試した Swarm クラスタは docker-machine を作成した後にその上で swarm コンテナを起動しましたが、今回は dcoker-machine create コマンドで swarm まで起動しちゃうようです

```
$ docker-machine create \
> -d virtualbox \
> --swarm --swarm-master \
> --swarm-discovery="consul://$(docker-machine ip mh-keystore):8500" \
> --engine-opt="cluster-store=consul://$(docker-machine ip mh-keystore):8500" \
> --engine-opt="cluster-advertise=eth1:2376" \
> mhs-demo0
Running pre-create checks...
Creating machine...
(mhs-demo0) Copying /home/ytera/.docker/machine/cache/boot2docker.iso to /home/ytera/.docker/machine/machines/mhs-demo0/boot2docker.iso...
(mhs-demo0) Creating VirtualBox VM...
(mhs-demo0) Creating SSH key...
(mhs-demo0) Starting the VM...
(mhs-demo0) Check network to re-create if needed...
(mhs-demo0) Waiting for an IP...
Waiting for machine to be running, this may take a few minutes...
Detecting operating system of created instance...
Waiting for SSH to be available...
Detecting the provisioner...
Provisioning with boot2docker...
Copying certs to the local machine directory...
Copying certs to the remote machine...
Setting Docker configuration on the remote daemon...
Configuring swarm...
Checking connection to Docker...
Docker is up and running!
To see how to connect your Docker Client to the Docker Engine running on this virtual machine, run: docker-machine env mhs-demo0
```

master と agent の2つのコンテナが起動しています

```
$ DOCKER_HOST=$(docker-machine ip mhs-demo0):2376 docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
20681dcbb76e        swarm:latest        "/swarm join --advert"   39 seconds ago      Up 39 seconds                           swarm-agent
51e3f21e92f2        swarm:latest        "/swarm manage --tlsv"   44 seconds ago      Up 43 seconds                           swarm-agent-master
```

もう一個 docker-machine を作成する

```
$ docker-machine create -d virtualbox \
>     --swarm \
>     --swarm-discovery="consul://$(docker-machine ip mh-keystore):8500" \
>     --engine-opt="cluster-store=consul://$(docker-machine ip mh-keystore):8500" \
>     --engine-opt="cluster-advertise=eth1:2376" \
>   mhs-demo1
Running pre-create checks...
Creating machine...
(mhs-demo1) Copying /home/ytera/.docker/machine/cache/boot2docker.iso to /home/ytera/.docker/machine/machines/mhs-demo1/boot2docker.iso...
(mhs-demo1) Creating VirtualBox VM...
(mhs-demo1) Creating SSH key...
(mhs-demo1) Starting the VM...
(mhs-demo1) Check network to re-create if needed...
(mhs-demo1) Waiting for an IP...
Waiting for machine to be running, this may take a few minutes...
Detecting operating system of created instance...
Waiting for SSH to be available...
Detecting the provisioner...
Provisioning with boot2docker...
Copying certs to the local machine directory...
Copying certs to the remote machine...
Setting Docker configuration on the remote daemon...
Configuring swarm...
Checking connection to Docker...
Docker is up and running!
To see how to connect your Docker Client to the Docker Engine running on this virtual machine, run: docker-machine env mhs-demo1
```

こちらは agent がひとつだけ

```
$ DOCKER_HOST=$(docker-machine ip mhs-demo1):2376 docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
94dc04993723        swarm:latest        "/swarm join --advert"   5 seconds ago       Up 5 seconds                            swarm-agent
```

mhs-demo0 が SWARM の master になっているようです

```
$ docker-machine ls
NAME          ACTIVE   DRIVER       STATE     URL                         SWARM                DOCKER    ERRORS
mh-keystore   *        virtualbox   Running   tcp://192.168.99.103:2376                        v1.10.3   
mhs-demo0     -        virtualbox   Running   tcp://192.168.99.104:2376   mhs-demo0 (master)   v1.10.3   
mhs-demo1     -        virtualbox   Running   tcp://192.168.99.105:2376   mhs-demo0            v1.10.3
```

`docker-machine env` に `--swarm` をつけると Swarm クラスタとしてアクセスするための値が返されます

```
$ docker-machine env --swarm mhs-demo0
export DOCKER_TLS_VERIFY="1"
export DOCKER_HOST="tcp://192.168.99.104:3376"
export DOCKER_CERT_PATH="/home/ytera/.docker/machine/machines/mhs-demo0"
export DOCKER_MACHINE_NAME="mhs-demo0"
# Run this command to configure your shell: 
# eval $(docker-machine env --swarm mhs-demo0)
```

`--swarm` をつけないとこんな感じで docker-machine 単体となる

```
$ docker-machine env mhs-demo0
export DOCKER_TLS_VERIFY="1"
export DOCKER_HOST="tcp://192.168.99.104:2376"
export DOCKER_CERT_PATH="/home/ytera/.docker/machine/machines/mhs-demo0"
export DOCKER_MACHINE_NAME="mhs-demo0"
# Run this command to configure your shell: 
# eval $(docker-machine env mhs-demo0)
```

master ではない node で `--swarm` をつけるとエラーになる

```
$ docker-machine env --swarm mhs-demo1
Error checking TLS connection: "mhs-demo1" is not a swarm master. The --swarm flag is intended for use with swarm masters
```

クラスタ情報の確認 2台のクラスタになっていることが確認できます

```
$ eval $(docker-machine env --swarm mhs-demo0)
$ docker info
Containers: 3
 Running: 3
 Paused: 0
 Stopped: 0
Images: 2
Server Version: swarm/1.1.3
Role: primary
Strategy: spread
Filters: health, port, dependency, affinity, constraint
Nodes: 2
 mhs-demo0: 192.168.99.104:2376
  └ Status: Healthy
  └ Containers: 2
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 1.021 GiB
  └ Labels: executiondriver=native-0.2, kernelversion=4.1.19-boot2docker, operatingsystem=Boot2Docker 1.10.3 (TCL 6.4.1); master : 625117e - Thu Mar 10 22:09:02 UTC 2016, provider=virtualbox, storagedriver=aufs
  └ Error: (none)
  └ UpdatedAt: 2016-03-18T16:01:05Z
 mhs-demo1: 192.168.99.105:2376
  └ Status: Healthy
  └ Containers: 1
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 1.021 GiB
  └ Labels: executiondriver=native-0.2, kernelversion=4.1.19-boot2docker, operatingsystem=Boot2Docker 1.10.3 (TCL 6.4.1); master : 625117e - Thu Mar 10 22:09:02 UTC 2016, provider=virtualbox, storagedriver=aufs
  └ Error: (none)
  └ UpdatedAt: 2016-03-18T16:00:59Z
Plugins: 
 Volume: 
 Network: 
Kernel Version: 4.1.19-boot2docker
Operating System: linux
Architecture: amd64
CPUs: 2
Total Memory: 2.043 GiB
Name: mhs-demo0
```

### オーバーレイネットワークの作成

```
$ eval $(docker-machine env --swarm mhs-demo0)
$ docker network ls
NETWORK ID          NAME                DRIVER
566f51fbecf4        mhs-demo0/bridge    bridge              
408cc854d4e2        mhs-demo1/bridge    bridge              
f84f99d835f6        mhs-demo1/none      null                
cecd093423fe        mhs-demo1/host      host                
5fa9569a1b20        mhs-demo0/none      null                
c7871366f2d5        mhs-demo0/host      host
```

```
$ DOCKER_HOST=$(docker-machine ip mhs-demo0):2376 docker network ls
NETWORK ID          NAME                DRIVER
566f51fbecf4        bridge              bridge              
5fa9569a1b20        none                null                
c7871366f2d5        host                host
```

```
$ DOCKER_HOST=$(docker-machine ip mhs-demo1):2376 docker network ls
NETWORK ID          NAME                DRIVER
f84f99d835f6        none                null                
cecd093423fe        host                host                
408cc854d4e2        bridge              bridge
```

```
$ eval $(docker-machine env --swarm mhs-demo0)
$ docker network create --driver overlay --subnet=10.0.9.0/24 my-net
5fa661090e5d418c4c87fcfb90b87468cb8b9a027239090cd16d020c8a183016
$ docker network ls
NETWORK ID          NAME                DRIVER
408cc854d4e2        mhs-demo1/bridge    bridge              
f84f99d835f6        mhs-demo1/none      null                
5fa9569a1b20        mhs-demo0/none      null                
5fa661090e5d        my-net              overlay             
c7871366f2d5        mhs-demo0/host      host                
566f51fbecf4        mhs-demo0/bridge    bridge              
cecd093423fe        mhs-demo1/host      host
```

`--subnet` はちゃんと考えて指定しましょうとのこと。省略すると自動で採番されるけど、既存ネットワークとかぶると通信できないよと。 個別の docker-machine で見ても overlay の my-net が確認できます

```
$ DOCKER_HOST=$(docker-machine ip mhs-demo0):2376 docker network ls
NETWORK ID          NAME                DRIVER
5fa661090e5d        my-net              overlay             
566f51fbecf4        bridge              bridge              
5fa9569a1b20        none                null                
c7871366f2d5        host                host                
```

```
$ DOCKER_HOST=$(docker-machine ip mhs-demo1):2376 docker network ls
NETWORK ID          NAME                DRIVER
5fa661090e5d        my-net              overlay             
cecd093423fe        host                host                
408cc854d4e2        bridge              bridge              
f84f99d835f6        none                null
```

nginx を mhs-demo0 で実行します。`--env="constraint:node==mhs-demo0"` で実行ノードを指定することができるんですね

```
$ docker run -itd --name=web --net=my-net --env="constraint:node==mhs-demo0" nginx
bf918047d0dd862ef5d60dc119ae846c8abe8c114165a45bf889164903ad2712
```

```
$ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
bf918047d0dd        nginx               "nginx -g 'daemon off"   12 seconds ago      Up 11 seconds       80/tcp, 443/tcp     mhs-demo0/web
```

mhs-demo1 で busybox を起動してその中から wget で先の nginx にアクセスします

```
$ docker run -it --rm --net=my-net --env="constraint:node==mhs-demo1" busybox wget -O- http://web
Connecting to web (10.0.9.2:80)
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>
```

busybox には wget も入ってるんですね。あのサイズで。
web という名前で 10.0.9.2 にアクセスできています。これは誰が DNS サーバーとして返してくれているのだろうか？
`/etc/resolv.conf` は次のようになっています。

```
nameserver 127.0.0.11
options ndots:0
```

127.0.0.11 ってことは loopback デバイスだから同一ホスト上にいるということだから docker か swarm-agent に DNS サーバー機能があるっぽい

[Docker embedded DNS server](https://docs.docker.com/engine/userguide/networking/dockernetworks/#docker-embedded-dns-server) というものがあるようで、docker だったようです。

Docker の名前解決関連だと /etc/resolv.conf や /etc/hosts などはどうやって書き換えてるのかなって思ってたけど、こんなことになってるんですね

```
/dev/sda1 on /etc/resolv.conf type ext4 (rw,relatime,data=ordered)
/dev/sda1 on /etc/hostname type ext4 (rw,relatime,data=ordered)
/dev/sda1 on /etc/hosts type ext4 (rw,relatime,data=ordered)
```

試しに ubuntu コンテナを起動して dig で問い合わせてみる。www.google.com でも答えてくれる

```
# dig +short @127.0.0.11 web a
10.0.9.2
# dig +short @127.0.0.11 www.google.com a
216.58.197.196
```

ところで、docker コンテナを起動させたら docker\_gwbridge というネットワークが現れましたね

```
$ docker network ls
NETWORK ID          NAME                        DRIVER
9fbf2f30b09b        my-net                      overlay             
efde1746d319        mhs-demo0/bridge            bridge              
7ace1816bf3e        mhs-demo0/docker_gwbridge   bridge              
dac21ff6debc        mhs-demo1/docker_gwbridge   bridge              
ca19cb9ed0fe        mhs-demo1/bridge            bridge              
2f3cec420273        mhs-demo0/none              null                
9eca025e3f23        mhs-demo0/host              host                
fdb80d5fdc3a        mhs-demo1/none              null                
6533ca5a6b39        mhs-demo1/host              host
```

それぞれの docker-machine にできてます

```
$ DOCKER_HOST=$(docker-machine ip mhs-demo1):2376 docker network ls
NETWORK ID          NAME                DRIVER
ca19cb9ed0fe        bridge              bridge              
fdb80d5fdc3a        none                null                
6533ca5a6b39        host                host                
dac21ff6debc        docker_gwbridge     bridge              
9fbf2f30b09b        my-net              overlay
```

```
$ DOCKER_HOST=$(docker-machine ip mhs-demo0):2376 docker network ls
NETWORK ID          NAME                DRIVER
9fbf2f30b09b        my-net              overlay             
efde1746d319        bridge              bridge              
2f3cec420273        none                null                
9eca025e3f23        host                host                
7ace1816bf3e        docker_gwbridge     bridge
```

それぞれを `docker network inspect` で見てみます

```
$ docker network inspect mhs-demo0/docker_gwbridge
[
    {
        "Name": "docker_gwbridge",
        "Id": "7ace1816bf3e76eac53393808478bef4c6a6dfa91f86fbba413990489fff7955",
        "Scope": "local",
        "Driver": "bridge",
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": [
                {
                    "Subnet": "172.18.0.0/16",
                    "Gateway": "172.18.0.1/16"
                }
            ]
        },
        "Containers": {},
        "Options": {
            "com.docker.network.bridge.enable_icc": "false",
            "com.docker.network.bridge.enable_ip_masquerade": "true",
            "com.docker.network.bridge.name": "docker_gwbridge"
        }
    }
]
```

```
$ docker network inspect mhs-demo0/bridge
[
    {
        "Name": "bridge",
        "Id": "efde1746d3196225e68f47508882d7d5b3d118aef886b6040f322a58647a430a",
        "Scope": "local",
        "Driver": "bridge",
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": [
                {
                    "Subnet": "172.17.0.0/16"
                }
            ]
        },
        "Containers": {},
        "Options": {
            "com.docker.network.bridge.default_bridge": "true",
            "com.docker.network.bridge.enable_icc": "true",
            "com.docker.network.bridge.enable_ip_masquerade": "true",
            "com.docker.network.bridge.host_binding_ipv4": "0.0.0.0",
            "com.docker.network.bridge.name": "docker0",
            "com.docker.network.driver.mtu": "1500"
        }
    }
]
```

```
$ docker network inspect my-net
[
    {
        "Name": "my-net",
        "Id": "9fbf2f30b09bbe17457a116c64af2d59291b61efc11c34a006a2013583bb54e4",
        "Scope": "global",
        "Driver": "overlay",
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": [
                {
                    "Subnet": "10.0.9.0/24"
                }
            ]
        },
        "Containers": {},
        "Options": {}
    }
]
```

```
$ docker network inspect mhs-demo0/host
[
    {
        "Name": "host",
        "Id": "9eca025e3f23c5fb7b66063dd09b74dbb0a19e0ab5f1438f65ff9d83c28a2bf6",
        "Scope": "local",
        "Driver": "host",
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": []
        },
        "Containers": {
            "0a0c6293b4d31f439ff131ce57809e28feb91ce7a6f59a5d47d4fa22d28c1114": {
                "Name": "swarm-agent-master",
                "EndpointID": "22ff3f4019ce59162b87964078ae9328660a52b1c364043509bae3a427c402e4",
                "MacAddress": "",
                "IPv4Address": "",
                "IPv6Address": ""
            },
            "4614fed35665803693ac4702793b004ed89ca5f11e8f1673974ebe307dabee41": {
                "Name": "swarm-agent",
                "EndpointID": "4b1464dc76486835a42702281ed7714ef65bf900a385164c47bc6d44837113e1",
                "MacAddress": "",
                "IPv4Address": "",
                "IPv6Address": ""
            }
        },
        "Options": {}
    }
]
```

```
$ docker network inspect mhs-demo0/none
[
    {
        "Name": "none",
        "Id": "2f3cec4202730f0191ff6547f73da9ffa695367418fe34e98a3375d53abe71bd",
        "Scope": "local",
        "Driver": "null",
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": []
        },
        "Containers": {},
        "Options": {}
    }
]

```

nginx コンテナで interface を確認してみます。`my-net` と `docker_gwbridge` が割り当てられています

```
$ docker exec web ip addr
1: lo: mtu 65536 qdisc noqueue state UNKNOWN group default 
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
9: eth0@if10: mtu 1450 qdisc noqueue state UP group default 
    link/ether 02:42:0a:00:09:02 brd ff:ff:ff:ff:ff:ff
    inet 10.0.9.2/24 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:aff:fe00:902/64 scope link 
       valid_lft forever preferred_lft forever
12: eth1@if13: mtu 1500 qdisc noqueue state UP group default 
    link/ether 02:42:ac:12:00:02 brd ff:ff:ff:ff:ff:ff
    inet 172.18.0.2/16 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::42:acff:fe12:2/64 scope link 
       valid_lft forever preferred_lft forever 
```

```
$ docker exec web ip r
default via 172.18.0.1 dev eth1 
10.0.9.0/24 dev eth0  proto kernel  scope link  src 10.0.9.2 
172.18.0.0/16 dev eth1  proto kernel  scope link  src 172.18.0.2
```

```
$ docker exec -t web ping -c 3 8.8.8.8
PING 8.8.8.8 (8.8.8.8): 56 data bytes
64 bytes from 8.8.8.8: icmp_seq=0 ttl=61 time=13.327 ms
64 bytes from 8.8.8.8: icmp_seq=1 ttl=61 time=13.003 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=61 time=13.236 ms
--- 8.8.8.8 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max/stddev = 13.003/13.189/13.327/0.136 ms
```

`my-net` を使わない場合は 172.17.0.0/16 のアドレスなので `bridge` が割り当てられています

```
$ docker run -it --rm busybox ip a
1: lo: mtu 65536 qdisc noqueue 
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
44: eth0@if45: mtu 1500 qdisc noqueue 
    link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.2/16 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:acff:fe11:2/64 scope link tentative 
       valid_lft forever preferred_lft forever 
```

さて、オーバーレイ・ネットワークがない場合とどう違うの？というところですが

```
$ docker run -itd --name=web2 --env="constraint:node==mhs-demo0" nginx
c3c0131cb7881652f2e27768184a29767728d33cc3be6d66c0fdbc79d8c66459

$ docker run -it --rm --env="constraint:node==mhs-demo1" busybox wget -O- http://web2
wget: bad address 'web2'
```

名前解決ができませんね、IP アドレスで試してみましょう

```
$ docker exec -it web2 ip a
1: lo: mtu 65536 qdisc noqueue state UNKNOWN group default 
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
14: eth0@if15: mtu 1500 qdisc noqueue state UP group default 
    link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.2/16 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:acff:fe11:2/64 scope link 
       valid_lft forever preferred_lft forever

$ docker run -it --rm --env="constraint:node==mhs-demo1" busybox wget -O - http://172.17.0.2
Connecting to 172.17.0.2 (172.17.0.2:80)
wget: can't connect to remote host (172.17.0.2): Connection refused 
```

IP アドレスで指定しても通信できませんね。
nginx と wget を実行するコンテナを同一ホスト(docker-machine)で実行するとどうでしょうか 

```
$ docker run -it --rm --env="constraint:node==mhs-demo0" busybox wget -O - http://172.17.0.2
Connecting to 172.17.0.2 (172.17.0.2:80)

Welcome to nginx!
 body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    } 

Welcome to nginx!
=================

If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.

For online documentation and support please refer to
[nginx.org](http://nginx.org/).  
Commercial support is available at
[nginx.com](http://nginx.com/).

_Thank you for using nginx._

-                    100% |*******************************|   612   0:00:00 ETA
```

つながりましたね。

オーバーレイ・ネットワークがない状態の場合、2つの docker-machine がそれぞれ同じネットワークセグメントを独立して持っているためにお互いに通信ができませんでした。名前解決もできません。複数台の docker-machine を使う場合はオーバーレイ・ネットワークがとても便利です。
