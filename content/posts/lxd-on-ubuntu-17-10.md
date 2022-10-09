---
title: 'Ubuntu 17.10 で LXD を試してみる'
date: Thu, 09 Nov 2017 14:50:14 +0000
draft: false
tags: ['LXD', 'Linux', 'Ubuntu', 'container']
---

PC が "Operating System Not Found" と起動しなくなってしまったので Ubuntu 17.10 をクリーンインストールして「ソフトウェア」ってソフトを起動したらコレクションに LXD があったので試してみることにした。

```
$ sudo snap install lxd
```

でインストールできる。

```
$ sudo lxd init
Do you want to configure a new storage pool (yes/no) [default=yes]? 
Name of the new storage pool [default=default]: 
Name of the storage backend to use (dir, btrfs, ceph, lvm, zfs) [default=zfs]: dir
Would you like LXD to be available over the network (yes/no) [default=no]? 
Would you like stale cached images to be updated automatically (yes/no) [default=yes]? 
Would you like to create a new network bridge (yes/no) [default=yes]? 
What should the new bridge be called [default=lxdbr0]? 
What IPv4 address should be used (CIDR subnet notation, “auto” or “none”) [default=auto]? 
What IPv6 address should be used (CIDR subnet notation, “auto” or “none”) [default=auto]? 
LXD has been successfully configured.
```

CentOS 7 のコンテナを起動させてみる

```
$ sudo lxc launch images:centos/7/amd64 srv01
```

と実行するとイメージのダウンロードが始まります、2回目以降など、既にダウンロード済みならすぐに作成されます。

```
$ sudo lxc launch images:centos/7/amd64 srv01
Creating srv01
Retrieving image: rootfs: 63% (1.65MB/s)
```

```
$ sudo lxc launch images:centos/7/amd64 srv01
Creating srv01
Starting srv01
```

```
$ sudo lxc list
+-------+---------+---------------------+----------------------------------------------+------------+-----------+
| NAME  |  STATE  |        IPV4         |                     IPV6                     |    TYPE    | SNAPSHOTS |
+-------+---------+---------------------+----------------------------------------------+------------+-----------+
| srv01 | RUNNING | 10.20.22.236 (eth0) | fd42:ea65:7ecf:78e8:216:3eff:fe60:5e4 (eth0) | PERSISTENT | 0         |
+-------+---------+---------------------+----------------------------------------------+------------+-----------+
```

```
$ sudo lxc info srv01
Name: srv01
Remote: unix://
Architecture: x86_64
Created: 2017/11/09 14:42 UTC
Status: Running
Type: persistent
Profiles: default
Pid: 8883
Ips:
  eth0:	inet	10.20.22.236	vethHJ05J0
  eth0:	inet6	fd42:ea65:7ecf:78e8:216:3eff:fe60:5e4	vethHJ05J0
  eth0:	inet6	fe80::216:3eff:fe60:5e4	vethHJ05J0
  lo:	inet	127.0.0.1
  lo:	inet6	::1
Resources:
  Processes: 11
  CPU usage:
    CPU usage (in seconds): 1
  Memory usage:
    Memory (current): 37.02MB
    Memory (peak): 40.30MB
  Network usage:
    eth0:
      Bytes received: 33.09kB
      Bytes sent: 1.77kB
      Packets received: 331
      Packets sent: 17
    lo:
      Bytes received: 0B
      Bytes sent: 0B
      Packets received: 0
      Packets sent: 0
```

コンテナ内に入るには lxc exec を使います

```
$ sudo lxc exec srv01 -- bash
[root@srv01 ~]# ps -ef
UID        PID  PPID  C STIME TTY          TIME CMD
root         1     0  0 14:42 ?        00:00:00 /sbin/init
root        33     1  0 14:42 ?        00:00:00 /usr/lib/systemd/systemd-journald
root        37     1  0 14:42 ?        00:00:00 /usr/lib/systemd/systemd-udevd
root        55     1  0 14:42 ?        00:00:00 /usr/sbin/rsyslogd -n
dbus        57     1  0 14:42 ?        00:00:00 /bin/dbus-daemon --system --address=systemd: --nofork --nopidfile --systemd-activation
root        64     1  0 14:42 ?        00:00:00 /usr/lib/systemd/systemd-logind
root        69     1  0 14:42 ?        00:00:00 /usr/sbin/crond -n
root        70     1  0 14:42 console  00:00:00 /sbin/agetty --noclear --keep-baud console 115200 38400 9600 linux
root       242     1  0 14:42 ?        00:00:00 /sbin/dhclient -1 -q -lf /var/lib/dhclient/dhclient--eth0.lease -pf /var/run/dhclient-et
root       303     0  0 14:45 ?        00:00:00 bash
root       312   303  0 14:46 ?        00:00:00 ps -ef
```

[https://linuxcontainers.org/ja/lxd/getting-started-cli/](https://linuxcontainers.org/ja/lxd/getting-started-cli/) を見ると基本的なコマンドの使い方はわかります 停止は lxc stop srv01 削除は lxc delete srv01 イメージのリストは lxc image list イメージの削除は lxc image delete XXXXX (XXXXX は list で表示される FINGERPRINT)

```
$ sudo lxc image list
+-------+--------------+--------+---------------------------------+--------+---------+-----------------------------+
| ALIAS | FINGERPRINT  | PUBLIC |           DESCRIPTION           |  ARCH  |  SIZE   |         UPLOAD DATE         |
+-------+--------------+--------+---------------------------------+--------+---------+-----------------------------+
|       | bd115f8374ba | no     | Centos 7 amd64 (20171109_02:28) | x86_64 | 82.26MB | Nov 9, 2017 at 2:42pm (UTC) |
+-------+--------------+--------+---------------------------------+--------+---------+-----------------------------+
```

lxd グループに自分を追加しておけば lxc コマンドを sudo なしで使えるようになる
