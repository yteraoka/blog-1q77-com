---
title: 'docker 1.13 の secrets を試す'
date: Fri, 10 Feb 2017 14:54:59 +0000
draft: false
tags: ['Docker', 'Docker', 'Swarm', 'Swarm']
---

[Introducing Docker Secrets Management](https://blog.docker.com/2017/02/docker-secrets-management/) で紹介されているパスワードなどの機密情報管理の仕組みを試してみました。

### サーバー3台を起動

いつものように DigitalOcean で Docker 1.13 on Ubuntu 16.04 のサーバーを3台立ち上げます```
$ doctl compute droplet ls
ID		Name	Public IPv4	Public IPv6	Memory	VCPUs	Disk	Region	Image		Status	Tags
39553388	docker1	128.199.166.69			2048	2	40	sgp1	Ubuntu Docker 1.13.0 on 16.04	active	
39553389	docker2	128.199.166.74			2048	2	40	sgp1	Ubuntu Docker 1.13.0 on 16.04	active	
39553390	docker3	128.199.166.111			2048	2	40	sgp1	Ubuntu Docker 1.13.0 on 16.04	active	

```

### Swarm cluster を作成する

```
root@docker1:~# docker swarm init --listen-addr eth1 --advertise-addr eth1
Swarm initialized: current node (belgib92ppl2xq75aliayfpfu) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join \\
    --token SWMTKN-1-3avyjkw67sm3c6mpkmspb1g68vn3pp2xjd60e20j591qpaingi-eo53e4b2q029frqg868n9errv \\
    10.130.6.155:2377

To add a manager to this swarm, run 'docker swarm join-token manager' and follow the instructions.

```2377/tcp で待ち受けるよってことですが、```
root@docker1:~# ufw status
Status: active

To                         Action      From
--                         ------      ----
22                         LIMIT       Anywhere
2375/tcp                   ALLOW       Anywhere
2376/tcp                   ALLOW       Anywhere
22 (v6)                    LIMIT       Anywhere (v6)
2375/tcp (v6)              ALLOW       Anywhere (v6)
2376/tcp (v6)              ALLOW       Anywhere (v6)

```開いてないので開けましょう (3台とも)```
\# ufw allow in on eth1 proto tcp to any port 2377
Rule added
Rule added (v6)
# ufw allow out on eth1 proto tcp to any port 2377
Rule added
Rule added (v6)

```2台目、3台目を worker として swarm の join させる```
root@docker2:~# docker swarm join --listen-addr eth1 --advertise-addr eth1 \\
>     --token SWMTKN-1-3avyjkw67sm3c6mpkmspb1g68vn3pp2xjd60e20j591qpaingi-eo53e4b2q029frqg868n9errv \\
>     10.130.6.155:2377
This node joined a swarm as a worker.

``````
root@docker3:~# docker swarm join --listen-addr eth1 --advertise-addr eth1 \\
>     --token SWMTKN-1-3avyjkw67sm3c6mpkmspb1g68vn3pp2xjd60e20j591qpaingi-eo53e4b2q029frqg868n9errv \\
>     10.130.6.155:2377
This node joined a swarm as a worker.

```3台の swarm cluster ができました```
root@docker1:~# docker node ls
ID                           HOSTNAME  STATUS  AVAILABILITY  MANAGER STATUS
49tnhxfj2f935pzf0oa6hiia5    docker2   Ready   Active        
belgib92ppl2xq75aliayfpfu \*  docker1   Ready   Active        Leader
o71mxiuvxb1uxqzsc9n84ymud    docker3   Ready   Active        

```

### secret の作成

[Manage sensitive data with Docker secrets](https://docs.docker.com/engine/swarm/secrets/) にいろんな例がありますが標準入力からの文字列を登録してみます。```
root@docker1:~# echo "This is a secret" | docker secret create my\_secret\_data -
j64qa46dokdye82drqmjiy0z7

``````
root@docker1:~# docker secret ls
ID                          NAME                CREATED              UPDATED
j64qa46dokdye82drqmjiy0z7   my\_secret\_data      About a minute ago   About a minute ago

``````
root@docker1:~# docker secret inspect my\_secret\_data
\[
    {
        "ID": "j64qa46dokdye82drqmjiy0z7",
        "Version": {
            "Index": 21
        },
        "CreatedAt": "2017-02-10T14:19:29.170169762Z",
        "UpdatedAt": "2017-02-10T14:19:29.170169762Z",
        "Spec": {
            "Name": "my\_secret\_data"
        }
    }
\]

```

### コンテナから secret にアクセスする

なんでもいいけど redis のサービスを **\--secret="my\_secret\_data"** つきで作成する```
root@docker1:~# docker service create --name="redis" --secret="my\_secret\_data" redis:alpine
t7pnaiho5b26uilcz58q7ej8x

``````
root@docker1:~# docker service ls
ID            NAME   MODE        REPLICAS  IMAGE
t7pnaiho5b26  redis  replicated  1/1       redis:alpine

``````
root@docker1:~# docker service ps redis
ID            NAME     IMAGE         NODE     DESIRED STATE  CURRENT STATE          ERROR  PORTS
sxiapghqb6ev  redis.1  redis:alpine  docker1  Running        Running 4 minutes ago         

```docker1 上で起動しているので docker1 サーバー上で **docker exec** します```
root@docker1:~# docker exec $(docker ps --filter name=redis -q) ls -l /run/secrets
total 4
-r--r--r--    1 root     root            17 Feb 10 14:20 my\_secret\_data

```**/run/secrets/my\_secret\_data** というファイルが確認できます 中身を見てみます```
root@docker1:~# docker exec $(docker ps --filter name=redis -q) cat /run/secrets/my\_secret\_data
This is a secret

```**docker secret create** に渡した **This is a secret** ができました。 コンテナの **/run/secrets** ディレクトリに secret の名前のファイルができるわけですね。 コンテナ起動中には使われている secret は削除できないようです```
root@docker1:~# docker secret rm my\_secret\_data
Error response from daemon: rpc error: code = 3 desc = secret 'my\_secret\_data' is in use by the following service: redis

```コンテナから消したい場合は service の update を行う必要があるようです。```
root@docker1:~# docker service update --secret-rm="my\_secret\_data" redis
redis
root@docker1:~# docker service ps redis
ID            NAME         IMAGE         NODE     DESIRED STATE  CURRENT STATE           ERROR  PORTS
9i9axnogc4cz  redis.1      redis:alpine  docker2  Running        Running 2 seconds ago          
sxiapghqb6ev   \\\_ redis.1  redis:alpine  docker1  Shutdown       Shutdown 6 seconds ago         

```今度は docker2 サーバーですね```
root@docker2:~# docker exec $(docker ps --filter name=redis -q) cat /run/secrets/my\_secret\_data
cat: can't open '/run/secrets/my\_secret\_data': No such file or directory

```当該ファイルにアクセスできなくなりました

### secret 名を別名で渡す

[Manage sensitive data with Docker secrets](https://docs.docker.com/engine/swarm/secrets/) の例に Wordpress + MySQL のものがあります。```
$ docker service create \\
     --name mysql \\
     --replicas 1 \\
     --network mysql\_private \\
     --mount type=volume,source=mydata,destination=/var/lib/mysql \\
     --secret source=mysql\_root\_password,target=mysql\_root\_password \\
     --secret source=mysql\_password,target=mysql\_password \\
     -e MYSQL\_ROOT\_PASSWORD\_FILE="/run/secrets/mysql\_root\_password" \\
     -e MYSQL\_PASSWORD\_FILE="/run/secrets/mysql\_password" \\
     -e MYSQL\_USER="wordpress" \\
     -e MYSQL\_DATABASE="wordpress" \\
     mysql:latest

``````
$ docker service create \\
     --name wordpress \\
     --replicas 1 \\
     --network mysql\_private \\
     --publish 30000:80 \\
     --mount type=volume,source=wpdata,destination=/var/www/html \\
     --secret source=mysql\_password,target=wp\_db\_password,mode=0400 \\
     -e WORDPRESS\_DB\_USER="wordpress" \\
     -e WORDPRESS\_DB\_PASSWORD\_FILE="/run/secrets/wp\_db\_password" \\
     -e WORDPRESS\_DB\_HOST="mysql:3306" \\
     -e WORDPRESS\_DB\_NAME="wordpress" \\
     wordpress:latest

```MySQL コンテナで mysql\_password として使ったものを Wordpress では wp\_db\_password として見せたいので **\--secret source=mysql\_password,target=wp\_db\_password,mode=0400** と **source** と **target** で別の名前を使っています。**mode** で permission も指定できるのですね。 secret は値を更新することができないので、この **source** と **target** を駆使して service update する必要があるようです。あるいは一度 secret を削除して作りなおす、ただし、削除するにはコンテナを停止する必要がある。 Swarm mode はやっぱり簡単だよなぁ。1.12 の時は rolling update でもなぜか network が一旦切れるという問題があってこりゃまだ使えないなという感じだったけど 1.13 でもちょっと試してみよう。