---
title: 'Docker Swarm mode を知る (setup)'
date: Mon, 12 Mar 2018 15:13:03 +0000
draft: false
tags: ['Docker', 'Swarm']
---

時代は Kubernetes ですが、Docker Swarm mode を再調査していみます。 Swarm mode については 1.12 での登場時に調査した（[Docker 1.12 の衝撃 \[slideshare\]](https://www.slideshare.net/yteraoka1/docker-112)）際にまだちょっと使うには早いなということで見送ってそれ以降ほとんど調査していませんでした。

### サーバーの準備

DigitalOcean で Docker インストール済みの Ubuntu を3台用意します。

```
for i in $(seq 3); do
  doctl compute droplet create swarm${i} \
    --image docker-16-04 \
    --region sgp1 \
    --size s-2vcpu-4gb \
    --ssh-keys 16797382 \
    --enable-private-networking \
    --enable-monitoring \
    --user-data-file userdata.sh
done
```

```
root@swarm1:~# ufw status verbose
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), allow (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22                         LIMIT IN    Anywhere
2375/tcp                   ALLOW IN    Anywhere
2376/tcp                   ALLOW IN    Anywhere
22 (v6)                    LIMIT IN    Anywhere (v6)
2375/tcp (v6)              ALLOW IN    Anywhere (v6)
2376/tcp (v6)              ALLOW IN    Anywhere (v6)
```

クラスタ管理用の通信で 2377/tcp を、ノード間通信で 7946/tcp, 7946/udp を、オーバーレイ・ネットワークで 4789/udp が使われるため ufw で firewall 設定を行います。 今回使ったイメージでは 2375/tcp, 2376/tcp が全開になっている（でも TCP の docker socket は使わないから開いてても大丈夫かな）のでこれを閉じて、上記のポートを eth1 でだけ開けます(DigitalOcean の eth1 は Private Network ですが、自分のアカウントに閉じられたネットワークではないため注意が必要）。

```
ufw delete allow 2375/tcp
ufw delete allow 2376/tcp

ufw allow in on eth1 from any port 2375 proto tcp
ufw allow in on eth1 from any port 2376 proto tcp
ufw allow in on eth1 from any port 2377 proto tcp
ufw allow in on eth1 from any port 7946 proto tcp
ufw allow in on eth1 from any port 7946 proto udp
ufw allow in on eth1 from any port 4789 proto udp
```

overlay network 作成時に `--opt encrypte` をつけて通信の暗号化を有効にした場合は追加で ESP プロトコルも通るようにする必要があります。

```
ufw allow from any proto esp
```

（`doctl compute ssh NAME` で便利に ssh できるはずなんだけど Windows では winpty が必要でこれが ANSI エスケープシーケンスの扱いが良くなくて使いものにならないのが残念だ）

### Swarm クラスタの作成

まず、`docker swarm init` コマンドで初期化します eth1 だけを listen するように次のようにしました

```
docker swarm init \
  --advertise-addr $(ip a s eth1 | grep 'inet ' | awk '{print $2}' | sed 's/\/.*//') \
  --listen-addr $(ip a s eth1 | grep 'inet ' | awk '{print $2}' | sed 's/\/.*//')
```

```
root@swarm1:~# docker swarm init \
>  --advertise-addr $(ip a s eth1 | grep 'inet ' | awk '{print $2}' | sed 's/\/.*//') \
>  --listen-addr $(ip a s eth1 | grep 'inet ' | awk '{print $2}' | sed 's/\/.*//')
Swarm initialized: current node (asqtfpeef1ur58dijnnykuwuk) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join --token SWMTKN-1-49x7ir3ihge066dretzivcu2gmdbwtys7v6h1yvybx784e5g5v-734ruykh451rsguxdjfhonuxn 10.130.27.207:2377

To add a manager to this swarm, run 'docker swarm join-token manager' and follow the instructions.

root@swarm1:~#
```

swarm init のオプション一覧は次のようになっています

```
Usage:  docker swarm init [OPTIONS]

Initialize a swarm

Options:
      --advertise-addr string           Advertised address (format: [:port])
      --autolock                        Enable manager autolocking (requiring an unlock key
                                        to start a stopped manager)
      --availability string             Availability of the node ("active"|"pause"|"drain")
                                        (default "active")
      --cert-expiry duration            Validity period for node certificates
                                        (ns|us|ms|s|m|h) (default 2160h0m0s)
      --data-path-addr string           Address or interface to use for data path traffic
                                        (format: )
      --dispatcher-heartbeat duration   Dispatcher heartbeat period (ns|us|ms|s|m|h) (default 5s)
      --external-ca external-ca         Specifications of one or more certificate signing
                                        endpoints
      --force-new-cluster               Force create a new cluster from current state
      --listen-addr node-addr           Listen address (format: [:port])
                                        (default 0.0.0.0:2377)
      --max-snapshots uint              Number of additional Raft snapshots to retain
      --snapshot-interval uint          Number of log entries between Raft snapshots (default
                                        10000)
      --task-history-limit int          Task history retention limit (default 5) 
```

`--cert-expiry` のデフォルト 2160h0m0s は90日

#### worker node の join

`docker swarm init` で出力されたコマンドを使って worker node として swarm クラスタに参加させられます。init の時と同じように `--advertise-addr`, `--listen-addr`

```
root@swarm2:~# docker swarm join \
>   --token SWMTKN-1-4h3mm7ekejoqq9vg4axaba8rdu3cisgck84feon7mqmh3kmf2a-3rus2x8h6p3rvti4r27by5wbt \
>   --advertise-addr $(ip a s eth1 | grep 'inet ' | awk '{print $2}' | sed 's/\/.*//') \
>   --listen-addr $(ip a s eth1 | grep 'inet ' | awk '{print $2}' | sed 's/\/.*//') \
>   10.130.71.24:2377
This node joined a swarm as a worker.
root@swarm2:~#
```

```
root@swarm1:~# docker node ls
ID                            HOSTNAME            STATUS              AVAILABILITY        MANAGER STATUS
bj8muio9ov1wkkxg7ts1lqozc *   swarm1              Ready               Active              Leader
vywjboq8e8pk1buntrulod9fu     swarm2              Ready               Active
r55jic8bg1giuljuv9901lic1     swarm3              Ready               Active
root@swarm1:~#
```

```
root@swarm1:~# docker info | grep -A 5 ^Swarm
Swarm: active
 NodeID: bj8muio9ov1wkkxg7ts1lqozc
 Is Manager: true
 ClusterID: udczyrb1xk8pvmehncli8y5o7
 Managers: 1
 Nodes: 3
root@swarm1:~#
```

manager ノードを増やすには `docker node promote NODE-ANME` とします

```
root@swarm1:~# docker node promote swarm2 swarm3
Node swarm2 promoted to a manager in the swarm.
Node swarm3 promoted to a manager in the swarm.
root@swarm1:~#
```

```
root@swarm1:~# docker node ls
ID                            HOSTNAME            STATUS              AVAILABILITY        MANAGER STATUS
bj8muio9ov1wkkxg7ts1lqozc *   swarm1              Ready               Active              Leader
vywjboq8e8pk1buntrulod9fu     swarm2              Ready               Active              Reachable
r55jic8bg1giuljuv9901lic1     swarm3              Ready               Active              Reachable
root@swarm1:~#
```

MANAGER STATUS が Reachable に変わりました

```
root@swarm1:~# docker info | grep -A 5 ^Swarm
Swarm: active
 NodeID: bj8muio9ov1wkkxg7ts1lqozc
 Is Manager: true
 ClusterID: udczyrb1xk8pvmehncli8y5o7
 Managers: 3
 Nodes: 3
root@swarm1:~#
```

Managers が 3 に増えました node を増やすための token は忘れても `docker swarm join-token {worker|manager}` コマンドで確認することができます

### Service の作成

```
Usage:  docker service create [OPTIONS] IMAGE [COMMAND] [ARG...]

Create a new service

Options:
      --config config                      Specify configurations to expose to the service
      --constraint list                    Placement constraints
      --container-label list               Container labels
      --credential-spec credential-spec    Credential spec for managed service account
                                           (Windows only)
  -d, --detach                             Exit immediately instead of waiting for the
                                           service to converge
      --dns list                           Set custom DNS servers
      --dns-option list                    Set DNS options
      --dns-search list                    Set custom DNS search domains
      --endpoint-mode string               Endpoint mode (vip or dnsrr) (default "vip")
      --entrypoint command                 Overwrite the default ENTRYPOINT of the image
  -e, --env list                           Set environment variables
      --env-file list                      Read in a file of environment variables
      --generic-resource list              User defined resources
      --group list                         Set one or more supplementary user groups for the
                                           container
      --health-cmd string                  Command to run to check health
      --health-interval duration           Time between running the check (ms|s|m|h)
      --health-retries int                 Consecutive failures needed to report unhealthy
      --health-start-period duration       Start period for the container to initialize
                                           before counting retries towards unstable (ms|s|m|h)
      --health-timeout duration            Maximum time to allow one check to run (ms|s|m|h)
      --host list                          Set one or more custom host-to-IP mappings (host:ip)
      --hostname string                    Container hostname
      --isolation string                   Service container isolation mode
  -l, --label list                         Service labels
      --limit-cpu decimal                  Limit CPUs
      --limit-memory bytes                 Limit Memory
      --log-driver string                  Logging driver for service
      --log-opt list                       Logging driver options
      --mode string                        Service mode (replicated or global) (default
                                           "replicated")
      --mount mount                        Attach a filesystem mount to the service
      --name string                        Service name
      --network network                    Network attachments
      --no-healthcheck                     Disable any container-specified HEALTHCHECK
      --no-resolve-image                   Do not query the registry to resolve image digest
                                           and supported platforms
      --placement-pref pref                Add a placement preference
  -p, --publish port                       Publish a port as a node port
  -q, --quiet                              Suppress progress output
      --read-only                          Mount the container's root filesystem as read only
      --replicas uint                      Number of tasks
      --reserve-cpu decimal                Reserve CPUs
      --reserve-memory bytes               Reserve Memory
      --restart-condition string           Restart when condition is met
                                           ("none"|"on-failure"|"any") (default "any")
      --restart-delay duration             Delay between restart attempts (ns|us|ms|s|m|h)
                                           (default 5s)
      --restart-max-attempts uint          Maximum number of restarts before giving up
      --restart-window duration            Window used to evaluate the restart policy
                                           (ns|us|ms|s|m|h)
      --rollback-delay duration            Delay between task rollbacks (ns|us|ms|s|m|h)
                                           (default 0s)
      --rollback-failure-action string     Action on rollback failure ("pause"|"continue")
                                           (default "pause")
      --rollback-max-failure-ratio float   Failure rate to tolerate during a rollback (default 0)
      --rollback-monitor duration          Duration after each task rollback to monitor for
                                           failure (ns|us|ms|s|m|h) (default 5s)
      --rollback-order string              Rollback order ("start-first"|"stop-first")
                                           (default "stop-first")
      --rollback-parallelism uint          Maximum number of tasks rolled back simultaneously
                                           (0 to roll back all at once) (default 1)
      --secret secret                      Specify secrets to expose to the service
      --stop-grace-period duration         Time to wait before force killing a container
                                           (ns|us|ms|s|m|h) (default 10s)
      --stop-signal string                 Signal to stop the container
  -t, --tty                                Allocate a pseudo-TTY
      --update-delay duration              Delay between updates (ns|us|ms|s|m|h) (default 0s)
      --update-failure-action string       Action on update failure
                                           ("pause"|"continue"|"rollback") (default "pause")
      --update-max-failure-ratio float     Failure rate to tolerate during an update (default 0)
      --update-monitor duration            Duration after each task update to monitor for
                                           failure (ns|us|ms|s|m|h) (default 5s)
      --update-order string                Update order ("start-first"|"stop-first") (default
                                           "stop-first")
      --update-parallelism uint            Maximum number of tasks updated simultaneously (0
                                           to update all at once) (default 1)
  -u, --user string                        Username or UID (format: [:])
      --with-registry-auth                 Send registry authentication details to swarm agents
  -w, --workdir string                     Working directory inside the container 
```

alpine イメージで ping を実行する helloworld というサービスを作ります。実行するコンテナ数は1個。

```
root@swarm1:~# docker service create --replicas 1 --name helloworld alpine ping docker.com
nti2sn57ise7179iewt15bvkz
overall progress: 1 out of 1 tasks
1/1: running
verify: Service converged
root@swarm1:~#
```

サービスの確認

```
root@swarm1:~# docker service ls
ID                  NAME                MODE                REPLICAS            IMAGE               PORTS
nti2sn57ise7        helloworld          replicated          1/1                 alpine:latest
root@swarm1:~#
```

サービスのコンテナ（タスクと呼ぶらしい）を確認

```
root@swarm1:~# docker service ps helloworld
ID                  NAME                IMAGE               NODE                DESIRED STATE       CURRENT STATE                ERROR               PORTS
u2vgsm3uuu2i        helloworld.1        alpine:latest       swarm1              Running             Running about a minute ago
root@swarm1:~#
```

`docker ps` ではその node で実行されているコンテナだけが確認できます

```
root@swarm1:~# docker ps
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
02ad80ae8ec8        alpine:latest       "ping docker.com"   2 minutes ago       Up 2 minutes                            helloworld.1.u2vgsm3uuu2i1f4f70y3f3yhe
root@swarm1:~#
```

service inspect は `--pretty` をつけると見やすい！！

```
root@swarm1:~# docker service inspect --pretty helloworld

ID:             nti2sn57ise7179iewt15bvkz
Name:           helloworld
Service Mode:   Replicated
 Replicas:      1
Placement:
UpdateConfig:
 Parallelism:   1
 On failure:    pause
 Monitoring Period: 5s
 Max failure ratio: 0
 Update order:      stop-first
RollbackConfig:
 Parallelism:   1
 On failure:    pause
 Monitoring Period: 5s
 Max failure ratio: 0
 Rollback order:    stop-first
ContainerSpec:
 Image:         alpine:latest@sha256:7b848083f93822dd21b0a2f14a110bd99f6efb4b838d499df6d04a49d0debf8b
 Args:          ping docker.com
Resources:
Endpoint Mode:  vip
root@swarm1:~#
```

### Scale の変更

サービスで実行するコンテナ数を増減させられます

```
root@swarm1:~# docker service scale helloworld=5
helloworld scaled to 5
overall progress: 5 out of 5 tasks
1/5: running
2/5: running
3/5: running
4/5: running
5/5: running
verify: Service converged
root@swarm1:~#
```

5つのコンテナに増えました

```
root@swarm1:~# docker service ps helloworld
ID                  NAME                IMAGE               NODE                DESIRED STATE       CURRENT STATE                ERROR               PORTS
u2vgsm3uuu2i        helloworld.1        alpine:latest       swarm1              Running             Running 8 minutes ago
udthnceo672p        helloworld.2        alpine:latest       swarm3              Running             Running about a minute ago
to5h2akq19tl        helloworld.3        alpine:latest       swarm1              Running             Running 59 seconds ago
jtnr25puybdb        helloworld.4        alpine:latest       swarm2              Running             Running about a minute ago
y8561et8m5e1        helloworld.5        alpine:latest       swarm3              Running             Running 59 seconds ago
root@swarm1:~#
```

`docker ps` ではその node で実行されているコンテナだけが確認できます

```
root@swarm1:~# docker ps
CONTAINER ID        IMAGE               COMMAND             CREATED              STATUS              PORTS               NAMES
7f828e94f492        alpine:latest       "ping docker.com"   About a minute ago   Up About a minute                       helloworld.3.to5h2akq19tliyshxwe7enzyc
02ad80ae8ec8        alpine:latest       "ping docker.com"   9 minutes ago        Up 9 minutes                            helloworld.1.u2vgsm3uuu2i1f4f70y3f3yhe
root@swarm1:~#
```

### Service の削除

```
root@swarm1:~# docker service rm helloworld
helloworld
root@swarm1:~#
```

service はすぐに削除して見えなくなるが container は cleanup されるまで数秒残るため docker ps ではしばらく見えます

### Rolling update

Rolling update の確認用に 3 コンテナの redis サービスを作成します。`--update-delay` で更新と更新の間の待ち時間を指定します。

```
root@swarm1:~# docker service create \
>   --replicas 3 \
>   --name redis \
>   --update-delay 10s \
>   redis:3.0.6
d97voxnq0jt74a7hlb1749ytt
overall progress: 3 out of 3 tasks
1/3: running
2/3: running
3/3: running
verify: Service converged
root@swarm1:~#
```

```
root@swarm1:~# docker service ls
ID                  NAME                MODE                REPLICAS            IMAGE               PORTS
d97voxnq0jt7        redis               replicated          3/3                 redis:3.0.6
root@swarm1:~# docker service ps redis
ID                  NAME                IMAGE               NODE                DESIRED STATE       CURRENT STATE            ERROR               PORTS
po89kjashmcm        redis.1             redis:3.0.6         swarm2              Running             Running 29 seconds ago
dg8cu0lz71t7        redis.2             redis:3.0.6         swarm3              Running             Running 29 seconds ago
sbs7yrrr3ct2        redis.3             redis:3.0.6         swarm1              Running             Running 26 seconds ago
root@swarm1:~#
```

デフォルトでは1コンテナずつ更新するが `--update-parallelism` でいくつ同時に更新するかを指定可能。

```
root@swarm1:~# docker service inspect --pretty redis

ID:             d97voxnq0jt74a7hlb1749ytt
Name:           redis
Service Mode:   Replicated
 Replicas:      3
Placement:
UpdateConfig:
 Parallelism:   1
 Delay:         10s
 On failure:    pause
 Monitoring Period: 5s
 Max failure ratio: 0
 Update order:      stop-first
RollbackConfig:
 Parallelism:   1
 On failure:    pause
 Monitoring Period: 5s
 Max failure ratio: 0
 Rollback order:    stop-first
ContainerSpec:
 Image:         redis:3.0.6@sha256:6a692a76c2081888b589e26e6ec835743119fe453d67ecf03df7de5b73d69842
Resources:
Endpoint Mode:  vip
root@swarm1:~#
```

**On failure** が **pause** なので更新に失敗すると更新を中断(pause)します。 **Update order**, **Rollback order** が **stop-first** なのでまず、現在のコンテナを停止して新しいものを起動させます。 中断してしまった更新は `docker service update CONTAINER-ID` で再開できます。上記の redis サービスでは `docker service update redis` とします。

```
root@swarm1:~# docker service update --image redis:3.0.7 redis
redis
overall progress: 3 out of 3 tasks
1/3: running
2/3: running
3/3: running
verify: Service converged
root@swarm1:~#
```

```
root@swarm1:~# docker service ps redis
ID                  NAME                IMAGE               NODE                DESIRED STATE       CURRENT STATE                 ERROR               PORTS
tak46phep0nr        redis.1             redis:3.0.7         swarm2              Running             Running 45 seconds ago
po89kjashmcm         \_ redis.1         redis:3.0.6         swarm2              Shutdown            Shutdown 52 seconds ago
i510owz0oag8        redis.2             redis:3.0.7         swarm3              Running             Running about a minute ago
dg8cu0lz71t7         \_ redis.2         redis:3.0.6         swarm3              Shutdown            Shutdown about a minute ago
trnsqcuxgrt9        redis.3             redis:3.0.7         swarm1              Running             Running 24 seconds ago
sbs7yrrr3ct2         \_ redis.3         redis:3.0.6         swarm1              Shutdown            Shutdown 33 seconds ago
root@swarm1:~#
```

### Drain node

node をクラスタから外す際には `docker node update` で `--availability drain` とします。サービスで実行中のコンテナ（タスク）は他の node に移動してくれます。

```
Usage:  docker node update [OPTIONS] NODE

Update a node

Options:
      --availability string   Availability of the node ("active"|"pause"|"drain")
      --label-add list        Add or update a node label (key=value)
      --label-rm list         Remove a node label if exists
      --role string           Role of the node ("worker"|"manager")
```

```
root@swarm1:~# docker node update --availability drain swarm2
swarm2
root@swarm1:~# docker node inspect --pretty swarm2 | head
ID:                     7h2d9guflr988w7r6eanuml1l
Hostname:               swarm2
Joined at:              2018-03-12 14:11:26.07479248 +0000 utc
Status:
 State:                 Ready
 Availability:          Drain
 Address:               10.130.39.87
Platform:
 Operating System:      linux
 Architecture:          x86_64
root@swarm1:~#
```

再度 `docker node update` で `--availability active` にすれば再度タスクが割り当てられるようになります。が、既に他の node で実行中のコンテナが移動されるわけではなく、`scale` コマンドや `service update` による更新、他の node を `drain` にしたり他の node 障害が発生した場合にタスクが移ってきます。

### Routing mesh

サービス作成時に `--publish` (`-p`) オプションを指定すると、全 node の published port へアクセスするとコンテナにルーティングしてくれるようになります。

```
$ docker service create \
  --name my-web \
  --publish published=8080,target=80 \
  --replicas 2 \
  nginx
```

`--publish published=8080,target=80` は `-p 8080:80` でも ok 上記のコマンドではどの node の port 8080 にアクセスしても my-web コンテナの port 80 に転送してくれます。複数のコンテナに順に振り分けてくれます（ロードバランス）。アクセスした node 上で当該コンテナが起動してるかどうかに関係なく他の node であっても転送されます。 udp の場合は `--publish published=53,target=53,protocol=udp` (`-p 53:53/udp`) のように指定します。 `--publish` (`-p`) は複数指定可能なので複数ポート使うことができます。 mesh routing が不要な場合は `--publish published=53,target=53,protocol=udp,mode=host` のように `mode=host` を追加します。ただし、この場合はその node でポートがかぶらないように調整が必要となるため注意が必要です。このため通常は `--mode global` で各 node でひとつずつ実行するタイプのサービスで使用することになると思われます。

### 次回

次はもっと実践的なサービスを構築してみようかと思います。
