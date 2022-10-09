---
title: 'docker-machine で DigitalOcean を使う'
date: Fri, 15 Apr 2016 14:25:43 +0000
draft: false
tags: ['未分類']
---

docker-machine コマンドは --driver digitalocean で簡単に DigitalOcean に Docker Machine を作れます。 https://docs.docker.com/machine/drivers/digital-ocean/```
Options:
   
   --digitalocean-access-token                Digital Ocean access token
                                              \[$DIGITALOCEAN\_ACCESS\_TOKEN\]

   --digitalocean-backups                     enable backups for droplet
                                              \[$DIGITALOCEAN\_BACKUPS\]

   --digitalocean-image "ubuntu-15-10-x64"    Digital Ocean Image
                                              \[$DIGITALOCEAN\_IMAGE\]

   --digitalocean-ipv6                        enable ipv6 for droplet
                                              \[$DIGITALOCEAN\_IPV6\]

   --digitalocean-private-networking          enable private networking for droplet
                                              \[$DIGITALOCEAN\_PRIVATE\_NETWORKING\]

   --digitalocean-region "nyc3"               Digital Ocean region
                                              \[$DIGITALOCEAN\_REGION\]

   --digitalocean-size "512mb"                Digital Ocean size
                                              \[$DIGITALOCEAN\_SIZE\]

   --digitalocean-ssh-key-fingerprint         SSH key fingerprint
                                              \[$DIGITALOCEAN\_SSH\_KEY\_FINGERPRINT\]

   --digitalocean-ssh-port "22"               SSH port
                                              \[$DIGITALOCEAN\_SSH\_PORT\]

   --digitalocean-ssh-user "root"             SSH username
                                              \[$DIGITALOCEAN\_SSH\_USER\]

   --digitalocean-userdata                    path to file with cloud-init user-data
                                              \[$DIGITALOCEAN\_USERDATA\]

```region や size は [doctl](https://github.com/digitalocean/doctl) コマンドで確認できます。実行のたびに変わらないものは環境変数にセットしておきます。（doctl は golang で書かれた one binary なので GitHub の release ページからダウンロートして PATH の通った場所に置いて使います）。```
$ doctl compute region list
Slug    Name            Available
nyc1    New York 1      true
sfo1    San Francisco 1 true
nyc2    New York 2      true
ams2    Amsterdam 2     true
sgp1    Singapore 1     true
lon1    London 1        true
nyc3    New York 3      true
ams3    Amsterdam 3     true
fra1    Frankfurt 1     true
tor1    Toronto 1       true

``````
$ doctl compute size list
Slug    Memory  VCPUs   Disk    Price Monthly   Price Hourly
512mb   512     1       20      5.00            0.007440
1gb     1024    1       30      10.00           0.014880
2gb     2048    2       40      20.00           0.029760
4gb     4096    2       60      40.00           0.059520
8gb     8192    4       80      80.00           0.119050
16gb    16384   8       160     160.00          0.238100
32gb    32768   12      320     320.00          0.476190
48gb    49152   16      480     480.00          0.714290
64gb    65536   20      640     640.00          0.952380

```SSH公開鍵のフィンガープリントは DigitalOcean の [Settings](https://cloud.digitalocean.com/settings/security) でも確認できますが、ローカルある鍵については ssh-keygen コマンドで取得できます 最近の ssh はデフォルトの HASH アルゴリズムが SHA256 になっているので、次のような出力だった場合は -E md5 を指定する必要があります。```
$ ssh-keygen -l -f ~/.ssh/id\_rsa.pub
2048 SHA256:XfGdbFbCEr/DkiONISd2V3fjpjYJddbJHVOfkau9qBA ytera@mypc (RSA)

``````
$ ssh-keygen -l -E md5 -f ~/.ssh/id\_rsa.pub
2048 MD5:f2:f2:76:35:b0:54:54:0d:8c:67:37:59:b0:0b:43:51 ytera@mypc (RSA)

```公開鍵を消しちゃってる場合は ssh-keygen -y で秘密鍵から作れます。 MD5: の後の部分 (f2:f2:76:35:b0:54:54:0d:8c:67:37:59:b0:0b:43:51) を環境変数 DIGITALOCEAN\_SSH\_KEY\_FINGERPRINT にセットしておきます。```
$ docker-machine create \\
  --driver digitalocean \\
  --digitalocean-size 2gb \\
  test1
Running pre-create checks...
Creating machine...
(test1) Creating SSH key...
(test1) Creating Digital Ocean droplet...
(test1) Waiting for IP address to be assigned to the Droplet...
Waiting for machine to be running, this may take a few minutes...
Detecting operating system of created instance...
Waiting for SSH to be available...
Detecting the provisioner...
Provisioning with ubuntu(systemd)...
Installing Docker...
Copying certs to the local machine directory...
Copying certs to the remote machine...
Setting Docker configuration on the remote daemon...
Checking connection to Docker...
Docker is up and running!
To see how to connect your Docker Client to the Docker Engine running on this virtual machine, run: docker-machine env test1

```簡単に Docker Machine ができました。```
$ docker-machine ls
NAME    ACTIVE   DRIVER         STATE     URL                        SWARM   DOCKER    ERRORS
test1   -        digitalocean   Running   tcp://188.166.211.7:2376           v1.11.0

``````
$ docker-machine ssh test1
Welcome to Ubuntu 15.10 (GNU/Linux 4.2.0-27-generic x86\_64)

 \* Documentation:  https://help.ubuntu.com/
Last login: Fri Apr 15 08:38:46 2016 from 124.211.178.241
root@test1:~# docker ps
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
root@test1:~# 

``````
$ eval $(docker-machine env test1)

``````
$ docker run -d -p 80:80 nginx

```とすれば外から port 80 にアクセスできちゃいました。 プライベートネットワークを有効にして試してみるとどうなるだろうか。```
$ docker-machine stop test1
Stopping "test1"...
Machine "test1" was stopped.
$ docker-machine rm test1
About to remove test1
Are you sure? (y/n): y
Successfully removed test1 

``````
$ docker-machine create \\
  --driver digitalocean \\
  --digitalocean-size 2gb \\
  --digitalocean-private-networking \\
  test2

```これで同じく nginx コンテナを起動してみたら```
$ docker run -d -p 80:80 nginx

```0.0.0.0:80 を Listen しており、Global IP Address 側からも Private IP Address 側からもアクセスできる状態になりました 次はこれで Swarm クラスタを構築してみよう