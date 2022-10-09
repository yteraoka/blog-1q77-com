---
title: 'DigitalOcean で Mesos を試す'
date: 
draft: true
tags: ['Docker', 'Linux', 'Mesos']
---

https://mesosphere.com/downloads/ One-click Apps で Docker 1.10.3 on 14.04 を起動する

```
# Setup
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)

# Add the repository
echo "deb http://repos.mesosphere.io/${DISTRO} ${CODENAME} main" | \
  sudo tee /etc/apt/sources.list.d/mesosphere.list
sudo apt-get -y update
```

```
sudo apt-get -y install mesos
```

さて必要なもののインストールはできたっぽいのかな？ mesos は zookeeper を使用しているため、まずはこれの設定を行う。 DigitalOcean では Private Network を使うこともでき、今回はそれを有効にしてあり3台それぞれ次のようになっている

```
ubuntu-2gb-sgp1-01 [10.130.16.183]
ubuntu-2gb-sgp1-02 [10.130.20.122]
ubuntu-2gb-sgp1-03 [10.130.20.123]
```

3台の `/etc/zookeeper/conf/myid` の値をそれぞれ 1, 2, 3 とする。

```
# ubuntu-2gb-sgp1-01
echo "1" > /etc/zookeeper/conf/myid

# ubuntu-2gb-sgp1-02
echo "2" > /etc/zookeeper/conf/myid

# ubuntu-2gb-sgp1-03
echo "3" > /etc/zookeeper/conf/myid
```

`/etc/zookeeper/conf/zoo.cfg` に server.X を設定する

```
server.1=10.130.16.183:2888:3888
server.2=10.130.20.122:2888:3888
server.3=10.130.20.123:2888:3888
```

また、それぞれのサーバーが Global IP Address も持っているがそのアドレスで Listen する必要はないためぞれぞれのサーバーで clientPortAddress を設定する。

```
clientPortAddress=10.130.xx.xx
```

再起動

```
sudo service zookeeper restart
```

### Zookeeper の動作確認を行う

```
$ echo ruok | nc 10.130.16.183 2181
imok
```

```
ruok = Are you OK ?
imok = I'm OK
```

サーバーの情報を確認 リーダーの場合

```
# echo srvr | nc 10.130.16.183 2181
Zookeeper version: 3.4.5--1, built on 06/10/2013 17:26 GMT
Latency min/avg/max: 0/0/0
Received: 3
Sent: 2
Connections: 1
Outstanding: 0
Zxid: 0x300000000
Mode: leader
Node count: 4
```

フォロワーの場合

```
$ echo srvr | nc 10.130.16.183 2181
Zookeeper version: 3.4.5--1, built on 06/10/2013 17:26 GMT
Latency min/avg/max: 0/0/0
Received: 2
Sent: 1
Connections: 1
Outstanding: 0
Zxid: 0x100000000
Mode: follower
Node count: 4
```

### Zookeeper にデータをセットしてみる

クライアントスクリプトが `/usr/share/zookeeper/bin/zkCli.sh` にある `/foo` に `bar` という値をセットして他のサーバーでそれが見えることを確認する

```
$ /usr/share/zookeeper/bin/zkCli.sh -server 10.130.16.183:2181
Connecting to 10.130.16.183:2181
Welcome to ZooKeeper!
JLine support is enabled

WATCHER::

WatchedEvent state:SyncConnected type:None path:null
[zk: 10.130.16.183:2181(CONNECTED) 0] help
ZooKeeper -server host:port cmd args
	connect host:port
	get path [watch]
	ls path [watch]
	set path data [version]
	rmr path
	delquota [-n|-b] path
	quit 
	printwatches on|off
	create [-s] [-e] path data acl
	stat path [watch]
	close 
	ls2 path [watch]
	history 
	listquota path
	setAcl path acl
	getAcl path
	sync path
	redo cmdno
	addauth scheme auth
	delete path [version]
	setquota -n|-b val path
[zk: 10.130.16.183:2181(CONNECTED) 1] ls /
[zookeeper]
[zk: 10.130.16.183:2181(CONNECTED) 2] create /foo bar
Created /foo
[zk: 10.130.16.183:2181(CONNECTED) 3] ls /foo
[]
[zk: 10.130.16.183:2181(CONNECTED) 4] ls /
[foo, zookeeper]
[zk: 10.130.16.183:2181(CONNECTED) 5] get /foo
bar
cZxid = 0x300000003
ctime = Thu Mar 24 11:24:08 EDT 2016
mZxid = 0x300000003
mtime = Thu Mar 24 11:24:08 EDT 2016
pZxid = 0x300000003
cversion = 0
dataVersion = 0
aclVersion = 0
ephemeralOwner = 0x0
dataLength = 3
numChildren = 0
[zk: 10.130.16.183:2181(CONNECTED) 6] quit
Quitting...
```

別のサーバーで `/foo` の値を確認する

```
$ /usr/share/zookeeper/bin/zkCli.sh -server 10.130.20.122:2181
Connecting to 10.130.20.122:2181
Welcome to ZooKeeper!
JLine support is enabled

WATCHER::

WatchedEvent state:SyncConnected type:None path:null
[zk: 10.130.20.122:2181(CONNECTED) 0] ls /
[foo, zookeeper]
[zk: 10.130.20.122:2181(CONNECTED) 1] get /foo
bar
cZxid = 0x300000003
ctime = Thu Mar 24 11:24:08 EDT 2016
mZxid = 0x300000003
mtime = Thu Mar 24 11:24:08 EDT 2016
pZxid = 0x300000003
cversion = 0
dataVersion = 0
aclVersion = 0
ephemeralOwner = 0x0
dataLength = 3
numChildren = 0
[zk: 10.130.20.122:2181(CONNECTED) 2] quit
Quitting...
```

### Mesos の設定

### Mesos Master

`/etc/mesos/zk` に zookeeper の url を設定する

```
zk://10.130.16.183:2181,10.130.20.122:2181,10.130.20.123:2181/mesos
```

`/etc/mesos-master/cluster` にクラスタ名を設定する。 `/etc/mesos-master/ip`, `/etc/mesos-master/hostname` に IP アドレスを設定する。ip はそのノードを識別するために使われる。hostname は Web インターフェースで leader への redirect に使われる。

```
service mesos-master start
```

### Mesos Slave

`/etc/mesos/zk` に zookeeper の url を設定する

```
zk://10.130.16.183:2181,10.130.20.122:2181,10.130.20.123:2181/mesos
```

`/etc/mesos-slave/ip`, `/etc/mesos-save/hostname` に IP アドレスを設定する。 `/etc/mesos-slave/containerizers` に `docker,mesos` と設定する

```
service mesos-slave start
```

### Marathon

```
# Add the Mesosphere repository
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  python-software-properties software-properties-common
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)
echo "deb http://repos.mesosphere.io/${DISTRO} ${CODENAME} main" | \
  sudo tee /etc/apt/sources.list.d/mesosphere.list

# Install Java 8 from Oracle's PPA
sudo add-apt-repository ppa:webupd8team/java
sudo apt-get update -y
sudo apt-get install -y oracle-java8-installer oracle-java8-set-default
```

インストールが終わったら起動するだけ

```
sudo service marathon start
```

mesos UI の Frameworks からアクセスできます

```
$ ps -ef | grep marathon
root      8205     1 10 12:10 ?        00:00:19 java -Djava.library.path=/usr/local/lib:/usr/lib:/usr/lib64 -Djava.util.logging.SimpleFormatter.format=%2$s%5$s%6$s%n -Xmx512m -cp /usr/bin/marathon mesosphere.marathon.Main --zk zk://10.130.16.183:2181,10.130.20.122:2181,10.130.20.123:2181/marathon --master zk://10.130.16.183:2181,10.130.20.122:2181,10.130.20.123:2181/mesos
root      8219  8205  0 12:10 ?        00:00:00 logger -p user.info -t marathon[8205]
root      8220  8205  0 12:10 ?        00:00:00 logger -p user.notice -t marathon[8205]
root      8358  1442  0 12:13 pts/0    00:00:00 grep --color=auto marathon
```

どこから zk:// を拾ってきてるのかな？

### Chronos

```
sudo apt-get -y install chronos
```

```
# ps -ef | grep chronos
root      7672     1 99 12:34 ?        00:00:04 java -Djava.library.path=/usr/local/lib:/usr/lib64:/usr/lib -Djava.util.logging.SimpleFormatter.format=%2$s %5$s%6$s%n -Xmx512m -cp /usr/bin/chronos org.apache.mesos.chronos.scheduler.Main --zk_hosts 10.130.16.183:2181,10.130.20.122:2181,10.130.20.123:2181 --master zk://10.130.16.183:2181,10.130.20.122:2181,10.130.20.123:2181/mesos --http_port 4400
root      7683  7672  0 12:34 ?        00:00:00 logger -p user.info -t chronos[7672]
root      7684  7672  0 12:34 ?        00:00:00 logger -p user.notice -t chronos[7672]
root      7714  1416  0 12:34 pts/1    00:00:00 grep --color=auto chronos
```
