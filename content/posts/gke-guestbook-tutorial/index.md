---
title: 'GKE Guestbook チュートリアルを試す'
date: Sun, 12 Jul 2015 16:14:01 +0000
draft: false
tags: ['GCP', 'GKE', 'GCE', 'Kubernetes', 'tutorial']
---

前回は [Wordpress のチュートリアルを試しました](/2015/07/gke-hello-wordpress-tutorial/)、次はもう少し複雑な [Guestbook Tutorial - Container Engine — Google Cloud Platform](https://cloud.google.com/container-engine/docs/tutorials/guestbook) をなぞります。

Create a Container Engine cluster
---------------------------------

[GKE クラスタ](https://cloud.google.com/container-engine/docs/clusters/?hl=ja)を作成します

```
$ gcloud beta container clusters create guestbook
Creating cluster guestbook...done.
Created [https://container.googleapis.com/v1/projects/PROJECTID/zones/asia-east1-c/clusters/guestbook].
kubeconfig entry generated for guestbook. To switch context to the cluster, run

$ kubectl config use-context gke_PROJECTID_asia-east1-c_guestbook

NAME       ZONE          MASTER_VERSION  MASTER_IP        MACHINE_TYPE   STATUS
guestbook  asia-east1-c  0.21.1          203.0.113.167    n1-standard-1  RUNNING
```

Wordpress の時はノード数と GCE インスタンスの g1-small を指定しましたが、今回は指定がありません。 どうなってるのか確認してみましょう。

```
$ gcloud compute instances list
NAME                             ZONE         MACHINE_TYPE  PREEMPTIBLE INTERNAL_IP    EXTERNAL_IP     STATUS
gke-guestbook-f6a9e1a2-node-bjb5 asia-east1-c n1-standard-1             10.240.145.243 203.0.113.104   RUNNING
gke-guestbook-f6a9e1a2-node-woin asia-east1-c n1-standard-1             10.240.158.209 203.0.113.237   RUNNING
gke-guestbook-f6a9e1a2-node-zti0 asia-east1-c n1-standard-1             10.240.209.195 203.0.113.101   RUNNING
```

n1-standard-1 が3つ起動してますね。
n1-standard-1 は今日(2015/7/12)では1インスタンス $0.069/時間 のようです。[https://cloud.google.com/compute/?hl=ja](https://cloud.google.com/compute/?hl=ja) 3ノードそれぞれで `docker ps` してみました。 fluentd (ログコレクション), [etcd](https://github.com/coreos/etcd) (分散KVS), SkyDNS (etcd をバックエンドとした DNS サーバー), [kube2sky](https://github.com/GoogleCloudPlatform/kubernetes/tree/master/cluster/addons/dns/kube2sky) (Kubernetes と SkyDNS のブリッジ), [heapster](https://github.com/GoogleCloudPlatform/heapster) (リソースモニタリング) などが動いています。"pause" ってなんだろう？

```
$ sudo docker ps -a --no-trunc=true
CONTAINER ID                                                       IMAGE                                       COMMAND                                                                                       CREATED             STATUS              PORTS               NAMES
7d406295a24dd57eac1af3e0023b943d613ed6f7424b937412d90d7374760205   gcr.io/google_containers/fluentd-gcp:1.8    "\"/bin/sh -c '/usr/sbin/google-fluentd \"$FLUENTD_ARGS\" > /var/log/google-fluentd.log'\""   4 minutes ago       Up 4 minutes                            k8s_fluentd-cloud-logging.7721935b_fluentd-cloud-logging-gke-guestbook-f6a9e1a2-node-bjb5_kube-system_d0feac1ad02da9e97c4bf67970ece7a1_85a07d24   
014716b09d6de5c5546cd7fac5fe7c420071dd513cdee552d82dda5106de7399   gcr.io/google_containers/heapster:v0.15.0   "/heapster --source=kubernetes:''"                                                            4 minutes ago       Up 4 minutes                            k8s_heapster.5ec26f85_monitoring-heapster-v5-emb1z_kube-system_f9c0a5a4-289e-11e5-9359-42010af03fdb_18db2cfe                                      
7c85c94394ce25d5092e41bf2f1cba1bf67984b3c1cc27ebb775ffab75bbc76f   gcr.io/google_containers/pause:0.8.0        "/pause"                                                                                      5 minutes ago       Up 5 minutes                            k8s_POD.e4cc795_monitoring-heapster-v5-emb1z_kube-system_f9c0a5a4-289e-11e5-9359-42010af03fdb_70f26e8e                                            
be3069e309c9bdf6bacab0b0a83b641de1b24232d2438bd7db0d755697038c29   gcr.io/google_containers/pause:0.8.0        "/pause"                                                                                      5 minutes ago       Up 5 minutes                            k8s_POD.e4cc795_fluentd-cloud-logging-gke-guestbook-f6a9e1a2-node-bjb5_kube-system_d0feac1ad02da9e97c4bf67970ece7a1_8f560911
```

```
$ sudo docker ps -a --no-trunc=true
CONTAINER ID                                                       IMAGE                                      COMMAND                                                                                       CREATED             STATUS              PORTS               NAMES
d46086762093a7ae2b6885695afe3e6829e53f0546d1f8153c1c26d62038a5c3   gcr.io/google_containers/fluentd-gcp:1.8   "\"/bin/sh -c '/usr/sbin/google-fluentd \"$FLUENTD_ARGS\" > /var/log/google-fluentd.log'\""   16 minutes ago      Up 16 minutes                           k8s_fluentd-cloud-logging.7721935b_fluentd-cloud-logging-gke-guestbook-f6a9e1a2-node-woin_kube-system_d0feac1ad02da9e97c4bf67970ece7a1_334baa58   
78c2c76ddb6af757752ebab0494da0470c810bc9d4dd6dd4c76615b4b04540bd   gcr.io/google_containers/kube-ui:v1        "/kube-ui"                                                                                    16 minutes ago      Up 16 minutes                           k8s_kube-ui.e47d83a6_kube-ui-v1-gx17k_kube-system_f9c09a3f-289e-11e5-9359-42010af03fdb_8e9d5d77                                                   
d8460a693d20c6d4e2b2bf18700c1e7e589ea1c36e2c9d6c94c871227480c583   gcr.io/google_containers/pause:0.8.0       "/pause"                                                                                      16 minutes ago      Up 16 minutes                           k8s_POD.3b46e8b9_kube-ui-v1-gx17k_kube-system_f9c09a3f-289e-11e5-9359-42010af03fdb_cc87173f                                                       
e908771293b93ee52639fdf6400ff64338769c306252a6daa70f63fee3824703   gcr.io/google_containers/pause:0.8.0       "/pause"                                                                                      16 minutes ago      Up 16 minutes                           k8s_POD.e4cc795_fluentd-cloud-logging-gke-guestbook-f6a9e1a2-node-woin_kube-system_d0feac1ad02da9e97c4bf67970ece7a1_818f6b11
```

```
$ sudo docker ps -a --no-trunc=true
CONTAINER ID                                                       IMAGE                                            COMMAND                                                                                                                                                                                       CREATED             STATUS              PORTS               NAMES
c688081b385db0e2008f10705d412501983c8a52a938692d64e6dee14a1bd74e   gcr.io/google_containers/skydns:2015-03-11-001   "/skydns -machines=http://localhost:4001 -addr=0.0.0.0:53 -domain=cluster.local."                                                                                                             17 minutes ago      Up 17 minutes                           k8s_skydns.58dac13a_kube-dns-v6-qyyz6_kube-system_f9c0ad25-289e-11e5-9359-42010af03fdb_b864c5a2                                                   
ee5987aa158d726b376b327b12eb84457340a3d1c5e9fa93dc0d38f00131e2a5   gcr.io/google_containers/fluentd-gcp:1.8         "\"/bin/sh -c '/usr/sbin/google-fluentd \"$FLUENTD_ARGS\" > /var/log/google-fluentd.log'\""                                                                                                   17 minutes ago      Up 17 minutes                           k8s_fluentd-cloud-logging.7721935b_fluentd-cloud-logging-gke-guestbook-f6a9e1a2-node-zti0_kube-system_d0feac1ad02da9e97c4bf67970ece7a1_5a94cca9   
08c23fc0567836698bd44eec9bf07298657094ad1ef3a3fa79dc886ff5c46e68   gcr.io/google_containers/kube2sky:1.11           "/kube2sky -domain=cluster.local"                                                                                                                                                             17 minutes ago      Up 17 minutes                           k8s_kube2sky.a17e6ab0_kube-dns-v6-qyyz6_kube-system_f9c0ad25-289e-11e5-9359-42010af03fdb_4f7667c3                                                 
42dcd9cafab7def216f24f859615a3f90166e8971cfad6eb1ec88d8a8eaf8bba   gcr.io/google_containers/etcd:2.0.9              "/usr/local/bin/etcd -listen-client-urls http://127.0.0.1:2379,http://127.0.0.1:4001 -advertise-client-urls http://127.0.0.1:2379,http://127.0.0.1:4001 -initial-cluster-token skydns-etcd"   17 minutes ago      Up 17 minutes                           k8s_etcd.962798f6_kube-dns-v6-qyyz6_kube-system_f9c0ad25-289e-11e5-9359-42010af03fdb_30d92bc0                                                     
5bbad3fdb141277f4cff48851901bbf8c4e05821bf6aea9f2fb57b7914fd1fcd   gcr.io/google_containers/pause:0.8.0             "/pause"                                                                                                                                                                                      17 minutes ago      Up 17 minutes                           k8s_POD.8fdb0e41_kube-dns-v6-qyyz6_kube-system_f9c0ad25-289e-11e5-9359-42010af03fdb_59ac2004                                                      
9fbc741b98754aed17778101fd0ed5746f1a3acfb21191ca4686776dbc7ae0f6   gcr.io/google_containers/pause:0.8.0             "/pause"                                                                                                                                                                                      17 minutes ago      Up 17 minutes                           k8s_POD.e4cc795_fluentd-cloud-logging-gke-guestbook-f6a9e1a2-node-zti0_kube-system_d0feac1ad02da9e97c4bf67970ece7a1_4053a8c5

```

Linux distribution は Debian でした。

```
$ cat /etc/os-release 
PRETTY_NAME="Debian GNU/Linux 7 (wheezy)"
NAME="Debian GNU/Linux"
VERSION_ID="7"
VERSION="7 (wheezy)"
ID=debian
ANSI_COLOR="1;31"
HOME_URL="http://www.debian.org/"
SUPPORT_URL="http://www.debian.org/support/"
BUG_REPORT_URL="http://bugs.debian.org/"
```

Step one: Start the Redis master
--------------------------------

チュートリアルのサイトからダウンロードした `redis-master-controller.json` を使って pod を作成します。 この pod は[シングルコンテナ](https://cloud.google.com/container-engine/docs/pods/operations#pod_configuration_file)です。

```
$ kubectl create -f redis-master-controller.json
replicationcontrollers/redis-master
```

```
$ kubectl get pods -l name=redis-master
POD                  IP          CONTAINER(S)   IMAGE(S)   HOST                                              LABELS              STATUS    CREATED      MESSAGE
redis-master-4qexb   10.16.1.4                             gke-guestbook-f6a9e1a2-node-bjb5/10.240.145.243   name=redis-master   Running   25 seconds   
                                 master         redis                                                                            Running   10 seconds
```

`gke-guestbook-f6a9e1a2-node-bjb5` に pod が追加されたようなので、またログインして `docker ps` してみます。

```
$ sudo docker ps -a --no-trunc=true
CONTAINER ID                                                       IMAGE                                       COMMAND                                                                                       CREATED             STATUS                        PORTS               NAMES
623c6f0e1312d0f3e40eb924d105f6ac4164a4e4bad5d60b52333c570e82c45a   gcr.io/google_containers/heapster:v0.15.0   "/heapster --source=kubernetes:''"                                                            4 minutes ago       Up 4 minutes                                      k8s_heapster.5ec26f85_monitoring-heapster-v5-emb1z_kube-system_f9c0a5a4-289e-11e5-9359-42010af03fdb_5fe2012f                                      
5be9079c528100f6b342ddd1bccb8d987f32acbc3cdf95adc393ce2c3d412553   redis:latest                                "/entrypoint.sh redis-server"                                                                 13 minutes ago      Up 13 minutes                                     k8s_master.3173469e_redis-master-4qexb_default_a613affd-28a3-11e5-9359-42010af03fdb_6129e534                                                      
14087860fcf4e6648493e4895dca603b3b014c865a7eb69f828cc0d9d2bb0120   gcr.io/google_containers/pause:0.8.0        "/pause"                                                                                      13 minutes ago      Up 13 minutes                                     k8s_POD.49eee8c2_redis-master-4qexb_default_a613affd-28a3-11e5-9359-42010af03fdb_e8510c23                                                         
8a2b8a55b671ea003aee66ef7b048140fd7de393c77667e2c9bdda0565128588   gcr.io/google_containers/heapster:v0.15.0   "/heapster --source=kubernetes:''"                                                            14 minutes ago      Exited (137) 4 minutes ago                        k8s_heapster.5ec26f85_monitoring-heapster-v5-emb1z_kube-system_f9c0a5a4-289e-11e5-9359-42010af03fdb_c28b7121                                      
a17c35601da8dd07abce20b554537f814ba4cf1355d72804574efce81b62c4d6   gcr.io/google_containers/heapster:v0.15.0   "/heapster --source=kubernetes:''"                                                            24 minutes ago      Exited (137) 14 minutes ago                       k8s_heapster.5ec26f85_monitoring-heapster-v5-emb1z_kube-system_f9c0a5a4-289e-11e5-9359-42010af03fdb_c3470740                                      
7d406295a24dd57eac1af3e0023b943d613ed6f7424b937412d90d7374760205   gcr.io/google_containers/fluentd-gcp:1.8    "\"/bin/sh -c '/usr/sbin/google-fluentd \"$FLUENTD_ARGS\" > /var/log/google-fluentd.log'\""   46 minutes ago      Up 46 minutes                                     k8s_fluentd-cloud-logging.7721935b_fluentd-cloud-logging-gke-guestbook-f6a9e1a2-node-bjb5_kube-system_d0feac1ad02da9e97c4bf67970ece7a1_85a07d24   
7c85c94394ce25d5092e41bf2f1cba1bf67984b3c1cc27ebb775ffab75bbc76f   gcr.io/google_containers/pause:0.8.0        "/pause"                                                                                      46 minutes ago      Up 46 minutes                                     k8s_POD.e4cc795_monitoring-heapster-v5-emb1z_kube-system_f9c0a5a4-289e-11e5-9359-42010af03fdb_70f26e8e                                            
be3069e309c9bdf6bacab0b0a83b641de1b24232d2438bd7db0d755697038c29   gcr.io/google_containers/pause:0.8.0        "/pause"                                                                                      46 minutes ago      Up 46 minutes                                     k8s_POD.e4cc795_fluentd-cloud-logging-gke-guestbook-f6a9e1a2-node-bjb5_kube-system_d0feac1ad02da9e97c4bf67970ece7a1_8f560911
```

これで 10.16.1.4 の 6379 port にアクセスすると Redis が起動していることが確認できます。 どれかの node に ssh してアクセスしてみます。

```
$ gcloud compute ssh gke-guestbook-f6a9e1a2-node-zti0
```

telnet は入っていませんでしたが、nc コマンドがあったので試してみます

```
$ echo info | nc 10.16.1.4 6379
$1886
# Server
redis_version:3.0.2
redis_git_sha1:00000000
redis_git_dirty:0
redis_build_id:4795df119e2d77fe
redis_mode:standalone
os:Linux 3.16.0-0.bpo.4-amd64 x86_64
arch_bits:64
multiplexing_api:epoll
gcc_version:4.7.2
process_id:1
run_id:24fbeb83eb004d5d6e3828f37bea703974a87606
tcp_port:6379
uptime_in_seconds:326
uptime_in_days:0
hz:10
lru_clock:10648884
config_file:

# Clients
connected_clients:1
client_longest_output_list:0
client_biggest_input_buf:0
blocked_clients:0

# Memory
used_memory:815912
used_memory_human:796.79K
used_memory_rss:3551232
used_memory_peak:815912
used_memory_peak_human:796.79K
used_memory_lua:36864
mem_fragmentation_ratio:4.35
mem_allocator:jemalloc-3.6.0

# Persistence
loading:0
rdb_changes_since_last_save:0
rdb_bgsave_in_progress:0
rdb_last_save_time:1436711918
rdb_last_bgsave_status:ok
rdb_last_bgsave_time_sec:-1
rdb_current_bgsave_time_sec:-1
aof_enabled:0
aof_rewrite_in_progress:0
aof_rewrite_scheduled:0
aof_last_rewrite_time_sec:-1
aof_current_rewrite_time_sec:-1
aof_last_bgrewrite_status:ok
aof_last_write_status:ok

# Stats
total_connections_received:2
total_commands_processed:1
instantaneous_ops_per_sec:0
total_net_input_bytes:20
total_net_output_bytes:1951
instantaneous_input_kbps:0.00
instantaneous_output_kbps:0.00
rejected_connections:0
sync_full:0
sync_partial_ok:0
sync_partial_err:0
expired_keys:0
evicted_keys:0
keyspace_hits:0
keyspace_misses:0
pubsub_channels:0
pubsub_patterns:0
latest_fork_usec:0
migrate_cached_sockets:0

# Replication
role:master
connected_slaves:0
master_repl_offset:0
repl_backlog_active:0
repl_backlog_size:1048576
repl_backlog_first_byte_offset:0
repl_backlog_histlen:0

# CPU
used_cpu_sys:0.07
used_cpu_user:0.08
used_cpu_sys_children:0.00
used_cpu_user_children:0.00

# Cluster
cluster_enabled:0

# Keyspace
```

`docker logs` コマンドで出力を確認できます。

```
$ sudo docker logs 5be9079c528100f6b342ddd1bccb8d987f32acbc3cdf95adc393ce2c3d412553
1:C 12 Jul 14:38:38.271 # Warning: no config file specified, using the default config. In order to specify a config file use redis-server /path/to/redis.conf
                _._                                                  
           _.-``__ ''-._                                             
      _.-``    `.  `_.  ''-._           Redis 3.0.2 (00000000/0) 64 bit
  .-`` .-```.  ```\/    _.,_ ''-._                                   
 (    '      ,       .-`  | `,    )     Running in standalone mode
 |`-._`-...-` __...-.``-._|'` _.-'|     Port: 6379
 |    `-._   `._    /     _.-'    |     PID: 1
  `-._    `-._  `-./  _.-'    _.-'                                   
 |`-._`-._    `-.__.-'    _.-'_.-'|                                  
 |    `-._`-._        _.-'_.-'    |           http://redis.io        
  `-._    `-._`-.__.-'_.-'    _.-'                                   
 |`-._`-._    `-.__.-'    _.-'_.-'|                                  
 |    `-._`-._        _.-'_.-'    |                                  
  `-._    `-._`-.__.-'_.-'    _.-'                                   
      `-._    `-.__.-'    _.-'                                       
          `-._        _.-'                                           
              `-.__.-'                                               

1:M 12 Jul 14:38:38.272 # Server started, Redis version 3.0.2
1:M 12 Jul 14:38:38.272 # WARNING overcommit_memory is set to 0! Background save may fail under low memory condition. To fix this issue add 'vm.overcommit_memory = 1' to /etc/sysctl.conf and then reboot or run the command 'sysctl vm.overcommit_memory=1' for this to take effect.
1:M 12 Jul 14:38:38.272 # WARNING you have Transparent Huge Pages (THP) support enabled in your kernel. This will create latency and memory usage issues with Redis. To fix this issue run the command 'echo never > /sys/kernel/mm/transparent_hugepage/enabled' as root, and add it to your /etc/rc.local in order to retain the setting after a reboot. Redis must be restarted after THP is disabled.
1:M 12 Jul 14:38:38.272 # WARNING: The TCP backlog setting of 511 cannot be enforced because /proc/sys/net/core/somaxconn is set to the lower value of 128.
1:M 12 Jul 14:38:38.272 * The server is now ready to accept connections on port 6379

```

Step two: Start the Redis master's service
------------------------------------------

次に[サービス](https://cloud.google.com/container-engine/docs/services/)を設定します

```
$ kubectl create -f redis-master-service.json
services/redis-master
```

```
$ kubectl get services -l name=redis-master
NAME           LABELS              SELECTOR            IP(S)           PORT(S)
redis-master   name=redis-master   name=redis-master   10.19.253.109   6379/TCP
```

redis-master は1つだけなのでサービスを作っても代わり映えがしませんが、このアドレスを使ってアクセスします。pod が入れ替わってもこのアドレスは変わりません。次の redis slave は複数 pod のロードバランサー的に動作します。

Step three: Start the replicated Redis worker pods
--------------------------------------------------

今度は [Replication Controller](https://cloud.google.com/container-engine/docs/replicationcontrollers/) で同じ pod を複数起動させ、その数をキープさせます。

```
$ kubectl create -f redis-worker-controller.json
replicationcontrollers/redis-slave
```

`redis-slave` は `REPLICAS` が2になっています

```
$ kubectl get rc
CONTROLLER     CONTAINER(S)   IMAGE(S)                    SELECTOR            REPLICAS
redis-master   master         redis                       name=redis-master   1
redis-slave    slave          kubernetes/redis-slave:v2   name=redis-slave    2
```

`kubectl get pods` も2つの pod が確認できます

```
$ kubectl get pods -l name=redis-slave
POD                 IP        CONTAINER(S)   IMAGE(S)                    HOST                                LABELS             STATUS    CREATED          MESSAGE
redis-slave-a90om                                                        gke-guestbook-f6a9e1a2-node-woin/   name=redis-slave   Pending   About a minute   
                              slave          kubernetes/redis-slave:v2                                                                                     
redis-slave-xkeft                                                        gke-guestbook-f6a9e1a2-node-bjb5/   name=redis-slave   Pending   About a minute   
                              slave          kubernetes/redis-slave:v2
```

すぐだとまだ `Pending` でしたが、しばらくすると `Running` になりました。

```
$ kubectl get pods -l name=redis-slave
POD                 IP          CONTAINER(S)   IMAGE(S)                    HOST                                              LABELS             STATUS    CREATED     MESSAGE
redis-slave-a90om   10.16.2.4                                              gke-guestbook-f6a9e1a2-node-woin/10.240.158.209   name=redis-slave   Running   7 minutes   
                                slave          kubernetes/redis-slave:v2                                                                        Running   5 minutes   
redis-slave-xkeft   10.16.1.5                                              gke-guestbook-f6a9e1a2-node-bjb5/10.240.145.243   name=redis-slave   Running   7 minutes   
                                slave          kubernetes/redis-slave:v2                                                                        Running   5 minutes
```

Step four: Create the Redis worker service
------------------------------------------

redis-master 同様にサービスを作成します

```
$ kubectl create -f redis-worker-service.json
services/redis-slave
```

```
$ kubectl get services
NAME           LABELS                                    SELECTOR            IP(S)           PORT(S)
kubernetes     component=apiserver,provider=kubernetes   10.19.240.1     443/TCP
redis-master   name=redis-master                         name=redis-master   10.19.253.109   6379/TCP
redis-slave    name=redis-slave                          name=redis-slave    10.19.244.0     6379/TCP 
```

`redis-slave` という名前ですが、これはほんとに replication されてるのか確認してみましょう master に問い合わせてみると2つの slave が接続されてることが確認できました。 slave0, slave1 のアドレスに見知らぬものが表示されてますね、これは NAPT でアドレス変換されているのでしょうか

```
$ echo info replication | nc 10.16.1.4 6379
$309
# Replication
role:master
connected_slaves:2
slave0:ip=10.240.158.209,port=6379,state=online,offset=617,lag=0
slave1:ip=10.16.1.1,port=6379,state=online,offset=617,lag=1
master_repl_offset:617
repl_backlog_active:1
repl_backlog_size:1048576
repl_backlog_first_byte_offset:2
repl_backlog_histlen:616
```

今度は slave に問い合わせてみました。 `master_host` には `redis-master` とあります。これは redis-master というサービスのアドレスが etcd によって名前解決できるようになっているわけですね（きっと）

```
$ echo info replication | nc 10.16.2.4 6379
$363
# Replication
role:slave
master_host:redis-master
master_port:6379
master_link_status:up
master_last_io_seconds_ago:5
master_sync_in_progress:0
slave_repl_offset:743
slave_priority:100
slave_read_only:1
connected_slaves:0
master_repl_offset:0
repl_backlog_active:0
repl_backlog_size:1048576
repl_backlog_first_byte_offset:0
repl_backlog_histlen:0
```

```
$ echo info replication | nc 10.16.1.5 6379
$363
# Replication
role:slave
master_host:redis-master
master_port:6379
master_link_status:up
master_last_io_seconds_ago:6
master_sync_in_progress:0
slave_repl_offset:785
slave_priority:100
slave_read_only:1
connected_slaves:0
master_repl_offset:0
repl_backlog_active:0
repl_backlog_size:1048576
repl_backlog_first_byte_offset:0
repl_backlog_histlen:0
```

Step five: Create the guestbook web server pods
-----------------------------------------------

次は `frontend` という名の web serveer をセットアップします。

```
$ kubectl create -f frontend-controller.json
replicationcontrollers/frontend
```

```
$ kubectl get rc
CONTROLLER     CONTAINER(S)   IMAGE(S)                                    SELECTOR            REPLICAS
frontend       php-redis      kubernetes/example-guestbook-php-redis:v2   name=frontend       3
redis-master   master         redis                                       name=redis-master   1
redis-slave    slave          kubernetes/redis-slave:v2                   name=redis-slave    2
```

まだ起動中でしょうか Pending ですね。

```
$ kubectl get pods
POD                  IP          CONTAINER(S)   IMAGE(S)                                    HOST                                              LABELS              STATUS    CREATED      MESSAGE
frontend-ltoyt                                                                              gke-guestbook-f6a9e1a2-node-woin/                 name=frontend       Pending   47 seconds   
                                 php-redis      kubernetes/example-guestbook-php-redis:v2                                                                                                
frontend-o6dla                                                                              gke-guestbook-f6a9e1a2-node-bjb5/                 name=frontend       Pending   47 seconds   
                                 php-redis      kubernetes/example-guestbook-php-redis:v2                                                                                                
frontend-rurh0                                                                              gke-guestbook-f6a9e1a2-node-zti0/                 name=frontend       Pending   47 seconds   
                                 php-redis      kubernetes/example-guestbook-php-redis:v2                                                                                                
redis-master-4qexb   10.16.1.4                                                              gke-guestbook-f6a9e1a2-node-bjb5/10.240.145.243   name=redis-master   Running   50 minutes   
                                 master         redis                                                                                                             Running   50 minutes   
redis-slave-a90om    10.16.2.4                                                              gke-guestbook-f6a9e1a2-node-woin/10.240.158.209   name=redis-slave    Running   17 minutes   
                                 slave          kubernetes/redis-slave:v2                                                                                         Running   15 minutes   
redis-slave-xkeft    10.16.1.5                                                              gke-guestbook-f6a9e1a2-node-bjb5/10.240.145.243   name=redis-slave    Running   17 minutes   
                                 slave          kubernetes/redis-slave:v2                                                                                         Running   15 minutes
```

きました

```
$ kubectl get pods
POD                  IP          CONTAINER(S)   IMAGE(S)                                    HOST                                              LABELS              STATUS    CREATED          MESSAGE
frontend-ltoyt       10.16.2.5                                                              gke-guestbook-f6a9e1a2-node-woin/10.240.158.209   name=frontend       Running   3 minutes        
                                 php-redis      kubernetes/example-guestbook-php-redis:v2                                                                         Running   About a minute   
frontend-o6dla       10.16.1.6                                                              gke-guestbook-f6a9e1a2-node-bjb5/10.240.145.243   name=frontend       Running   3 minutes        
                                 php-redis      kubernetes/example-guestbook-php-redis:v2                                                                         Running   About a minute   
frontend-rurh0       10.16.0.4                                                              gke-guestbook-f6a9e1a2-node-zti0/10.240.209.195   name=frontend       Running   3 minutes        
                                 php-redis      kubernetes/example-guestbook-php-redis:v2                                                                         Running   About a minute   
redis-master-4qexb   10.16.1.4                                                              gke-guestbook-f6a9e1a2-node-bjb5/10.240.145.243   name=redis-master   Running   53 minutes       
                                 master         redis                                                                                                             Running   52 minutes       
redis-slave-a90om    10.16.2.4                                                              gke-guestbook-f6a9e1a2-node-woin/10.240.158.209   name=redis-slave    Running   19 minutes       
                                 slave          kubernetes/redis-slave:v2                                                                                         Running   18 minutes       
redis-slave-xkeft    10.16.1.5                                                              gke-guestbook-f6a9e1a2-node-bjb5/10.240.145.243   name=redis-slave    Running   19 minutes       
                                 slave          kubernetes/redis-slave:v2                                                                                         Running   18 minutes
```

これまでの流れでだいたいわかりました、次はサービスの設定ですね。

Step six: Create a guestbook web service with an external IP, and open up the firewall
--------------------------------------------------------------------------------------

redis の時とは違って今回は `type: LoadBalancer` という指定が入っています。ということは redis-slave は LoadBalancer ではないということなのかな。

```
$ kubectl create -f frontend-service.json
services/frontend
```

`frontend` というサービスができました

```
$ kubectl get services
NAME           LABELS                                    SELECTOR            IP(S)           PORT(S)
frontend       name=frontend                             name=frontend       10.19.248.123   80/TCP
kubernetes     component=apiserver,provider=kubernetes   10.19.240.1     443/TCP
redis-master   name=redis-master                         name=redis-master   10.19.253.109   6379/TCP
redis-slave    name=redis-slave                          name=redis-slave    10.19.244.0     6379/TCP 
```

次は `frontend` に外部からアクセスできるようにします

```
$ kubectl get nodes
NAME                               LABELS                                                    STATUS
gke-guestbook-f6a9e1a2-node-bjb5   kubernetes.io/hostname=gke-guestbook-f6a9e1a2-node-bjb5   Ready
gke-guestbook-f6a9e1a2-node-woin   kubernetes.io/hostname=gke-guestbook-f6a9e1a2-node-woin   Ready
gke-guestbook-f6a9e1a2-node-zti0   kubernetes.io/hostname=gke-guestbook-f6a9e1a2-node-zti0   Ready
```

Wordpress のと同じように node の `NAME` の `-name` までを使います。この場合 `gke-guestbook-f6a9e1a2-node` ですね

```
$ gcloud compute firewall-rules create --allow=tcp:80 \
    --target-tags=gke-guestbook-f6a9e1a2-node guestbook
Created [https://www.googleapis.com/compute/v1/projects/PROJECTID/global/firewalls/guestbook].
NAME      NETWORK SRC_RANGES RULES  SRC_TAGS TARGET_TAGS
guestbook default 0.0.0.0/0  tcp:80          gke-guestbook-f6a9e1a2-node
```

Gobal IP address を確認してアクセスしてみます (API の version 違いみたいな warning が表示されたけど)

```
$ kubectl describe services frontend
Name:			frontend
Labels:			name=frontend
Selector:		name=frontend
Type:			LoadBalancer
IP:			10.19.248.123
LoadBalancer Ingress:	203.0.113.110
Port:			 80/TCP
NodePort:		 30698/TCP
Endpoints:		10.16.0.4:80,10.16.1.6:80,10.16.2.5:80
Session Affinity:	None
No events. 
```

LoadBalancer Ingress の IP アドレスの port 80 にアクセスしてみましょう

{{< figure src="gke-guestbook.png" caption="GKE Tutorial Guestbook" >}}

わーい

Resizing a replication controller: Changing the number of web servers
---------------------------------------------------------------------

`frontend` の数を3から5に増やしてみましょう。Docker なので増やすのは簡単そうです、kubernetes では次の1行です

```
$ kubectl scale --replicas=5 rc frontend
```

増えましたね

```
$ kubectl get pods
POD                  IP          CONTAINER(S)   IMAGE(S)                                    HOST                                              LABELS              STATUS    CREATED         MESSAGE
frontend-ltoyt       10.16.2.5                                                              gke-guestbook-f6a9e1a2-node-woin/10.240.158.209   name=frontend       Running   31 minutes      
                                 php-redis      kubernetes/example-guestbook-php-redis:v2                                                                         Running   28 minutes      
frontend-o6dla       10.16.1.6                                                              gke-guestbook-f6a9e1a2-node-bjb5/10.240.145.243   name=frontend       Running   31 minutes      
                                 php-redis      kubernetes/example-guestbook-php-redis:v2                                                                         Running   28 minutes      
frontend-rurh0       10.16.0.4                                                              gke-guestbook-f6a9e1a2-node-zti0/10.240.209.195   name=frontend       Running   31 minutes      
                                 php-redis      kubernetes/example-guestbook-php-redis:v2                                                                         Running   28 minutes      
frontend-t67ho       10.16.2.6                                                              gke-guestbook-f6a9e1a2-node-woin/10.240.158.209   name=frontend       Running   18 seconds      
                                 php-redis      kubernetes/example-guestbook-php-redis:v2                                                                         Running   18 seconds      
frontend-xn9hx       10.16.0.5                                                              gke-guestbook-f6a9e1a2-node-zti0/10.240.209.195   name=frontend       Running   18 seconds      
                                 php-redis      kubernetes/example-guestbook-php-redis:v2                                                                         Running   18 seconds      
redis-master-4qexb   10.16.1.4                                                              gke-guestbook-f6a9e1a2-node-bjb5/10.240.145.243   name=redis-master   Running   About an hour   
                                 master         redis                                                                                                             Running   About an hour   
redis-slave-a90om    10.16.2.4                                                              gke-guestbook-f6a9e1a2-node-woin/10.240.158.209   name=redis-slave    Running   47 minutes      
                                 slave          kubernetes/redis-slave:v2                                                                                         Running   45 minutes      
redis-slave-xkeft    10.16.1.5                                                              gke-guestbook-f6a9e1a2-node-bjb5/10.240.145.243   name=redis-slave    Running   47 minutes      
                                 slave          kubernetes/redis-slave:v2                                                                                         Running   45 minutes
```

減らすのも同様です

```
$ kubectl scale --replicas=1 rc frontend
scaled
```

減った

```
$ kubectl get pods
POD                  IP          CONTAINER(S)   IMAGE(S)                                    HOST                                              LABELS              STATUS    CREATED         MESSAGE
frontend-o6dla       10.16.1.6                                                              gke-guestbook-f6a9e1a2-node-bjb5/10.240.145.243   name=frontend       Running   32 minutes      
                                 php-redis      kubernetes/example-guestbook-php-redis:v2                                                                         Running   30 minutes      
redis-master-4qexb   10.16.1.4                                                              gke-guestbook-f6a9e1a2-node-bjb5/10.240.145.243   name=redis-master   Running   About an hour   
                                 master         redis                                                                                                             Running   About an hour   
redis-slave-a90om    10.16.2.4                                                              gke-guestbook-f6a9e1a2-node-woin/10.240.158.209   name=redis-slave    Running   48 minutes      
                                 slave          kubernetes/redis-slave:v2                                                                                         Running   47 minutes      
redis-slave-xkeft    10.16.1.5                                                              gke-guestbook-f6a9e1a2-node-bjb5/10.240.145.243   name=redis-slave    Running   48 minutes      
                                 slave          kubernetes/redis-slave:v2                                                                                         Running   47 minutes
```

Cleanup
-------

破産しないように忘れずにお掃除を。

```
$ kubectl delete services frontend
services/frontend
```

```
$ gcloud beta container clusters delete guestbook
The following clusters will be deleted.
 - [guestbook] in [asia-east1-c]

Do you want to continue (Y/n)?  Y

Deleting cluster guestbook...done.
Deleted [https://container.googleapis.com/v1/projects/PROJECTID/zones/asia-east1-c/clusters/guestbook].
```

```
$ gcloud compute firewall-rules delete guestbook
The following firewalls will be deleted:
 - [guestbook]

Do you want to continue (Y/n)?  y

Deleted [https://www.googleapis.com/compute/v1/projects/PROJECTID/global/firewalls/guestbook].
```

念の為 [https://console.developers.google.com/](https://console.developers.google.com/) で消えてることを確認してみましょうか Pod, Replication Controller, Service を設定するための YAML / JSON について調べるといろいろわかるのかな
