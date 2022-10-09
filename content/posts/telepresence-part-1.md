---
title: 'telepresence 入門 (1)'
date: Fri, 31 Dec 2021 14:54:43 +0000
draft: false
tags: ['Kubernetes', 'Kubernetes', 'telepresence']
---

[telepresence](https://github.com/telepresenceio/telepresence) というツールがあります。手元の端末が Kubernetes クラスタ内にいるかのような通信を可能にし、Kubernetes の Pod の Container への通信をインターセプトして手元の端末に流すことができます。これの仕組みを調べてみます。(以前は Python で書かれていたようですが、v2 は Go で書き直されたみたいです)

確認に使用した telepresence と mac の version

```
$ telepresence version
Client: v2.4.9 (api v3)

$ sw_vers
ProductName:	macOS
ProductVersion:	12.1
BuildVersion:	21C52
```

Kubernetes クラスタは GKE の v1.21.5-gke.1302

クラスタへの terffic-manager のデプロイ
----------------------------

[helm を使ってインストール](https://www.telepresence.io/docs/latest/install/helm/)することができます。デフォルトではクラスタワイドな設定になりますが、特定の namespace にのみインストールしたり、namespace 毎に権限を分けてインストールすることも可能です。

```
$ helm repo add datawire https://app.getambassador.io
$ helm repo update
```

Namespace の作成。デフォルトでは **ambassador** という namespace を使うことになっているようです。

```
$ kubectl create namespace ambassador

```

```
$ helm install traffic-manager --namespace ambassador datawire/telepresence
```

次のようなリソースが作成されます。

| Kind                         | Namespace  | Name                              |
|------------------------------|------------|-----------------------------------|
| ServiceAccount               | ambassador | traffic-manager                   |
| Secret                       | ambassador | mutator-webhook-tls               |
| ClusterRole                  | -          | traffic-manager-ambassador        |
| ClusterRoleBinding           | -          | traffic-manager-ambassador        |
| Role                         | ambassador | traffic-manager                   |
| RoleBinding                  | ambassador | traffic-manager                   |
| Service                      | ambassador | traffic-manager                   |
| Service                      | ambassador | agent-injector                    |
| Deployment                   | ambassador | traffic-manager                   |
| MutatingWebhookConfiguration | -          | agent-injector-webhook-ambassador |

テスト用 Service / Deployment のデプロイ
-------------------------------

default namespace に hello という Deployment をデプロイし、 expose コマンドで Service を作成します。

```
$ kubectl create deploy hello --image=k8s.gcr.io/echoserver:1.4
```

```
$ kubectl expose deploy hello --port 80 --target-port 8080
```

```
$ kubectl get ns,svc,deploy,po
NAME                        STATUS   AGE
namespace/ambassador        Active   104m
namespace/default           Active   159m
namespace/kube-node-lease   Active   159m
namespace/kube-public       Active   159m
namespace/kube-system       Active   159m

NAME                 TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/hello        ClusterIP   172.16.1.153   80/TCP    11s
service/kubernetes   ClusterIP   172.16.0.1     443/TCP   159m

NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/hello   1/1     1            1           20s

NAME                         READY   STATUS    RESTARTS   AGE
pod/hello-79dbd5fdfb-t59nr   1/1     Running   0          13s 
```

telepresence connect
--------------------

手元の端末で `telepresence connect` コマンドを実行することで手元の端末と Kubernetes クラスタ間の tunnel を掘る。root 権限で実行する必要のあるものがあるため、sudo のパスワード入力を求められます。

```
$ telepresence connect
Launching Telepresence Root Daemon
Need root privileges to run: /Users/teraoka/bin/telepresence daemon-foreground /Users/teraoka/Library/Logs/telepresence '/Users/teraoka/Library/Application Support/telepresence' ''
Password:
Launching Telepresence User Daemon
Connected to context gke_MY_PROJECT_ID_asia-northeast1-a_CLUSTER_NAME (https://203.0.113.123)
```

`telepresence version` コマンドで root で実行する daemon をユーザー権限で実行する daemon の 2 つが実行されているのがわかります。

```
$ telepresence version
Client: v2.4.9 (api v3)
Root Daemon: v2.4.9 (api v3)
User Daemon: v2.4.9 (api v3)
```

手元の curl からクラスタ内へのアクセス
----------------------

たったこれだけで、**あら不思議** `curl hello.default` とするとクラスタ内の Service に対してアクセスできています。

```
$ curl -sv hello.default
*   Trying 172.16.1.153:80...
* Connected to hello.default (172.16.1.153) port 80 (#0)
> GET / HTTP/1.1
> Host: hello.default
> User-Agent: curl/7.79.1
> Accept: */*
> 
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< Server: nginx/1.10.0
< Date: Fri, 31 Dec 2021 08:27:43 GMT
< Content-Type: text/plain
< Transfer-Encoding: chunked
< Connection: keep-alive
< 
CLIENT VALUES:
client_address=172.17.0.131
command=GET
real path=/
query=nil
request_version=1.1
request_uri=http://hello.default:8080/

SERVER VALUES:
server_version=nginx: 1.10.0 - lua: 10001

HEADERS RECEIVED:
accept=*/*
host=hello.default
user-agent=curl/7.79.1
BODY:
* Connection #0 to host hello.default left intact
-no body in request-
```

hello.default が 172.16.1.153 と名前解決されているのがどうしてなのか気になります。答えは下にありますが、これは mac の場合です、Linux や Windows ではまた別の仕組みが使われているのだろうと思われます。(他の環境も含めて [DNS resolution](https://www.getambassador.io/docs/telepresence/latest/reference/routing/#dns-resolution) に書かれていました)

サーバー側から見た client\_address は 172.17.0.131 となっています、これは ambassador namespace にデプロイされている traffic-manager Deployment の Pod が持つ IP アドレスです。この Pod 経由でアクセスしていることがわかります。

```
$ kubectl get pod -n ambassador -o wide
NAME                               READY   STATUS    RESTARTS   AGE    IP             NODE                                                NOMINATED NODE   READINESS GATES
traffic-manager-5cb99c9fd6-mv6v9   1/1     Running   0          124m   172.17.0.131   gke-teraoka-blue-teraoka-blue-pool1-48fb0873-m4cw   <none>           <none>
```

telepresence プロセスの役割
--------------------

telepresence のぞれぞれのプロセスが何をやっているのかを確認してみます。

とりあえず ps コマンドで確認。

```
$ ps auxww | grep telepresence
teraoka          72020   0.0  0.0 34132084    872 s003  R+    5:18PM   0:00.00 grep telepresence
teraoka          71885   0.0  0.3 34956040  46184 s000  S     5:14PM   0:00.65 /Users/teraoka/bin/telepresence connector-foreground
root             71881   0.0  0.2 34966080  35296 s000  S     5:14PM   0:00.27 /Users/teraoka/bin/telepresence daemon-foreground /Users/teraoka/Library/Logs/telepresence /Users/teraoka/Library/Application Support/telepresence 
root             71880   0.0  0.0 34142464   4596 s000  S     5:14PM   0:00.01 sudo --non-interactive --preserve-env /Users/teraoka/bin/telepresence daemon-foreground /Users/teraoka/Library/Logs/telepresence /Users/teraoka/Library/Application Support/telepresence 

```

```
$ pstree -w 71880
-+= 71880 root sudo --non-interactive --preserve-env /Users/teraoka/bin/telepresence daemon-foreground /Users/teraoka/Library/Logs/telepresence /Users/teraoka/Library/Application Support/telepresence 
 \--- 71881 root /Users/teraoka/bin/telepresence daemon-foreground /Users/teraoka/Library/Logs/telepresence /Users/teraoka/Library/Application Support/telepresence
```

### lsof で確認

root daemon

```
$ sudo lsof -nPp 71881
COMMAND     PID USER   FD      TYPE             DEVICE SIZE/OFF                NODE NAME
teleprese 71881 root  cwd       DIR                1,9      512            47512210 /Users/teraoka/ghq/github.com/yteraoka/terraform-examples/gcp/gke
teleprese 71881 root  txt       REG                1,9 77231136            74147315 /Users/teraoka/bin/telepresence
teleprese 71881 root  txt       REG                1,9    46096            74099023 /Library/Preferences/Logging/.plist-cache.1VLWA6Q0
teleprese 71881 root  txt       REG                1,9  2160672 1152921500312811906 /usr/lib/dyld
teleprese 71881 root  txt       REG                1,9    32768            74099068 /private/var/db/mds/messages/se_SecurityMessages
teleprese 71881 root  txt       REG                1,9   114087            74099365 /private/var/db/analyticsd/events.whitelist
teleprese 71881 root  txt       REG                1,9 29638976 1152921500312823656 /usr/share/icu/icudt68l.dat
teleprese 71881 root    0r      CHR                3,2      0t0                 317 /dev/null
teleprese 71881 root    1w      REG                1,9     2099            74169276 /Users/teraoka/Library/Logs/telepresence/daemon.log
teleprese 71881 root    2w      REG                1,9     2099            74169276 /Users/teraoka/Library/Logs/telepresence/daemon.log
teleprese 71881 root    3u   KQUEUE                                                 count=0, state=0xa
teleprese 71881 root    4      PIPE 0xd904b24160bf46ff    16384                     ->0x1ac3420f1be0c501
teleprese 71881 root    5      PIPE 0x1ac3420f1be0c501    16384                     ->0xd904b24160bf46ff
teleprese 71881 root    6w      REG                1,9     2099            74169276 /Users/teraoka/Library/Logs/telepresence/daemon.log
teleprese 71881 root    7u    systm 0x4715bfb02f5e8bd7      0t0                     [ctl com.apple.net.utun_control id 4 unit 4]
teleprese 71881 root    8      PIPE 0x77446814497e3b77    16384                     ->0x67dbd1c5970420d8
teleprese 71881 root    9u     unix 0x4715bfb02f991c3f      0t0                     /var/run/telepresence-daemon.socket
teleprese 71881 root   10      PIPE 0x67dbd1c5970420d8    16384                     ->0x77446814497e3b77
teleprese 71881 root   11   NPOLICY                                                 
teleprese 71881 root   12u     unix 0x4715bfb02f991f5f      0t0                     /var/run/telepresence-daemon.socket
teleprese 71881 root   13u     unix 0x4715bfb02f9944df      0t0                     ->0x4715bfb02f9945a7
teleprese 71881 root   14u     IPv4 0x4715bfb4fc950c67      0t0                 UDP *:51812
teleprese 71881 root   15u     unix 0x4715bfb02f993477      0t0                     ->0x4715bfb02f99353f
```

root daemon は 51812/udp を listen しています。後でわかりますが、これは DNS サーバーです。クラスタのドメインはここに問い合わせが行われます。utun_control というのは tunnel の制御でしょうか。

utun3 といネットワークデバイスが作成されており

```
$ ifconfig utun3
utun3: flags=8051<UP,POINTOPOINT,RUNNING,MULTICAST> mtu 1500
	inet 172.16.0.0 --> 172.16.0.1 netmask 0xfffff000 
	inet 172.17.0.0 --> 172.17.0.1 netmask 0xffffffc0 
	inet 172.17.0.64 --> 172.17.0.1 netmask 0xffffffc0 
	inet 172.17.0.128 --> 172.17.0.1 netmask 0xffffffc0 
```

Pod や Service 用サブネットの route がその utun3 へ向けられています。

```
$ netstat -nr | grep utun3
172.16/20          172.16.0.1         UGCS            utun3       
172.16.0.1         172.16.0.0         UH              utun3       
172.16.15.255      172.16.0.1         UGHW3I          utun3     22
172.17/26          172.17.0.1         UGCS            utun3       
172.17.0.1         172.17.0.0         UH              utun3       
172.17.0.63        172.17.0.1         UGHW3I          utun3     22
172.17.0.64/26     172.17.0.1         UGCS            utun3       
172.17.0.127       172.17.0.1         UGHW3I          utun3     22
172.17.0.128/26    172.17.0.1         UGCS            utun3       
172.17.0.191       172.17.0.1         UGHW3I          utun3     22
```

user daemon

```
$ lsof -nPp 71885
COMMAND     PID    USER   FD      TYPE             DEVICE SIZE/OFF                NODE NAME
teleprese 71885 teraoka  cwd       DIR                1,9      512            47512210 /Users/teraoka/ghq/github.com/yteraoka/terraform-examples/gcp/gke
teleprese 71885 teraoka  txt       REG                1,9 77231136            74147315 /Users/teraoka/bin/telepresence
teleprese 71885 teraoka  txt       REG                1,9    46096            74099023 /Library/Preferences/Logging/.plist-cache.1VLWA6Q0
teleprese 71885 teraoka  txt       REG                1,9    32768            74100907 /private/var/db/mds/messages/501/se_SecurityMessages
teleprese 71885 teraoka  txt       REG                1,9  2160672 1152921500312811906 /usr/lib/dyld
teleprese 71885 teraoka  txt       REG                1,9   114087            74099365 /private/var/db/analyticsd/events.whitelist
teleprese 71885 teraoka    0r      CHR                3,2      0t0                 317 /dev/null
teleprese 71885 teraoka    1w      REG                1,9     1498            74169289 /Users/teraoka/Library/Logs/telepresence/connector.log
teleprese 71885 teraoka    2w      REG                1,9     1498            74169289 /Users/teraoka/Library/Logs/telepresence/connector.log
teleprese 71885 teraoka    3u   KQUEUE                                                 count=0, state=0xa
teleprese 71885 teraoka    4      PIPE 0xfc30aea6068d98ef    16384                     ->0xd5d97fbdd54a6017
teleprese 71885 teraoka    5      PIPE 0xd5d97fbdd54a6017    16384                     ->0xfc30aea6068d98ef
teleprese 71885 teraoka    6w      REG                1,9     1498            74169289 /Users/teraoka/Library/Logs/telepresence/connector.log
teleprese 71885 teraoka    7u     unix 0x4715bfb02f992347      0t0                     /tmp/telepresence-connector.socket
teleprese 71885 teraoka    8      PIPE 0xa124ff493681e691    16384                     ->0x40a1939f617879e5
teleprese 71885 teraoka    9      PIPE 0x40a1939f617879e5    16384                     ->0xa124ff493681e691
teleprese 71885 teraoka   10u     IPv6 0x4715bfb9c79fa6f7      0t0                 TCP *:53443 (LISTEN)
teleprese 71885 teraoka   12u     IPv4 0x4715bfbe96aaa46f      0t0                 TCP 192.168.210.119:53444->203.0.113.123:443 (ESTABLISHED)
teleprese 71885 teraoka   13u     unix 0x4715bfb02f9919e7      0t0                     ->0x4715bfb02f991f5f
teleprese 71885 teraoka   14   NPOLICY                                                 
teleprese 71885 teraoka   15u     unix 0x4715bfb02f992027      0t0                     ->0x4715bfb02f99434f
teleprese 71885 teraoka   17u     IPv4 0x4715bfbe9eb6546f      0t0                 TCP 192.168.210.119:53446->203.0.113.123:443 (ESTABLISHED)
teleprese 71885 teraoka   18u     unix 0x4715bfb02f9945a7      0t0                     /tmp/telepresence-connector.socket
```

Kubernetes の API Server と通信しているのは user daemon のようです。

### ログファイルを確認

lsof でログファイルらしきファイルが確認できたので中身を見てみます。

root daemon のログ

`/Users/teraoka/Library/Logs/telepresence/daemon.log`

```
2021-12-31 17:14:09.3150 info    Logging at this level "info"
2021-12-31 17:14:09.3151 info    ---
2021-12-31 17:14:09.3152 info    Telepresence daemon v2.4.9 (api v3) starting...
2021-12-31 17:14:09.3152 info    PID is 71881
2021-12-31 17:14:09.3152 info    
2021-12-31 17:14:09.4008 info    daemon/server-grpc : gRPC server started
2021-12-31 17:14:10.6945 info    daemon/server-grpc/conn=2 : Adding never-proxy subnet 203.0.113.123/32
2021-12-31 17:14:10.7615 info    daemon/watch-cluster-info : Adding service subnet 172.16.0.0/20
2021-12-31 17:14:10.7616 info    daemon/watch-cluster-info : Adding pod subnet 172.17.0.0/26
2021-12-31 17:14:10.7616 info    daemon/watch-cluster-info : Adding pod subnet 172.17.0.64/26
2021-12-31 17:14:10.7617 info    daemon/watch-cluster-info : Adding pod subnet 172.17.0.128/26
2021-12-31 17:14:10.7621 info    daemon/watch-cluster-info : Setting cluster DNS to 172.16.0.10
2021-12-31 17:14:10.7621 info    daemon/watch-cluster-info : Setting cluster domain to "cluster.local."
2021-12-31 17:14:10.7778 info    daemon/server-router/MGR stream : Connected to Manager 2.4.9
2021-12-31 17:14:10.7983 info    daemon/server-dns : Generated new /etc/resolver/telepresence.local
2021-12-31 17:14:10.7985 info    daemon/server-dns/SearchPaths : setting search paths ambassador default kube-node-lease kube-public kube-system
2021-12-31 17:14:10.7987 info    daemon/server-dns/SearchPaths : Generated new /etc/resolver/telepresence.kube-system.local
2021-12-31 17:14:10.7991 info    daemon/server-dns/SearchPaths : Generated new /etc/resolver/telepresence.tel2-search.local
2021-12-31 17:14:10.7994 info    daemon/server-dns/SearchPaths : Generated new /etc/resolver/telepresence.ambassador.local
2021-12-31 17:14:10.7996 info    daemon/server-dns/SearchPaths : Generated new /etc/resolver/telepresence.default.local
2021-12-31 17:14:10.7999 info    daemon/server-dns/SearchPaths : Generated new /etc/resolver/telepresence.kube-node-lease.local
2021-12-31 17:14:10.8001 info    daemon/server-dns/SearchPaths : Generated new /etc/resolver/telepresence.kube-public.local
```

root daemon は watch-cluster-info で Service の Subnet や Node 毎に作成される Pod の Subnet をクラスタに合わせて routing 設定しているようですし、DNS の forward 先の管理、そして /etc/resolver 配下に cluster 側に向けるドメイン用のファイルを管理しています。

例えば /etc/resolver/telepresence.kube-system.local の中身は次のようになっており、kube-system で終わるドメインの DNS の問い合わせは 127.0.0.1:51812 に送られるようになっています。51812/udp は root daemon が listen しており、tunnel 経由で Kubernetes 内の DNS Service に転送されてるようになっているみたいです。mac の /etc/resolver の仕組みを知らず、Linux の LD\_PRELOAD 的なものが mac にもあってそれが使われているのだろうと調べてて、そんな設定が見つからずしばらく悩んでしまっていました...

```
$ cat /etc/resolver/telepresence.kube-system.local
# Generated by telepresence
port 51812
domain kube-system
nameserver 127.0.0.1
```

127.0.0.1:51812 に対して DNS の問い合わせを投げると結果が返ってきます。

mac のこの設定は `scutil --dns` でも確認できます。

```
$ dig +short @127.0.0.1 -p 51812 hello.default.svc.cluster.local a
172.16.1.153
```

user daemon のログ

`/Users/teraoka/Library/Logs/telepresence/connector.log`

```
2021-12-31 17:14:09.5593 info    Logging at this level "info"
2021-12-31 17:14:09.5971 info    ---
2021-12-31 17:14:09.5972 info    Telepresence Connector v2.4.9 (api v3) starting...
2021-12-31 17:14:09.5972 info    PID is 71885
2021-12-31 17:14:09.5972 info    
2021-12-31 17:14:09.5974 info    connector/server-grpc : gRPC server started
2021-12-31 17:14:09.7740 info    connector/background-init : Connecting to daemon...
2021-12-31 17:14:09.7747 info    connector/background-init : Connecting to k8s cluster...
2021-12-31 17:14:09.8611 info    connector/background-init : Server version v1.21.5-gke.1302
2021-12-31 17:14:09.8612 info    connector/background-init : Context: gke_MY_PROJECT_ID_asia-northeast1-a_CLUSTER_NAME
2021-12-31 17:14:09.8613 info    connector/background-init : Server: https://203.0.113.123
2021-12-31 17:14:09.8613 info    connector/background-init : Connected to context gke_MY_PROJECT_ID_asia-northeast1-a_CLUSTER_NAME (https://203.0.113.123)
2021-12-31 17:14:10.0374 info    connector/background-init : Connecting to traffic manager...
2021-12-31 17:14:10.0375 info    connector/background-init : Waiting for TrafficManager to connect
2021/12/31 17:14:10 Patching synced Namespace 6ed04e58-22c9-4b10-87a2-690867ae2371
2021-12-31 17:14:10.1281 info    connector/background-manager : Existing Traffic Manager 2.4.9 not owned by cli or does not need upgrade, will not modify
2021/12/31 17:19:10 Patching synced Namespace 6ed04e58-22c9-4b10-87a2-690867ae2371
```

### telepresence status

`telepresence status` コマンドで2つの daemon プロセスの状況を確認できます。DNS 周りの仕組みを見てて、誰かが com とか jp とか TLD と同じ namespace 作ってしまうと困るだろうなと思ってたのですが、いくつかはデフォルトで Exclude suffixes に入っているのですね。`telepresence connect` コマンドの `--mapped-namespaces` オプションで必要な namespace だけをコンマ区切りで並べることもできます。

```
$ telepresence status
Root Daemon: Running
  Version   : v2.4.9 (api 3)
  DNS       :
    Remote IP       : 172.16.0.10
    Exclude suffixes: [.arpa .com .io .net .org .ru]
    Include suffixes: []
    Timeout         : 4s
  Also Proxy : (0 subnets)
  Never Proxy: (1 subnets)
User Daemon: Running
  Version           : v2.4.9 (api 3)
  Ambassador Cloud  : Logged out
  Status            : Connected
  Kubernetes server : https://203.0.113.123
  Kubernetes context: gke_MY_PROJECT_ID_asia-northeast1-a_CLUSTER_NAME
  Telepresence proxy: ON (networking to the cluster is enabled)
  Intercepts        : 0 total
```

part 1 はここまで。Kubernetes クラスタ側からのアクセスは[次回](/2022/01/telepresence-part-2/)。

`telepresence connect` で起動した 2 つの daemon プロセスは `telepresence quit` で終了できます。
