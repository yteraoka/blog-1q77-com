---
title: 'GlusterFS + NFS-Ganesha で HA な NFS サーバーを構築する (4)'
date: Mon, 05 Jun 2017 14:28:08 +0000
draft: false
tags: ['CentOS', 'GlusterFS', 'Linux', 'NFS', 'KVM']
---

[パート1](/2017/05/building-ha-nfs-server-part1/) で GlusterFS Volume をセットアップしたところから始めようと思ったが DigitalOcean でも Vagrant (VirtualBox) でもうまくいかないので KVM で試してみた（Network Interface が複数あるとうまくいかないのだろうか？）。

### KVM に kickstart でセットアップ

次のような Kickstart 用ファイルを gluster1, gluster2 分作成する

```
#version=DEVEL
# System authorization information
auth --enableshadow --passalgo=sha512
# Use network installation
url --url="http://ftp.iij.ad.jp/pub/linux/centos/7/os/x86_64/"
# Use text mode install
text
# Run the Setup Agent on first boot
firstboot --enable
ignoredisk --only-use=vda
# Keyboard layouts
keyboard --vckeymap=jp --xlayouts='jp','us'
# System language
lang en_US.UTF-8

# Network information
network  --bootproto=static --device=eth0 --gateway=192.168.122.1 --ip=192.168.122.51 --nameserver=192.168.122.1 --netmask=255.255.255.0 --ipv6=auto --activate
network  --hostname=gluster1.example.com

# Root password
rootpw --iscrypted $6$SnOAnBBQRh0lVpFR$fI.QeH4QU4fjrBvQVjNaXngHLWIHj5MeVSMX.37ws9qUiHJ9FkJqiofgNlW8xJky2O4QelVLSEvW63ckjv2a60
# System services
services --enabled="chronyd"
# System timezone
timezone Asia/Tokyo --isUtc
user --name=centos --password=$6$vm6CEJebCNPiAW9h$ZUTwIRMJbZCI5OqLSXFhT4i3W/nbXawEx3hPHSrJr7/N25anniULRSAGzBsbnN87LXIP5d3SDVS8y0j5sOaUk. --iscrypted
# System bootloader configuration
bootloader --append=" crashkernel=auto" --location=mbr --boot-drive=vda
# Partition clearing information
clearpart --none --initlabel
# Disk partitioning information
part /boot --fstype="xfs" --ondisk=vda --size=512
part pv.183 --fstype="lvmpv" --ondisk=vda --size=1 --grow
part biosboot --fstype="biosboot" --ondisk=vda --size=2
volgroup cl --pesize=4096 pv.183
logvol swap  --fstype="swap" --size=512 --name=swap --vgname=cl
logvol none  --fstype="None" --size=1 --grow --thinpool --name=pool00 --vgname=cl
logvol /  --fstype="xfs" --size=4096 --thin --poolname=pool00 --name=root --vgname=cl
logvol /gluster/vol1/brick1  --fstype="xfs" --size=1024 --thin --poolname=pool00 --name=gluster_vol1_brick1 --vgname=cl

%packages
@^minimal
@core
chrony
kexec-tools

%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end

%anaconda
pwpolicy root --minlen=6 --minquality=50 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=50 --notstrict --nochanges --notempty
pwpolicy luks --minlen=6 --minquality=50 --notstrict --nochanges --notempty
%end

%post --log=/root/ks-post.log
yum -y update
yum -y install centos-release-gluster310
yum -y install install glusterfs glusterfs-server glusterfs-ganesha
cat <<EOF >> /etc/hosts
192.168.122.51 gluster1
192.168.122.52 gluster2
EOF
echo redhat | sudo passwd --stdin hacluster
systemctl start glusterd
systemctl enable glusterd
systemctl disable NetworkManager.service
systemctl disable NetworkManager-wait-online.service
systemctl enable pcsd
systemctl start pcsd
cat <<EOF > /var/lib/glusterd/nfs/secret.pem
-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIDWZLwNkk5Za1PTAIOjEDrafAeA+MA5tSL7t2XAPnn+uoAoGCCqGSM49
AwEHoUQDQgAEpMGlqMXYci0EOceoT+kRmRnaHcT5F7AXvez0tu5ujm9cHYXT5k14
hDCRoqBR6NTnpYMnER6uE6AG43gX+HPACg==
-----END EC PRIVATE KEY-----
EOF
chmod 600 /var/lib/glusterd/nfs/secret.pem
install -o root -g root -m 0700 -d /root/.ssh
echo "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBKTBpajF2HItBDnHqE/pEZkZ2h3E+RewF73s9Lbubo5vXB2F0+ZNeIQwkaKgUejU56WDJxEerhOgBuN4F/hzwAo= root@gluster" >> /root/.ssh/authorized_keys
cat <<EOF > /tmp/000-firewalld-config.sh
#!/bin/bash

systemctl start firewalld
systemctl enable firewalld
firewall-cmd --add-service glusterfs
firewall-cmd --add-service glusterfs --permanent
firewall-cmd --add-service high-availability
firewall-cmd --add-service high-availability --permanent
firewall-cmd --add-service nfs
firewall-cmd --add-service nfs --permanent
EOF
chmod 755 /tmp/000-firewalld-config.sh
cat <<EOF > /tmp/001-setup-gluster-volume.sh
#!/bin/bash

gluster peer probe gluster2

gluster volume create vol1 replica 2 transport tcp gluster1:/gluster/vol1/brick1/brick gluster2:/gluster/vol1/brick1/brick

gluster volume start vol1
EOF
chmod 755 /tmp/001-setup-gluster-volume.sh

cat <<EOF > /tmp/002-mount-shared-storage.sh
#!/bin/bash

gluster volume set all cluster.enable-shared-storage enable
EOF
chmod 755 /tmp/002-mount-shared-storage.sh

cat <<EOF > /tmp/003-configure-ganesha.sh
#!/bin/bash

mkdir /var/run/gluster/shared_storage/nfs-ganesha
touch /var/run/gluster/shared_storage/nfs-ganesha/ganesha.conf
cat <<_EOF_ > /var/run/gluster/shared_storage/nfs-ganesha/ganesha-ha.conf
HA_NAME="ganesha"
HA_CLUSTER_NODES="gluster1,gluster2"
VIP_gluster1=192.168.122.61
VIP_gluster2=192.168.122.62
_EOF_

pcs cluster auth gluster1 gluster2 -u hacluster -p redhat

/usr/libexec/ganesha/ganesha-ha.sh setup /var/run/gluster/shared_storage/nfs-ganesha
EOF
chmod 755 /tmp/003-configure-ganesha.sh

cat <<EOF > /tmp/004-enable-services.sh
#!/bin/bash

systemctl enable pacemaker
systemctl enable corosync
systemctl enable nfs-ganesha
systemctl start nfs-ganesha
EOF
chmod 755 /tmp/004-enable-services.sh
%end
```

次のように virt-install で仮想サーバーをセットアップする（インストール時に No space left on device で / に書き込めないというエラーが出てハマったが 1GB メモリでは足りないということだったので 2GB に増やした）

```
virt-install \
  --name gluster1 \
  --vcpus 1 \
  --memory 2048 \
  --os-variant rhel7 \
  --location http://ftp.iij.ad.jp/pub/linux/centos/7/os/x86_64/ \
  --network network=default,model=virtio \
  --disk pool=ytera,size=10,format=qcow2,bus=virtio \
  --graphics none \
  --initrd-inject gluster1.ks \
  --extra-args="console=tty0 console=ttyS0,115200n8 ks=file:/gluster1.ks"
```

これでセットアップすると `%post` で glusterfs-ganesha パッケージのインストールや hosts への追記、お互いに公開鍵によって root で ssh できるようにする設定などが行われています。glusterfs-ganesha では pcs, pacemaker, corosync といった HA 構築用パッケージもインストールされています。 また /tmp に次に実行するファイルができています

```
/tmp/000-firewalld-config.sh
/tmp/001-setup-gluster-volume.sh
/tmp/002-mount-shared-storage.sh
/tmp/003-configure-ganesha.sh
/tmp/004-enable-services.sh
```

### /tmp/000-firewalld-config.sh

firewalld で必要なポートを開けます。これは gluster1, gluster2 の両方で実行します

```bash
systemctl start firewalld
systemctl enable firewalld
firewall-cmd --add-service glusterfs
firewall-cmd --add-service glusterfs --permanent
firewall-cmd --add-service high-availability
firewall-cmd --add-service high-availability --permanent
firewall-cmd --add-service nfs
firewall-cmd --add-service nfs --permanent
```

それぞれの service がどの port を開けているのかは `/usr/lib/firewalld/services/` にあるファイルを見るとわかります

```
$ cat /usr/lib/firewalld/services/high-availability.xml 
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>Red Hat High Availability</short>
  <description>This allows you to use the Red Hat High Availability (previously named Red Hat Cluster Suite). Ports are opened for corosync, pcsd, pacemaker_remote, dlm and corosync-qnetd.</description>
  <port protocol="tcp" port="2224"/>
  <port protocol="tcp" port="3121"/>
  <port protocol="tcp" port="5403"/>
  <port protocol="udp" port="5404"/>
  <port protocol="udp" port="5405"/>
  <port protocol="tcp" port="21064"/>
```

### /tmp/001-setup-gluster-volume.sh

glusterfs の peer 設定と volume の作成を行います。gluster1 でのみ実行します。

### /tmp/002-mount-shared-storage.sh

`gluster volume set all cluster.enable-shared-storage enable` を実行します。gluster1 でのみ実行します。
これにより `/run/gluster/shared_storage` に glusterfs の共有 volume がマウントされます。
設定の共有や NFS の lock などに使われます。`/etc/fstab` への書き込みまでしてくれます。

### /tmp/003-configure-ganesha.sh

`/var/run/gluster/shared_storage/nfs-ganesha/ganesha-ha.conf` に HA セットアップ用のファイルを作成します。

```
HA_NAME="ganesha"
HA_CLUSTER_NODES="gluster1,gluster2"
VIP_gluster1=192.168.122.61
VIP_gluster2=192.168.122.62
```

`HA_NAME` には任意の名前を設定、`HA_CLUSTER_NODES` にクラスタを組むサーバーのリストを列挙します。`VIP_{hostname}` にそれぞれのサーバー用の VIP (ip address) を指定します。 ドメインを入れても大丈夫です。

```
HA_NAME="ganesha"
HA_CLUSTER_NODES="gluster1.examplc.com,gluster2.examplc.com"
VIP_gluster1.examplc.com=192.168.122.61
VIP_gluster2.examplc.com=192.168.122.62
```

この後 `pcs cluster auth gluster1 gluster2 -u hacluster -p redhat` で pcs コマンドで設定ができるように認証を通します。`-u` でユーザー名、`-p` でパスワードを指定しています。 hacluster ユーザーは pcs パッケージのインストールで作成され、kickstart の `%post` でパスワードを設定しています。 `/usr/libexec/ganesha/ganesha-ha.sh setup /var/run/gluster/shared_storage/nfs-ganesha` にて HA 設定が行われます。

```
# bash -x 003-configure-ganesha.sh 
+ mkdir /var/run/gluster/shared_storage/nfs-ganesha
+ touch /var/run/gluster/shared_storage/nfs-ganesha/ganesha.conf
+ cat
+ pcs cluster auth gluster1 gluster2
Username: hacluster
Password: 
gluster2: Authorized
gluster1: Authorized
+ /usr/libexec/ganesha/ganesha-ha.sh setup /var/run/gluster/shared_storage/nfs-ganesha
gluster2: Already authorized
gluster1: Already authorized
Destroying cluster on nodes: gluster1, gluster2...
gluster1: Stopping Cluster (pacemaker)...
gluster2: Stopping Cluster (pacemaker)...
gluster1: Successfully destroyed cluster
gluster2: Successfully destroyed cluster

Sending cluster config files to the nodes...
gluster1: Succeeded
gluster2: Succeeded

Synchronizing pcsd certificates on nodes gluster1, gluster2...
gluster2: Success
gluster1: Success

Restarting pcsd on the nodes in order to reload the certificates...
gluster2: Success
gluster1: Success
gluster1: Starting Cluster...
gluster2: Starting Cluster...
Adding nfs-grace-clone gluster1-cluster_ip-1 (kind: Mandatory) (Options: first-action=start then-action=start)
Adding nfs-grace-clone gluster2-cluster_ip-1 (kind: Mandatory) (Options: first-action=start then-action=start)
CIB updated
```

これで、次のような状況になります

```
# pcs status
Cluster name: ganesha
Stack: corosync
Current DC: gluster1 (version 1.1.15-11.el7_3.4-e174ec8) - partition with quorum
Last updated: Sun Jun  4 19:46:33 2017		Last change: Sun Jun  4 19:46:23 2017 by root via cibadmin on gluster1

2 nodes and 12 resources configured

Online: [ gluster1 gluster2 ]

Full list of resources:

 Clone Set: nfs_setup-clone [nfs_setup]
     Started: [ gluster1 gluster2 ]
 Clone Set: nfs-mon-clone [nfs-mon]
     Started: [ gluster1 gluster2 ]
 Clone Set: nfs-grace-clone [nfs-grace]
     Stopped: [ gluster1 gluster2 ]
 Resource Group: gluster1-group
     gluster1-nfs_block	(ocf::heartbeat:portblock):	Stopped
     gluster1-cluster_ip-1	(ocf::heartbeat:IPaddr):	Stopped
     gluster1-nfs_unblock	(ocf::heartbeat:portblock):	Stopped
 Resource Group: gluster2-group
     gluster2-nfs_block	(ocf::heartbeat:portblock):	Stopped
     gluster2-cluster_ip-1	(ocf::heartbeat:IPaddr):	Stopped
     gluster2-nfs_unblock	(ocf::heartbeat:portblock):	Stopped

Daemon Status:
  corosync: active/disabled
  pacemaker: active/disabled
  pcsd: active/enabled
```

```
# pcs cluster corosync
totem {
    version: 2
    secauth: off
    cluster_name: ganesha
    transport: udpu
}

nodelist {
    node {
        ring0_addr: gluster1
        nodeid: 1
    }

    node {
        ring0_addr: gluster2
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

### /tmp/004-enable-services.sh

この中では自動起動を有効にしています、gluster1, gluster2 の両方で実行します

```bash
systemctl enable pacemaker
systemctl enable corosync
systemctl enable nfs-ganesha
systemctl start nfs-ganesha
```

nfs-ganesha が起動されることで HA 構成が完了です

```
# pcs status
Cluster name: ganesha
Stack: corosync
Current DC: gluster1 (version 1.1.15-11.el7_3.4-e174ec8) - partition with quorum
Last updated: Sun Jun  4 19:48:00 2017		Last change: Sun Jun  4 19:47:49 2017 by root via crm_attribute on gluster2

2 nodes and 12 resources configured

Online: [ gluster1 gluster2 ]

Full list of resources:

 Clone Set: nfs_setup-clone [nfs_setup]
     Started: [ gluster1 gluster2 ]
 Clone Set: nfs-mon-clone [nfs-mon]
     Started: [ gluster1 gluster2 ]
 Clone Set: nfs-grace-clone [nfs-grace]
     Started: [ gluster1 gluster2 ]
 Resource Group: gluster1-group
     gluster1-nfs_block	(ocf::heartbeat:portblock):	Started gluster1
     gluster1-cluster_ip-1	(ocf::heartbeat:IPaddr):	Started gluster1
     gluster1-nfs_unblock	(ocf::heartbeat:portblock):	Started gluster1
 Resource Group: gluster2-group
     gluster2-nfs_block	(ocf::heartbeat:portblock):	Started gluster2
     gluster2-cluster_ip-1	(ocf::heartbeat:IPaddr):	Started gluster2
     gluster2-nfs_unblock	(ocf::heartbeat:portblock):	Started gluster2

Daemon Status:
  corosync: active/disabled
  pacemaker: active/disabled
  pcsd: active/enabled
```

### export する

NFS で export するための設定を作成するための `/usr/libexec/ganesha/create-export-ganesha.sh` があります

```
# /usr/libexec/ganesha/create-export-ganesha.sh /var/run/gluster/shared_storage/nfs-ganesha on vol1
```

これによって `/var/run/gluster/shared_storage/nfs-ganesha/exports/export.vol1.conf` というファイルが作成されます

```
# cat /var/run/gluster/shared_storage/nfs-ganesha/exports/export.vol1.conf
# WARNING : Using Gluster CLI will overwrite manual
# changes made to this file. To avoid it, edit the
# file and run ganesha-ha.sh --refresh-config.
EXPORT{
      Export_Id = 2;
      Path = "/vol1";
      FSAL {
           name = GLUSTER;
           hostname="localhost";
          volume="vol1";
           }
      Access_type = RW;
      Disable_ACL = true;
      Squash="No_root_squash";
      Pseudo="/vol1";
      Protocols = "3", "4" ;
      Transports = "UDP","TCP";
      SecType = "sys";
     }
```

そして、`/var/run/gluster/shared_storage/nfs-ganesha/ganesha.con` ファイルに次の include 文が追記されます

```
%include "/var/run/gluster/shared_storage/nfs-ganesha/exports/export.vol1.conf"
```

この変更を反映させるためには `ganesha-ha.sh --refresh-config` が必要です

```
# /usr/libexec/ganesha/ganesha-ha.sh --refresh-config /var/run/gluster/shared_storage/nfs-ganesha vol1
Refresh-config completed on gluster2.
Success: refresh-config completed.
```

### NFS Mount

```
[root@gluster1 ~]# ip address show eth0
2: eth0: mtu 1500 qdisc pfifo_fast state UP qlen 1000
    link/ether 52:54:00:b0:fd:64 brd ff:ff:ff:ff:ff:ff
    inet 192.168.122.51/24 brd 192.168.122.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet 192.168.122.61/32 brd 192.168.122.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::5054:ff:feb0:fd64/64 scope link 
       valid_lft forever preferred_lft forever 
```

192.168.122.61 が VIP なのでこのアドレスを使ってマウントします。こうすることで gluster1 がダウンしても VIP が gluster2 に引き継がれることによってアクセスが継続できます。

```
[root@client ~]# mount -t nfs 192.168.122.61:/vol1 /mnt
[79243.819185] FS-Cache: Loaded
[79243.856830] FS-Cache: Netfs 'nfs' registered for caching
[79243.871002] Key type dns_resolver registered
[79243.901417] NFS: Registering the id_resolver key type
[79243.903629] Key type id_resolver registered
[79243.905705] Key type id_legacy registered
[root@client ~]# df /mnt
Filesystem           1K-blocks  Used Available Use% Mounted on
192.168.122.61:/vol1   1045504 33792   1011712   4% /mnt
[root@client ~]# echo test > /mnt/test.txt
[root@client ~]# cat /mnt/test.txt
test
[root@client ~]# 
```

サーバー側でファイルを見てみます

```
[root@gluster1 tmp]# ls /gluster/vol1/brick1/brick/
test.txt
[root@gluster1 tmp]# cat /gluster/vol1/brick1/brick/test.txt 
test
[root@gluster1 tmp]# 
```

Replicated Volume なので gluster2 にもあります

```
[root@gluster2 ~]# ls /gluster/vol1/brick1/brick/
test.txt
[root@gluster2 ~]# cat /gluster/vol1/brick1/brick/test.txt 
test
[root@gluster2 ~]# 
```

### gluster1 を停止してみる

```
$ virsh destroy gluster1
ドメイン gluster1 は強制停止されました
```

すぐに検知されて VIP が gluster2 に移動しました

```
[root@gluster2 ~]# ip a s eth0
2: eth0: mtu 1500 qdisc pfifo_fast state UP qlen 1000
    link/ether 52:54:00:98:a3:bc brd ff:ff:ff:ff:ff:ff
    inet 192.168.122.52/24 brd 192.168.122.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet 192.168.122.62/32 brd 192.168.122.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet 192.168.122.61/32 brd 192.168.122.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::5054:ff:fe98:a3bc/64 scope link 
       valid_lft forever preferred_lft forever 
```

しかし、gluster1-nfs\_unblock が Stopped となっており、しばらくは gluster1 についていた VIP の NFS ポート宛のパケットは iptables でブロックされます

```
[root@gluster2 ~]# pcs status
Cluster name: ganesha
Stack: corosync
Current DC: gluster2 (version 1.1.15-11.el7_3.4-e174ec8) - partition with quorum
Last updated: Mon Jun  5 22:45:20 2017		Last change: Sun Jun  4 19:47:49 2017 by root via crm_attribute on gluster2

2 nodes and 12 resources configured

Online: [ gluster2 ]
OFFLINE: [ gluster1 ]

Full list of resources:

 Clone Set: nfs_setup-clone [nfs_setup]
     Started: [ gluster2 ]
     Stopped: [ gluster1 ]
 Clone Set: nfs-mon-clone [nfs-mon]
     Started: [ gluster2 ]
     Stopped: [ gluster1 ]
 Clone Set: nfs-grace-clone [nfs-grace]
     Started: [ gluster2 ]
     Stopped: [ gluster1 ]
 Resource Group: gluster1-group
     gluster1-nfs_block	(ocf::heartbeat:portblock):	Started gluster2
     gluster1-cluster_ip-1	(ocf::heartbeat:IPaddr):	Started gluster2
     gluster1-nfs_unblock	(ocf::heartbeat:portblock):	Stopped
 Resource Group: gluster2-group
     gluster2-nfs_block	(ocf::heartbeat:portblock):	Started gluster2
     gluster2-cluster_ip-1	(ocf::heartbeat:IPaddr):	Started gluster2
     gluster2-nfs_unblock	(ocf::heartbeat:portblock):	Started gluster2

Daemon Status:
  corosync: active/disabled
  pacemaker: active/disabled
  pcsd: active/enabled
```

1分ほどでブロックは解除されて NFS アクセスが復活します

```
[root@gluster2 ~]# pcs status
Cluster name: ganesha
Stack: corosync
Current DC: gluster2 (version 1.1.15-11.el7_3.4-e174ec8) - partition with quorum
Last updated: Mon Jun  5 22:46:30 2017		Last change: Sun Jun  4 19:47:49 2017 by root via crm_attribute on gluster2

2 nodes and 12 resources configured

Online: [ gluster2 ]
OFFLINE: [ gluster1 ]

Full list of resources:

 Clone Set: nfs_setup-clone [nfs_setup]
     Started: [ gluster2 ]
     Stopped: [ gluster1 ]
 Clone Set: nfs-mon-clone [nfs-mon]
     Started: [ gluster2 ]
     Stopped: [ gluster1 ]
 Clone Set: nfs-grace-clone [nfs-grace]
     Started: [ gluster2 ]
     Stopped: [ gluster1 ]
 Resource Group: gluster1-group
     gluster1-nfs_block	(ocf::heartbeat:portblock):	Started gluster2
     gluster1-cluster_ip-1	(ocf::heartbeat:IPaddr):	Started gluster2
     gluster1-nfs_unblock	(ocf::heartbeat:portblock):	Started gluster2
 Resource Group: gluster2-group
     gluster2-nfs_block	(ocf::heartbeat:portblock):	Started gluster2
     gluster2-cluster_ip-1	(ocf::heartbeat:IPaddr):	Started gluster2
     gluster2-nfs_unblock	(ocf::heartbeat:portblock):	Started gluster2

Daemon Status:
  corosync: active/disabled
  pacemaker: active/disabled
  pcsd: active/enabled
```

gluster1 を再起動させると元に戻ります

```
[root@gluster1 ~]# pcs status
Cluster name: ganesha
Stack: corosync
Current DC: gluster2 (version 1.1.15-11.el7_3.4-e174ec8) - partition with quorum
Last updated: Mon Jun  5 23:04:58 2017		Last change: Sun Jun  4 19:47:49 2017 by root via crm_attribute on gluster2

2 nodes and 12 resources configured

Online: [ gluster1 gluster2 ]

Full list of resources:

 Clone Set: nfs_setup-clone [nfs_setup]
     Started: [ gluster1 gluster2 ]
 Clone Set: nfs-mon-clone [nfs-mon]
     Started: [ gluster1 gluster2 ]
 Clone Set: nfs-grace-clone [nfs-grace]
     Started: [ gluster1 gluster2 ]
 Resource Group: gluster1-group
     gluster1-nfs_block	(ocf::heartbeat:portblock):	Started gluster1
     gluster1-cluster_ip-1	(ocf::heartbeat:IPaddr):	Started gluster1
     gluster1-nfs_unblock	(ocf::heartbeat:portblock):	Started gluster1
 Resource Group: gluster2-group
     gluster2-nfs_block	(ocf::heartbeat:portblock):	Started gluster2
     gluster2-cluster_ip-1	(ocf::heartbeat:IPaddr):	Started gluster2
     gluster2-nfs_unblock	(ocf::heartbeat:portblock):	Started gluster2

Daemon Status:
  corosync: active/enabled
  pacemaker: active/enabled
  pcsd: active/enabled
```

停止中に作成したファイルも同期されています

```
[root@gluster1 ~]# ls /gluster/vol1/brick1/brick/
test2.txt  test.txt
[root@gluster1 ~]# cat /gluster/vol1/brick1/brick/test2.txt 
test2
[root@gluster1 ~]# 
```

次はアクセスコントロールを。
