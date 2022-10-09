---
title: 'CentOS7のMariaDB(MySQL)をDRBDでHA化'
date: Tue, 13 Jun 2017 14:45:31 +0000
draft: false
tags: ['Corosync', 'DRBD', 'MariaDB', 'MySQL', 'Pacemaker']
---

[Rancher の冗長構成](/2017/01/rancher-on-digitalocean-part2/)には MySQL の冗長化が必要になります。そこで Replication より単純かなということでまずは DRBD + Pacemaker + Corosync 構成を試してみます。

### 構成

db1 \[192.168.122.11\], db2 \[192.16.122.12\] という2台のホストで VIP \[192.168.122.10\] をもたせます。 KVM に CentOS 7 をインストールして試しました。/dev/cl/drbd0 という LogicalVolume を DRBD に使用した。

### ホスト名設定

DRBD の設定でのサーバー指定は `hostname` コマンドの出力と一致する必要があるので `db1`, `db2` としておきます。

```
[db1]# hostnamectl set-hostname db1
[db2]# hostnamectl set-hostname db2
```

### IPv6 を無効にする

```
[ALL]# echo "net.ipv6.conf.all.disable_ipv6 = 1" > /etc/sysctl.d/disable-ipv6.conf
[ALL]# echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.d/disable-ipv6.conf
[ALL]# sysctl -p
```

### firewalld 設定

```
[ALL]# systemctl start firewalld
[ALL]# systemctl enable firewalld
[ALL]# firewall-cmd --add-service high-availability
[ALL]# firewall-cmd --add-service high-availability --permanent
```

### pcs, pacemaker, corosync のインストール

```
[ALL]# yum install -y pcs
```

pcs の依存で pacemaker, corosync, resource-agents などもインストールされます pcs で使われる `hacluster` ユーザーのパスワード設定

```
[ALL]# echo passwd | passwd hacluster --stdin
```

`pcsd` の起動

```
[ALL]# systemctl start pcsd
[ALL]# systemctl enable pcsd
```

1方のサーバーでクラスタ間の認証を通す

```
[db1]# pcs cluster auth db1 db2 -u hacluster -p passwd
```

`/var/lib/pcsd/tokens` に token が保存される

### クラスタの作成

`mysql_cluster` という名前のクラスタをセットアップします

```
[db1]# pcs cluster setup --name mysql_cluster db1 db2
```

```
[root@db1 ~]# pcs cluster setup --name mysql_cluster db1 db2
Destroying cluster on nodes: db1, db2...
db1: Stopping Cluster (pacemaker)...
db2: Stopping Cluster (pacemaker)...
db1: Successfully destroyed cluster
db2: Successfully destroyed cluster

Sending cluster config files to the nodes...
db1: Succeeded
db2: Succeeded

Synchronizing pcsd certificates on nodes db1, db2...
db1: Success
db2: Success

Restarting pcsd on the nodes in order to reload the certificates...
db1: Success
db2: Success
```

`/etc/corosync/corosync.conf` が作成されています

```
[root@db1 ~]# cat /etc/corosync/corosync.conf
totem {
    version: 2
    secauth: off
    cluster_name: mysql_cluster
    transport: udpu
}

nodelist {
    node {
        ring0_addr: db1
        nodeid: 1
    }

    node {
        ring0_addr: db2
        nodeid: 2
    }
}

quorum {
    provider: corosync_votequorum
    two_node: 1
}

logging {
    to_logfile: yes
    logfile: /var/log/cluster/corosync.log
    to_syslog: yes
}
```

### クラスタの起動

```
[db1]# pcs cluster start --all
```

```
[root@db1 ~]# pcs cluster start --all
db1: Starting Cluster...
db2: Starting Cluster...
```

`corosync` の状態確認

```
[root@db1 ~]# pcs status corosync

Membership information
----------------------
    Nodeid      Votes Name
         1          1 db1 (local)
         2          1 db2
```

```
[root@db1 ~]# pcs status
Cluster name: mysql_cluster
WARNING: no stonith devices and stonith-enabled is not false
Stack: corosync
Current DC: db2 (version 1.1.15-11.el7_3.4-e174ec8) - partition with quorum
Last updated: Sun Jun 11 15:29:22 2017		Last change: Sun Jun 11 15:25:58 2017 by hacluster via crmd on db2

2 nodes and 0 resources configured

Online: [ db1 db2 ]

No resources


Daemon Status:
  corosync: active/disabled
  pacemaker: active/disabled
  pcsd: active/enabled
```

### DRBD のインストール

```
[ALL]# rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
[ALL]# rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
[ALL]# yum install -y kmod-drbd84 drbd84-utils
```

DRBD は SELinux が `enforcing` な環境では問題があるらしく次のようにして回避する

```
[ALL]# yum install -y policycoreutils-python
[ALL]# semanage permissive -a drbd_t
```

### DRBD 通信を許可する

互いに 7789/tcp ポートへアクセスできるようにする

```
[db1]# firewall-cmd --add-rich-rule='rule family=ipv4 source address=192.168.122.12 port port=7789 protocol=tcp accept'
[db1]# firewall-cmd --add-rich-rule='rule family=ipv4 source address=192.168.122.12 port port=7789 protocol=tcp accept' --permanent
```

```
[db2]# firewall-cmd --add-rich-rule='rule family=ipv4 source address=192.168.122.11 port port=7789 protocol=tcp accept'
[db2]# firewall-cmd --add-rich-rule='rule family=ipv4 source address=192.168.122.11 port port=7789 protocol=tcp accept' --permanent
```

### DRBD のリソースを作成する

```
[ALL]# cat < /etc/drbd.d/mysql.res
resource mysql {
  protocol C;
  meta-disk internal;
  device /dev/drbd0;
  disk /dev/cl/drbd0;
  handlers {
    split-brain "/usr/lib/drbd/notify-split-brain.sh root";
  }
  # スプリットブレインからの自動復旧ポリシー
  net {
    allow-two-primaries no;

    # スプリットブレインが検出されたときに両ノードともセカンダリロールの場合に適用されるポリシーの定義
    after-sb-0pri discard-zero-changes;  # 変更がなかったホストでは、他方に加えられたすべての変更内容を適用して続行

    # スプリットブレインが検出されたときにどちらか1つのノードがプライマリロールである場合に適用されるポリシーの定義
    after-sb-1pri discard-secondary;  # クラスタからノードを強制的に削除

    # スプリットブレインが検出されたときに両ノードともプライマリロールである場合に適用されるポリシーの定義
    after-sb-2pri disconnect;  # split-brain ハンドラスクリプト(構成されている場合)を呼び出し、コネクションを切断して切断モードで続行

    rr-conflict disconnect;
  }
  disk {
    on-io-error detach;
  }
  syncer {
    verify-alg sha1;
  }
  on db1 {
    address 192.168.122.11:7789;
  }
  on db2 {
    address 192.168.122.12:7789;
  }
}
EOF 
```

[https://blog.3ware.co.jp/drbd-users-guide-8.3/s-configure-split-brain-behavior.html](https://blog.3ware.co.jp/drbd-users-guide-8.3/s-configure-split-brain-behavior.html)

```
[ALL]# drbdadm create-md mysql
```

```
[root@db1 ~]# drbdadm create-md mysql
[ 9270.237905] Request for unknown module key 'The ELRepo Project (http://elrepo.org): ELRepo.org Secure Boot Key: f365ad3481a7b20e3427b61b2a26635b83fe427b' err -11
[ 9270.240696] drbd: loading out-of-tree module taints kernel.
[ 9270.241865] drbd: module verification failed: signature and/or required key missing - tainting kernel
[ 9270.256491] drbd: initialized. Version: 8.4.9-1 (api:1/proto:86-101)
[ 9270.257797] drbd: GIT-hash: 9976da086367a2476503ef7f6b13d4567327a280 build by akemi@Build64R7, 2016-12-04 01:08:48
[ 9270.260611] drbd: registered as block device major 147
initializing activity log
NOT initializing bitmap
Writing meta data...
New drbd meta data block successfully created.
success
```

```
[ALL]# drbdadm up mysql
```

db1 側を primary と指定することで同期が始まる

```
[db1]# drbdadm primary --force mysql
```

`drbd-overview` で同期の進捗が確認できる

```
[root@db1 ~]# drbd-overview
 0:mysql/0  SyncSource Primary/Secondary UpToDate/Inconsistent 
	[>....................] sync'ed:  2.8% (1022252/1048508)K           
```

```
[root@db1 ~]# drbd-overview
 0:mysql/0  SyncSource Primary/Secondary UpToDate/Inconsistent 
	[=>..................] sync'ed: 11.8% (929188/1048508)K           
```

```
[root@db1 ~]# drbd-overview
 0:mysql/0  Connected Primary/Secondary UpToDate/UpToDate
```

同期完了

### DRBD デバイスをフォーマット

DRBD によってできたデバイスを XFS でフォーマットする

```
[db1]# mkfs.xfs /dev/drbd0
```

### MariaDB のインストール

MySQL でも良いのだけれど CentOS 7 の標準 repository は MariaDB に変わっているのでこれを使います。そういえば最近 MariaDB の話聞かないね。

```
[ALL]# yum install -y mariadb-server mariadb
```

DRBD デバイスを仮に /mnt にマウント

```
[db1]# mount /dev/drbd0 /mnt
```

/mnt に MySQL(?) をセットアップ

```
[db1]# mysql_install_db --datadir=/mnt --user=mysql
```

/var/lib/mysql と同じように SELinux の context を設定

```
[db1]# semanage fcontext -a -t mysqld_db_t "/mnt(/.*)?"
[db1]# restorecon -Rv /mnt
```

準備ができたので umount

```
[db1]# umount /mnt
```

my.cnf の設定

```
[ALL]# cat << EOL > /etc/my.cnf
[mysqld]
symbolic-links=0
bind_address            = 0.0.0.0
datadir                 = /var/lib/mysql
pid_file                = /var/run/mariadb/mysqld.pid
socket                  = /var/run/mariadb/mysqld.sock

[mysqld_safe]
bind_address            = 0.0.0.0
datadir                 = /var/lib/mysql
pid_file                = /var/run/mariadb/mysqld.pid
socket                  = /var/run/mariadb/mysqld.sock

!includedir /etc/my.cnf.d
EOL
```

### Pacemaker 設定

[第12章 PACEMAKER クラスターのプロパティ](https://access.redhat.com/documentation/ja-JP/Red_Hat_Enterprise_Linux/7/html/High_Availability_Add-On_Reference/ch-clusteropts-HAAR.html)

```
[db1]# pcs cluster cib clust_cfg
```

stonith の無効化（使えるなら使ったほうが良い）

```
[db1]# pcs -f clust_cfg property set stonith-enabled=false
```

quorum の無効化（2台構成では過半数はとれない）

```
[db1]# pcs -f clust_cfg property set no-quorum-policy=ignore
```

failback を抑制する

```
[db1]# pcs -f clust\_cfg resource defaults resource-stickiness=200
```

DRBD の resource として mysql (/etc/drbd.d/mysql.res で設定したやつ) を指定

```
[db1]# pcs -f clust_cfg resource create mysql_data ocf:linbit:drbd \
  drbd_resource=mysql \
  op monitor interval=30s
```

```
[db1]# pcs -f clust_cfg resource master MySQLClone mysql_data \
  master-max=1 master-node-max=1 \
  clone-max=2 clone-node-max=1 \
  notify=true
```

master-max=1

マスターに昇格させることができるリソースのコピー数

master-node-max=1

1つのノード上でマスターに昇格させることができるリソースのコピー数

clone-max=2

いくつのリソースコピーを開始するか。デフォルトはクラスタ内のノード数

clone-node-max=1

1つのノードで開始状態にできるリソースのコピー数

notify=true

クローンのコピーを開始、停止する前後に他の全てのコピーに伝える

`mysql_fs` という名前で /dev/drbd0 を /var/lib/mysql にマウントする resource を定義

```
[db1]# pcs -f clust_cfg resource create mysql_fs Filesystem \
  device="/dev/drbd0" \
  directory="/var/lib/mysql" \
  fstype="xfs"
```

`MySQLClone` には `mysql_fs` が必須

```
[db1]# pcs -f clust_cfg constraint colocation add mysql_fs with MySQLClone \
  INFINITY with-rsc-role=Master
```

`MySQLClone` を master に昇格させるときに `mysql_fs` を開始する

```
[db1]# pcs -f clust_cfg constraint order promote MySQLClone then start mysql_fs
```

`mysql_service` resource の作成、MariaDB (MySQL) の起動設定 (ocf:heartbeat:mysql のファイルは /usr/lib/ocf/resource.d/heartbeat/mysql にあります) monitor interval はもっと短い方が良いかな

```
[db1]# pcs -f clust_cfg resource create mysql_service ocf:heartbeat:mysql \
  binary="/usr/bin/mysqld_safe" \
  config="/etc/my.cnf" \
  datadir="/var/lib/mysql" \
  pid="/var/lib/mysql/mysql.pid" \
  socket="/var/lib/mysql/mysql.sock" \
  additional_parameters="--bind-address=0.0.0.0" \
  op start timeout=60s \
  op stop timeout=60s \
  op monitor interval=20s timeout=30s
```

`mysql_fs` resource 起動しているノードで `mysql_service` を起動する ([7.3. リソースのコロケーション (constraint colocation)](https://access.redhat.com/documentation/ja-JP/Red_Hat_Enterprise_Linux/7/html/High_Availability_Add-On_Reference/s1-colocationconstraints-HAAR.html))

```
[db1]# pcs -f clust_cfg constraint colocation add mysql_service with mysql_fs INFINITY
```

`mysql_fs` の後に `mysql_service` を開始 ([7.2. 順序の制約 (constraint order)](https://access.redhat.com/documentation/ja-JP/Red_Hat_Enterprise_Linux/7/html/High_Availability_Add-On_Reference/s1-orderconstraints-HAAR.html))

```
[db1]# pcs -f clust_cfg constraint order mysql_fs then mysql_service
```

VIP resource を定義 (IPaddr2 は Linux 向けの VIP 設定、場所は /usr/lib/ocf/resource.d/heartbeat/IPaddr2)

```
[db1]# pcs -f clust_cfg resource create mysql_VIP ocf:heartbeat:IPaddr2 \
 ip=192.168.122.10 cidr_netmask=32 \
 op monitor interval=30s
```

IPaddr

manages virtual IPv4 addresses (portable version)

IPaddr2

manages virtual IPv4 addresses (Linux specific version).

`mysql_VIP` は `mysql_service` の実行ノードで実行

```
[db1]# pcs -f clust_cfg constraint colocation add mysql_VIP with mysql_service INFINITY
```

`mysql_service` の後に `mysql_VIP` を開始

```
[db1]# pcs -f clust_cfg constraint order mysql_service then mysql_VIP
```

制約確認

```
[db1]# pcs -f clust_cfg constraint
```

実行例

```
[root@db1 ~]# pcs -f clust_cfg constraint
Location Constraints:
Ordering Constraints:
  promote MySQLClone then start mysql_fs (kind:Mandatory)
  start mysql_fs then start mysql_service (kind:Mandatory)
  start mysql_service then start mysql_VIP (kind:Mandatory)
Colocation Constraints:
  mysql_fs with MySQLClone (score:INFINITY) (with-rsc-role:Master)
  mysql_service with mysql_fs (score:INFINITY)
  mysql_VIP with mysql_service (score:INFINITY)
Ticket Constraints:
```

`MySQLClone` という Master / Slave な clone があり、これを Master に昇格させると `mysql_fs`, `mysql_service`, `mysql_VIP` の順に起動させる

```
[db1]# pcs -f clust_cfg resource show
```

```
[root@db1 ~]# pcs -f clust_cfg resource show
 Master/Slave Set: MySQLClone [mysql_data]
     Stopped: [ db1 db2 ]
 mysql_fs	(ocf::heartbeat:Filesystem):	Stopped
 mysql_service	(ocf::heartbeat:mysql):	Stopped
 mysql_VIP	(ocf::heartbeat:IPaddr2):	Stopped
```

ここまで、cluster\_cfg というファイルに設定を入れていたが、ここで cib に push することで `/var/lib/pacemaker/cib/cib.xml` に保存されます

```
[db1]# pcs cluster cib-push clust_cfg
```

Pacemaker の状態確認

```
[db1]# pcs status
```

```
[root@db1 ~]# pcs status
Cluster name: mysql_cluster
Stack: corosync
Current DC: db2 (version 1.1.15-11.el7_3.4-e174ec8) - partition with quorum
Last updated: Tue Jun 13 23:44:58 2017		Last change: Tue Jun 13 20:22:08 2017 by root via crm_attribute on db2

2 nodes and 5 resources configured

Online: [ db1 db2 ]

Full list of resources:

 Master/Slave Set: MySQLClone [mysql_data]
     Masters: [ db1 ]
     Slaves: [ db2 ]
 mysql_fs	(ocf::heartbeat:Filesystem):	Started db1
 mysql_service	(ocf::heartbeat:mysql):	Started db1
 mysql_VIP	(ocf::heartbeat:IPaddr2):	Started db1

Daemon Status:
  corosync: active/enabled
  pacemaker: active/enabled
  pcsd: active/enabled
```

### 参考ドキュメント

* [Active/Passive MySQL High Availability Pacemaker Cluster with DRBD on CentOS 7 | Lisenet.com :: Linux | Security | Networking](https://www.lisenet.com/2016/activepassive-mysql-high-availability-pacemaker-cluster-with-drbd-on-centos-7/)
* [Capitolo 7. Replicate Storage Using DRBD](http://clusterlabs.org/doc/it-IT/Pacemaker/1.1/html/Clusters_from_Scratch/ch07.html)
* [スプリットブレイン時の動作の設定](https://blog.3ware.co.jp/drbd-users-guide-8.3/s-configure-split-brain-behavior.html)
* [DRBD 8.4 の設定、切り替え手順（マルチPrimaryバージョン） - Qiita](http://qiita.com/sion_cojp/items/a6a329df0415a843fb12)
* [ELRepo : HomePage](http://elrepo.org/tiki/tiki-index.php)
