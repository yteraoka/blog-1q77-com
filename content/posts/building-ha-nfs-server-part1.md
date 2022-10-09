---
title: 'GlusterFS + NFS-Ganesha で HA な NFS サーバーを構築する (1)'
date: Sat, 20 May 2017 11:32:02 +0000
draft: false
tags: ['CentOS', 'GlusterFS']
---

[GlusterFS](https://www.gluster.org/) と [NFS-Ganesha](https://github.com/nfs-ganesha/nfs-ganesha/wiki) で High-Availability NFS サーバーを構築してみます。 GlusterFS をそのままマウントさせられるクライアントばかりであればわざわざ NFS サーバーにする必要はないです。 OS は CentOS Linux release 7.3.1611 (Core) です。 gluster1, gluster2 という2台で試します。 DigitalOcean で試すので名前解決は hosts に書くことにします。

### package のインストール

[The CentOS Storage Special Interest Group](https://wiki.centos.org/SpecialInterestGroup/Storage) にて package が提供されていますので yum で簡単にインストールできます。現在（2017年5月）提供されている最新のバージョンは 3.10 です。これをインストールします。 [HowTos/GlusterFSonCentOS - CentOS Wiki](https://wiki.centos.org/HowTos/GlusterFSonCentOS) もありますし、Red Hat Gluster Storage の [INSTALLING RED HAT GLUSTER STORAGE 3.1](https://access.redhat.com/documentation/en-US/Red_Hat_Storage/3.1/html/Installation_Guide/index.html) も参考になります。

```
$ sudo yum -y install centos-release-gluster310
```

これで 3.10 の yum repository が登録されます。

```
$ sudo yum -y install glusterfs glusterfs-server
```

### Firewall 設定

glusterfs-server パッケージに `/usr/lib/firewalld/services/glusterfs.xml` が含まれるので firewall-cmd で glusterfs サービスを使います。

```
$ sudo systemctl start firewalld
$ sudo systemctl enable firewalld
$ sudo firewall-cmd --add-rich-rule="rule family=ipv4 source address=10.130.0.0/16 service name=glusterfs accept" --permanent
$ sudo firewall-cmd --add-rich-rule="rule family=ipv4 source address=10.130.0.0/16 service name=glusterfs accept"
$ sudo firewall-cmd --list-all
public
  target: default
  icmp-block-inversion: no
  interfaces: 
  sources: 
  services: dhcpv6-client ssh
  ports: 
  protocols: 
  masquerade: no
  forward-ports: 
  sourceports: 
  icmp-blocks: 
  rich rules: 
	rule family="ipv4" source address="10.130.0.0/16" service name="glusterfs" accept
```

`10.130.0.0/16` は DigitalOcean シンガポールリージョンの Provate Network アドレスですが他の契約者のサーバーと共用なので注意が必要です。実際には信頼できるIPアドレスだけに公開しましょう。

### クラスタリング

まずは全てのサーバーで glusterd を起動します

```
$ sudo systemctl start glusterd
$ sudo systemctl enable glusterd
```

いずれか1台のサーバーから他のサーバーを peer に加えます

```
$ sudo gluster peer probe gluster2
```

```
$ sudo gluster peer status
Number of Peers: 1

Hostname: gluster2
Uuid: 0699a6ac-1352-4996-a7e8-53d30531b2ee
State: Peer in Cluster (Connected)
```

### Volume の作成

GlusterFS の snapshot 機能を使うためにシンプロビジョニングされた LVM の Logical Volume を使います。 ここでは /dev/sda をデータボリュームように使うことにします（DigitalOcean の Block Storage サービスを使うとこの path になったので）。

```
$ lsblk
NAME    MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
sda       8:0    0   5G  0 disk 
vda     253:0    0  30G  0 disk 
├─vda1  253:1    0  30G  0 part /
└─vda15 253:15   0   1M  0 part

```

Volume Group は通常通りに作成します

```
$ sudo pvcreate /dev/sda
  Physical volume "/dev/sda" successfully created.
$ sudo vgcreate data /dev/sda
  Volume group "data" successfully created
```

Logial Volume として pool を作成します

```
$ sudo lvcreate --thin -l 100%FREE data/thinpool
  Using default stripesize 64.00 KiB.
  Logical volume "thinpool" created.
$ sudo lvs
  LV       VG   Attr       LSize Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  thinpool data twi-a-tz-- 4.98g             0.00   0.63
```

pool から volume を作成します vol1, vol2 をそれぞれ 1GB で作成しました。5GB を割り当てた pool から 1GB ずつなので普通に見えますね。でも実際にはまだ1GBは割り当てられていなくて必要になった分だけそときに割り当てられます。

```
$ sudo lvcreate --thin --virtualsize 1G -n vol1 data/thinpool
  Using default stripesize 64.00 KiB.
  Logical volume "vol1" created.
$ sudo lvcreate -T -V 1G -n vol2 data/thinpool
  Using default stripesize 64.00 KiB.
  Logical volume "vol2" created.
```

では 10GB の volume も作ってみます。

```
$ sudo lvcreate -T -V 10G -n vol3 data/thinpool
  Using default stripesize 64.00 KiB.
  WARNING: Sum of all thin volume sizes (12.00 GiB) exceeds the size of thin pool data/thinpool and the size of whole volume group (5.00 GiB)!
  For thin pool auto extension activation/thin_pool_autoextend_threshold should be below 100.
  Logical volume "vol3" created.
```

5GB の Volume Group 内に 10GB の Logical Volume が作成できました。これが Thin Provisioning というやつですね。必要になったときに Volume Group にディスクを追加するなどして対応できます。

```
$ sudo lvs
  LV       VG   Attr       LSize  Pool     Origin Data%  Meta%  Move Log Cpy%Sync Convert
  thinpool data twi-aotz--  4.98g                 0.00   0.78                            
  vol1     data Vwi-a-tz--  1.00g thinpool        0.00                                   
  vol2     data Vwi-a-tz--  1.00g thinpool        0.00                                   
  vol3     data Vwi-a-tz-- 10.00g thinpool        0.00
```

こんな風に `_tmeta` と `_tdata` というのが別に見えます。

```
$ lsblk
NAME                    MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   5G  0 disk 
├─data-thinpool_tmeta   252:0    0   8M  0 lvm  
│ └─data-thinpool-tpool 252:2    0   5G  0 lvm  
│   ├─data-thinpool     252:3    0   5G  0 lvm  
│   ├─data-vol1         252:4    0   1G  0 lvm  
│   ├─data-vol2         252:5    0   1G  0 lvm  
│   └─data-vol3         252:6    0  10G  0 lvm  
└─data-thinpool_tdata   252:1    0   5G  0 lvm  
  └─data-thinpool-tpool 252:2    0   5G  0 lvm  
    ├─data-thinpool     252:3    0   5G  0 lvm  
    ├─data-vol1         252:4    0   1G  0 lvm  
    ├─data-vol2         252:5    0   1G  0 lvm  
    └─data-vol3         252:6    0  10G  0 lvm  
vda                     253:0    0  30G  0 disk 
├─vda1                  253:1    0  30G  0 part /
└─vda15                 253:15   0   1M  0 part
```

それでは volume をフォーマットします。GLusterFS では XFS が推奨されているようです。inode の拡張属性として meta データを保持するようです。そのため inode サイズを 512 にするようにとなっています（CentOS 7 では default size が 512 なのであえて指定しなくても大丈夫ですが）。

```
$ sudo mkfs.xfs -i size=512 /dev/data/vol1
$ sudo mkfs.xfs -i size=512 /dev/data/vol2
```

マウントします。

```
$ sudo mkdir -p /gluster/vol1/brick1
$ sudo mkdir -p /gluster/vol2/brick1
$ echo "/dev/data/vol1 /gluster/vol1/brick1 xfs rw,noatime,nouuid 0 0" | sudo tee -a /etc/fstab
$ echo "/dev/data/vol2 /gluster/vol2/brick1 xfs rw,noatime,nouuid 0 0" | sudo tee -a /etc/fstab
$ sudo mount -a
```

### GlusterFS Volume の作成

次に GlusterFS のボリュームを作成します。GlusterFS では brick という実態はサーバーの1ディレクトリの組み合わせで volume を作成します。同じデータを複数の brick に保存する Replicated Volume や、ファイルによって保存する brick を振り分ける Distributed Volume、この2つを組み合わせた Distributed Replicated Volume あたりが基本的な Volume でしょうか。 他にもファイルを指定のサイズで分割して複数の brick に保存する方法や RAID5, RAID6 的な Dispersed Volume というものもあります。 [Setting Up Volumes - Gluster Docs](https://gluster.readthedocs.io/en/latest/Administrator%20Guide/Setting%20Up%20Volumes/) に各 Volume タイプの説明があります Volume の作成コマンドはどれか1台のサーバーで実行します `Replicated Volume` ミラーボリュームですね、3台以上でさらに冗長性を上げることもできます。

```
$ sudo gluster volume create vol1 \
         replica 2 \
         transport tcp \
         gluster1:/gluster/vol1/brick1/brick \
         gluster2:/gluster/vol1/brick1/brick
volume create: vol1: success: please start the volume to access data
```

```
$ sudo gluster volume info vol1
 
Volume Name: vol1
Type: Replicate
Volume ID: 0086e6e4-9d7c-40ec-badf-33f88b58f472
Status: Created
Snapshot Count: 0
Number of Bricks: 1 x 2 = 2
Transport-type: tcp
Bricks:
Brick1: gluster1:/gluster/vol1/brick1/brick
Brick2: gluster2:/gluster/vol1/brick1/brick
Options Reconfigured:
transport.address-family: inet
nfs.disable: on
```

`Distributed Volume` ファイル単位の RAID0 的なボリュームです。ファイルによってどこかの brick に保存されます。

```
$ sudo gluster volume create vol2 \
         transport tcp \
         gluster1:/gluster/vol2/brick1/brick \
         gluster2:/gluster/vol2/brick1/brick
volume create: vol2: success: please start the volume to access data
```

```
$ sudo gluster volume info vol2
 
Volume Name: vol2
Type: Distribute
Volume ID: 35be21b5-c624-4cdb-a20f-96cdb6efefbd
Status: Created
Snapshot Count: 0
Number of Bricks: 2
Transport-type: tcp
Bricks:
Brick1: gluster1:/gluster/vol2/brick1/brick
Brick2: gluster2:/gluster/vol2/brick1/brick
Options Reconfigured:
transport.address-family: inet
nfs.disable: on
```

クライアントからマウントできるようにするためには `start` させる必要があります

```
$ sudo gluster volume status vol1
Volume vol1 is not started
$ sudo gluster volume status vol2
Volume vol2 is not started
$ sudo gluster volume start vol1
volume start: vol1: success
$ sudo gluster volume start vol2
volume start: vol2: success
```

`gluster volume status {volume_name}` で状態が確認できます。Pid や TCP Port があることからわかるように brick ごとにプロセスがいますし、それぞれが別の TCP Port を Listen します。クライアントは volume を構成するそれぞれの brick の port に直接アクセスします。

```
$ sudo gluster volume status vol1
Status of volume: vol1
Gluster process                             TCP Port  RDMA Port  Online  Pid
------------------------------------------------------------------------------
Brick gluster1:/gluster/vol1/brick1/brick   49152     0          Y       30857
Brick gluster2:/gluster/vol1/brick1/brick   49152     0          Y       11657
Self-heal Daemon on localhost               N/A       N/A        Y       30877
Self-heal Daemon on gluster2                N/A       N/A        Y       16882
 
Task Status of Volume vol1
------------------------------------------------------------------------------
There are no active volume tasks

``````
$ sudo gluster volume status vol2
Status of volume: vol2
Gluster process                             TCP Port  RDMA Port  Online  Pid
------------------------------------------------------------------------------
Brick gluster1:/gluster/vol2/brick1/brick   49153     0          Y       30908
Brick gluster2:/gluster/vol2/brick1/brick   49153     0          Y       28864
 
Task Status of Volume vol2
------------------------------------------------------------------------------
There are no active volume tasks
```

### クライアントからマウントする

Linux クライアントからは FUSE でマウントします。

```
$ sudo yum -y install centos-release-gluster310
```

```
$ sudo yum -y install glusterfs-fuse
```

```
$ sudo mkdir /vol1
$ sudo mount -t glusterfs gluster1:/vol1 /vol1
$ mount | grep /vol1
gluster1:/vol1 on /vol1 type fuse.glusterfs (rw,relatime,user_id=0,group_id=0,default_permissions,allow_other,max_read=131072)
```

`/etc/fstab` には次のように `backup-volfile-servers` オプションで別サーバーも指定しておけば mount 時に gluster1 が down していてもマウントが可能となります

```
gluster1:/vol1 /vol1 glusterfs backup-volfile-servers=gluster2 0 0
```

[次回](/2017/05/building-ha-nfs-server-part2/) 一部のサーバーが down した時の動作を確認します。NFS-Ganesha はまだまだ先だな。

### doctl

今回の環境は DigitalOcean で作ってます。doctl コマンドで volume 付きのサーバーを立てるのはこんな感じ

```
$ doctl compute volume create gluster-data1 --region sgp1 --size 5GiB --desc "GlusterFS Data Volume 1"
ID                                      Name             Size     Region    Droplet IDs
a60e32be-3e20-11e7-892a-0242ac113804    gluster-data1    5 GiB    sgp1

$ doctl compute volume create gluster-data2 --region sgp1 --size 5GiB --desc "GlusterFS Data Volume 2"
ID                                      Name             Size     Region    Droplet IDs
ac9ead25-3e20-11e7-97d4-0242ac111505    gluster-data2    5 GiB    sgp1

$ doctl compute droplet create gluster1 \
  --image centos-7-x64 \
  --region sgp1 \
  --size 1gb \
  --volumes a60e32be-3e20-11e7-892a-0242ac113804 \
  --enable-private-networking \
  --enable-monitoring \
  --ssh-keys 76364
ID          Name        Public IPv4    Private IPv4    Public IPv6    Memory    VCPUs    Disk    Region    Image                  Status    Tags
49480401    gluster1                                                  1024      1        30      sgp1      CentOS 7.3.1611 x64    new

$ doctl compute droplet create gluster2 \
  --image centos-7-x64 \
  --region sgp1 \
  --size 1gb \
  --volumes ac9ead25-3e20-11e7-97d4-0242ac111505 \
  --enable-private-networking \
  --enable-monitoring \
  --ssh-keys 76364
ID          Name        Public IPv4    Private IPv4    Public IPv6    Memory    VCPUs    Disk    Region    Image                  Status    Tags
49480523    gluster2                                                  1024      1        30      sgp1      CentOS 7.3.1611 x64    new

$ doctl compute droplet create client \
  --image centos-7-x64 \
  --region sgp1 \
  --size 1gb \
  --enable-private-networking \
  --enable-monitoring \
  --ssh-keys 76364
ID          Name      Public IPv4    Private IPv4    Public IPv6    Memory    VCPUs    Disk    Region    Image                  Status    Tags
49480546    client                                                  1024      1        30      sgp1      CentOS 7.3.1611 x64    new
```
