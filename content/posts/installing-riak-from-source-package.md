---
title: 'Installing Riak from source package'
date: Sun, 13 Jan 2013 06:12:08 +0000
draft: false
tags: ['Erlang', 'Linux', 'Riak']
---

運用が楽な KVS ということで Riak をテストしてみる 1サーバーに複数 node を起動させてクラスタのテストをする ( [Running-Multiple-Nodes-on-One-Host](http://docs.basho.com/riak/1.3.0/cookbooks/Basic-Cluster-Setup/#Running-Multiple-Nodes-on-One-Host) ) ために source から入れてみる ( bin/riak は shell script でこいつを書き換えれば各種ディレクトリを指定できるので package で Riak を入れても1サーバーで複数起動させられそう )

まずは Erlang のインストール
------------------

[Installing Erlang](http://docs.basho.com/riak/1.3.0/tutorials/installation/Installing-Erlang/) を参考にインストールする 安易に最新版を使ってはいけない。Riak 1.2, 1.2.1 の場合は R15B01 をインストールする。 Ruby の rvm みたいな [kerl](https://github.com/spawngrid/kerl "kerl - GitHub") を使う

```
$ curl -o ~/bin/kerl https://raw.github.com/spawngrid/kerl/master/kerl
$ chmod a+x ~/bin/kerl
$ sudo yum install gcc glibc-devel make ncurses-devel openssl-devel autoconf
$ kerl build R15B01 r15b01
Getting the available releases from erlang.org...
Downloading otp_src_R15B01.tar.gz to /home/ytera/.kerl/archives
Getting the checksum file from erlang.org...
Verifying archive checksum...
Checksum verified (f12d00f6e62b36ad027d6c0c08905fad)
Extracting source code
Building Erlang/OTP R15B01 (r15b01), please wait...
Erlang/OTP R15B01 (r15b01) has been successfully built
$ kerl list builds
R15B01,r15b01
$ kerl install r15b01 ~/erlang/r15b01
Installing Erlang/OTP R15B01 (r15b01) in /home/ytera/erlang/r15b01...
You can activate this installation running the following command:
. /home/ytera/erlang/r15b01/activate
Later on, you can leave the installation typing:
kerl_deactivate
$ kerl list installations
r15b01 /home/ytera/erlang/r15b01
$ kerl active
No Erlang/OTP kerl installation is currently active
$ . /home/ytera/erlang/r15b01/activate
$ kerl active
The current active installation is:
/home/ytera/erlang/r15b01
$ erl -version
Erlang (SMP,ASYNC_THREADS,HIPE) (BEAM) emulator version 5.9.1
```

次は Riak を GitHub から Download してインストール
-------------------------------------

[Installing Riak from Source](http://docs.basho.com/riak/1.3.0/tutorials/installation/Installing-Riak-from-Source/) を参考にインストール

```
$ git clone git://github.com/basho/riak.git
Initialized empty Git repository in /home/ytera/riak/.git/
remote: Counting objects: 13705, done.
remote: Compressing objects: 100% (4461/4461), done.
remote: Total 13705 (delta 8951), reused 13573 (delta 8837)
Receiving objects: 100% (13705/13705), 10.16 MiB | 3.49 MiB/s, done.
Resolving deltas: 100% (8951/8951), done.
$ cd riak
$ make rel
```

クラスタを構成する3つの node を起動するための準備
----------------------------

### まずはコピー

```
$ for i in 1 2 3; do cp -a rel/riak rel/riak$i; done
```

### port を変更する

Riak は Protocol Buffer (pb\_port) と HTTP (http) をサポートしている pb\_port: 8087 -> 8187,8287,8387 (Protocol Buffer) http: 8098 -> 8198, 8298, 8398 (HTTP or HTTPS) handoff\_port: 8099 -> 8199,9299,8399 (cluster 制御用) Protocol Buffer と HTTP では他のサーバーからのアクセスできるように bind address を 0.0.0.0 に変更している

```
$ vi rel/riak1/etc/app.config
$ diff -u rel/riak{,1}/etc/app.config
--- rel/riak/etc/app.config	2013-01-12 23:54:38.000000000 +0900
+++ rel/riak1/etc/app.config	2013-01-13 14:18:45.052914322 +0900
@@ -12,11 +12,11 @@
 
             %% pb_ip is the IP address that the Riak Protocol Buffers interface
             %% will bind to.  If this is undefined, the interface will not run.
-            {pb_ip,   "127.0.0.1" },
+            {pb_ip,   "0.0.0.0" },
 
             %% pb_port is the TCP port that the Riak Protocol Buffers interface
             %% will bind to
-            {pb_port, 8087 }
+            {pb_port, 8187 }
             ]},
 
  %% Riak Core config
@@ -30,7 +30,7 @@
 
               %% http is a list of IP addresses and TCP ports that the Riak
               %% HTTP interface will bind.
-              {http, [ {"127.0.0.1", 8098 } ]},
+              {http, [ {"0.0.0.0", 8198 } ]},
 
               %% https is a list of IP addresses and TCP ports that the Riak
               %% HTTPS interface will bind.
@@ -45,7 +45,7 @@
 
               %% riak_handoff_port is the TCP port that Riak uses for
               %% intra-cluster data handoff.
-              {handoff_port, 8099 },
+              {handoff_port, 8199 },
 
               %% To encrypt riak_core intra-cluster data handoff traffic,
               %% uncomment the following line and edit its path to an
$ vi rel/riak1/etc/vm.args
$ diff -u rel/riak{,1}/etc/vm.args
--- rel/riak/etc/vm.args	2013-01-12 23:54:38.000000000 +0900
+++ rel/riak1/etc/vm.args	2013-01-13 14:18:53.802141554 +0900
@@ -1,5 +1,5 @@
 ## Name of the riak node
--name riak@127.0.0.1
+-name riak1@127.0.0.1
 
 ## Cookie for distributed erlang.  All nodes in the same cluster
 ## should use the same cookie or they will not be able to communicate.
$ vi rel/riak2/etc/vm.args
$ vi rel/riak3/etc/vm.args
```

Riak を起動させて、クラスターを組む
--------------------

一つ目の Riak を起動させると epmd という process も起動する、これは Riak の node がお互いに探しあうために使われているようだ ([Riak Users - epmd daemon runs after riak stops](http://riak-users.197444.n3.nabble.com/epmd-daemon-runs-after-riak-stops-td4025546.html)) そして、Riak を停止しても epmd は停止しないが、これは放置で問題ないとのこと

```
$ rel/riak1/bin/riak start
$ rel/riak2/bin/riak start
$ rel/riak3/bin/riak start
$ rel/riak2/bin/riak-admin cluster join riak1@127.0.0.1
Success: staged join request for 'riak2@127.0.0.1' to 'riak1@127.0.0.1'
$ rel/riak3/bin/riak-admin cluster join riak1@127.0.0.1
Success: staged join request for 'riak3@127.0.0.1' to 'riak1@127.0.0.1'
$ rel/riak2/bin/riak-admin cluster plan
=============================== Staged Changes ================================
Action         Nodes(s)
-------------------------------------------------------------------------------
join           'riak2@127.0.0.1'
join           'riak3@127.0.0.1'
-------------------------------------------------------------------------------


NOTE: Applying these changes will result in 1 cluster transition

###############################################################################
                         After cluster transition 1/1
###############################################################################

================================= Membership ==================================
Status     Ring    Pending    Node
-------------------------------------------------------------------------------
valid     100.0%     34.4%    'riak1@127.0.0.1'
valid       0.0%     32.8%    'riak2@127.0.0.1'
valid       0.0%     32.8%    'riak3@127.0.0.1'
-------------------------------------------------------------------------------
Valid:3 / Leaving:0 / Exiting:0 / Joining:0 / Down:0

WARNING: Not all replicas will be on distinct nodes

Transfers resulting from cluster changes: 42
  21 transfers from 'riak1@127.0.0.1' to 'riak3@127.0.0.1'
  21 transfers from 'riak1@127.0.0.1' to 'riak2@127.0.0.1'

$ rel/riak2/bin/riak-admin cluster commit
Cluster changes committed
```

これで 8198,8298,8398 port にブラウザでアクセス可能となる。

テスト
---

データを登録してみる (キーの値を指定しない場合は自動採番される)

```
$ curl -v -d 'this is a test' -H "Content-Type: text/plain" http://127.0.0.1:8198/riak/test
* About to connect() to 127.0.0.1 port 8198 (#0)
*   Trying 127.0.0.1... connected
* Connected to 127.0.0.1 (127.0.0.1) port 8198 (#0)
> POST /riak/test HTTP/1.1
> User-Agent: curl/7.19.7 (x86_64-redhat-linux-gnu) libcurl/7.19.7 NSS/3.13.1.0 zlib/1.2.3 libidn/1.18 libssh2/1.2.2
> Host: 127.0.0.1:8198
> Accept: */*
> Content-Type: text/plain
> Content-Length: 14
> 
< HTTP/1.1 201 Created
< Vary: Accept-Encoding
< Server: MochiWeb/1.1 WebMachine/1.9.2 (someone had painted it blue)
< Location: /riak/test/8ug82sCaLj0HjrnKh8RxhyNVTW9
< Date: Sun, 13 Jan 2013 05:49:38 GMT
< Content-Type: text/plain
< Content-Length: 0
< 
* Connection #0 to host 127.0.0.1 left intact
* Closing connection #0
```

登録したデータの確認 3つのどの node にアクセスしても取得可能

```
$ curl http://127.0.0.1:8198/riak/test/8ug82sCaLj0HjrnKh8RxhyNVTW9
this is a test
$ curl http://127.0.0.1:8298/riak/test/8ug82sCaLj0HjrnKh8RxhyNVTW9
this is a test
$ curl http://127.0.0.1:8398/riak/test/8ug82sCaLj0HjrnKh8RxhyNVTW9
this is a test
```

クラスタのオペレーションやもっと高度なテストはまた今度。
