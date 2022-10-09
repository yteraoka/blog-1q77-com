---
title: 'DELL PowerEdge の Firmware は DSU で簡単更新'
date: Tue, 12 Jan 2016 13:34:17 +0000
draft: false
tags: ['Linux', 'DELL', 'firmware']
---

Dell の PowerEdge サーバーを Linux で使う場合のお話です。

Dell の Linux 関連情報は [http://linux.dell.com/](http://linux.dell.com/) にあります。

これまで OpenManage Server Administrator については http://linux.dell.com/repo/hardware/latest/ の YUM repository を使ってインストールしていました。

が、昨年 Dell System Update (DSU) [http://linux.dell.com/repo/hardware/dsu/](http://linux.dell.com/repo/hardware/dsu/) が出現していました。
DSU を使うと Server Administrator だけでなく Firmware も Linux 上から簡単に更新できます。
わざわざ Download サイトにいって、必要なものを探してダウンロードしなくても良いのです、これは大変便利。
UEFI BIOS からも更新できましたが、OS の shutdown が必要ですし、何やってるのかわからない状態でずーーーっと待たされる遅さが困りものでした。 それでは使い方を見てみましょう リポジトリの登録 （CentOS 7 の最小インストールでは wget は入っていないので curl を使いたいところですが、スクリプト内でも wget が使われているので観念してインストールしましょう、さらに perl も使われているので `yum -y install wget perl` しましょう。）

```
[root@server ~]# wget -q -O - http://linux.dell.com/repo/hardware/dsu/bootstrap.cgi | bash
Downloading GPG key: http://linux.dell.com/repo/hardware/dsu/public.key
    Importing key into RPM.
Write repository configuration
Done!
[root@server ~]# yum clean all
Loaded plugins: fastestmirror
Cleaning repos: base dell-system-update_dependent dell-system-update_independent
              : extras updates
Cleaning up everything
Cleaning up list of fastest mirrors
```

DSU のインストール

```
[root@server ~]# yum install dell-system-update
Loaded plugins: fastestmirror
base                                                     | 3.6 kB     00:00
dell-system-update_dependent                             | 2.3 kB     00:00
dell-system-update_independent                           | 2.3 kB     00:00
extras                                                   | 3.4 kB     00:00
updates                                                  | 3.4 kB     00:00
(1/6): base/7/x86_64/group_gz                              | 155 kB   00:00
(2/6): updates/7/x86_64/primary_db                         | 953 kB   00:00
(3/6): extras/7/x86_64/primary_db                          |  90 kB   00:00
(4/6): base/7/x86_64/primary_db                            | 5.3 MB   00:00
(5/6): dell-system-update_dependent/7/x86_64/primary_db    |  32 kB   00:00
(6/6): dell-system-update_independent/primary_db           | 111 kB   00:00
Determining fastest mirrors
 * base: ftp.tsukuba.wide.ad.jp
 * extras: ftp.tsukuba.wide.ad.jp
 * updates: ftp.tsukuba.wide.ad.jp
Resolving Dependencies
--> Running transaction check
---> Package dell-system-update.x86_64 0:1.1-15.12.00 will be installed
--> Finished Dependency Resolution

Dependencies Resolved

================================================================================
 Package            Arch   Version         Repository                      Size
================================================================================
Installing:
 dell-system-update x86_64 1.1-15.12.00    dell-system-update_independent 2.0 M

Transaction Summary
================================================================================
Install  1 Package

Total download size: 2.0 M
Installed size: 8.3 M
Is this ok [y/d/N]: y
Downloading packages:
dell-system-update-1.1-15.12.00.x86_64.rpm                 | 2.0 MB   00:02
Running transaction check
Running transaction test
Transaction test succeeded
Running transaction
  Installing : dell-system-update-1.1-15.12.00.x86_64                       1/1
  Verifying  : dell-system-update-1.1-15.12.00.x86_64                       1/1

Installed:
  dell-system-update.x86_64 0:1.1-15.12.00

Complete!
```

Server Administrator のインストール

```
[root@server ~]# yum install srvadmin-storageservices-cli srvadmin-storageservices-snmp
Loaded plugins: fastestmirror
Loading mirror speeds from cached hostfile
 * base: ftp.tsukuba.wide.ad.jp
 * extras: ftp.tsukuba.wide.ad.jp
 * updates: ftp.tsukuba.wide.ad.jp
Resolving Dependencies
--> Running transaction check
---> Package srvadmin-storageservices-cli.x86_64 0:8.2.0-1739.8348.el7 will be installed
--> Processing Dependency: srvadmin-sysfsutils = 8.2.0 for package: srvadmin-storageservices-cli-8.2.0-1739.8348.el7.x86_64
--> Processing Dependency: srvadmin-storelib = 8.2.0 for package: srvadmin-storageservices-cli-8.2.0-1739.8348.el7.x86_64
--> Processing Dependency: srvadmin-storage-cli = 8.2.0 for package: srvadmin-storageservices-cli-8.2.0-1739.8348.el7.x86_64
--> Processing Dependency: srvadmin-storage = 8.2.0 for package: srvadmin-storageservices-cli-8.2.0-1739.8348.el7.x86_64
--> Processing Dependency: srvadmin-smcommon = 8.2.0 for package: srvadmin-storageservices-cli-8.2.0-1739.8348.el7.x86_64
---> Package srvadmin-storageservices-snmp.x86_64 0:8.2.0-1739.8348.el7 will be installed
--> Processing Dependency: srvadmin-storage-snmp = 8.2.0 for package: srvadmin-storageservices-snmp-8.2.0-1739.8348.el7.x86_64
--> Processing Dependency: srvadmin-isvc-snmp = 8.2.0 for package: srvadmin-storageservices-snmp-8.2.0-1739.8348.el7.x86_64
--> Processing Dependency: srvadmin-idrac-snmp = 8.2.0 for package: srvadmin-storageservices-snmp-8.2.0-1739.8348.el7.x86_64
--> Processing Dependency: srvadmin-deng-snmp = 8.2.0 for package: srvadmin-storageservices-snmp-8.2.0-1739.8348.el7.x86_64
--> Running transaction check
---> Package srvadmin-deng-snmp.x86_64 0:8.2.0-1739.8348.el7 will be installed
--> Processing Dependency: srvadmin-deng = 8.2.0-1739.8348.el7 for package: srvadmin-deng-snmp-8.2.0-1739.8348.el7.x86_64
--> Processing Dependency: libdcsupt.so.8()(64bit) for package: srvadmin-deng-snmp-8.2.0-1739.8348.el7.x86_64
---> Package srvadmin-idrac-snmp.x86_64 0:8.2.0-1739.8348.el7 will be installed
--> Processing Dependency: srvadmin-omilcore for package: srvadmin-idrac-snmp-8.2.0-1739.8348.el7.x86_64
--> Processing Dependency: libdcsdrs.so.8()(64bit) for package: srvadmin-idrac-snmp-8.2.0-1739.8348.el7.x86_64
---> Package srvadmin-isvc-snmp.x86_64 0:8.2.0-1739.8348.el7 will be installed
--> Processing Dependency: srvadmin-isvc = 8.2.0-1739.8348.el7 for package: srvadmin-isvc-snmp-8.2.0-1739.8348.el7.x86_64
--> Processing Dependency: srvadmin-hapi for package: srvadmin-isvc-snmp-8.2.0-1739.8348.el7.x86_64
--> Processing Dependency: libdcship.so.8()(64bit) for package: srvadmin-isvc-snmp-8.2.0-1739.8348.el7.x86_64
---> Package srvadmin-smcommon.x86_64 0:8.2.0-1739.8348.el7 will be installed
---> Package srvadmin-storage.x86_64 0:8.2.0-1739.8348.el7 will be installed
--> Processing Dependency: srvadmin-realssd for package: srvadmin-storage-8.2.0-1739.8348.el7.x86_64
--> Processing Dependency: srvadmin-nvme for package: srvadmin-storage-8.2.0-1739.8348.el7.x86_64
--> Processing Dependency: libxmlsup.so.2()(64bit) for package: srvadmin-storage-8.2.0-1739.8348.el7.x86_64
--> Processing Dependency: libsmbios.so.2()(64bit) for package: srvadmin-storage-8.2.0-1739.8348.el7.x86_64
--> Processing Dependency: libomacs.so.1()(64bit) for package: srvadmin-storage-8.2.0-1739.8348.el7.x86_64
--> Processing Dependency: libRealSSD-API.so()(64bit) for package: srvadmin-storage-8.2.0-1739.8348.el7.x86_64
---> Package srvadmin-storage-cli.x86_64 0:8.2.0-1739.8348.el7 will be installed
--> Processing Dependency: libclpsup.so.4()(64bit) for package: srvadmin-storage-cli-8.2.0-1739.8348.el7.x86_64
---> Package srvadmin-storage-snmp.x86_64 0:8.2.0-1739.8348.el7 will be installed
---> Package srvadmin-storelib.x86_64 0:8.2.0-1739.8348.el7 will be installed
--> Processing Dependency: srvadmin-storelib-sysfs-x86_64 for package: srvadmin-storelib-8.2.0-1739.8348.el7.x86_64
--> Processing Dependency: srvadmin-storelib-sysfs for package: srvadmin-storelib-8.2.0-1739.8348.el7.x86_64
---> Package srvadmin-sysfsutils.x86_64 0:8.2.0-1739.8348.el7 will be installed
--> Running transaction check
---> Package libsmbios.x86_64 0:2.2.27-1739.8348.el7 will be installed
---> Package srvadmin-deng.x86_64 0:8.2.0-1739.8348.el7 will be installed
---> Package srvadmin-hapi.x86_64 0:8.2.0-1739.8348.el7 will be installed
---> Package srvadmin-isvc.x86_64 0:8.2.0-1739.8348.el7 will be installed
---> Package srvadmin-nvme.x86_64 0:8.2.0-1739.8348.el7 will be installed
---> Package srvadmin-omacore.x86_64 0:8.2.0-1739.8348.el7 will be installed
--> Processing Dependency: srvadmin-ominst for package: srvadmin-omacore-8.2.0-1739.8348.el7.x86_64
--> Processing Dependency: srvadmin-omcommon for package: srvadmin-omacore-8.2.0-1739.8348.el7.x86_64
---> Package srvadmin-omacs.x86_64 0:8.2.0-1739.8348.el7 will be installed
---> Package srvadmin-omilcore.x86_64 0:8.2.0-1739.8348.el7 will be installed
--> Processing Dependency: smbios-utils-bin for package: srvadmin-omilcore-8.2.0-1739.8348.el7.x86_64
---> Package srvadmin-rac-components.x86_64 0:8.2.0-1739.8348.el7 will be installed
---> Package srvadmin-realssd.x86_64 0:8.2.0-1739.8348.el7 will be installed
---> Package srvadmin-storelib-sysfs.x86_64 0:8.2.0-1739.8348.el7 will be installed
---> Package srvadmin-xmlsup.x86_64 0:8.2.0-1739.8348.el7 will be installed
--> Running transaction check
---> Package smbios-utils-bin.x86_64 0:2.2.27-1739.8348.el7 will be installed
---> Package srvadmin-omcommon.x86_64 0:8.2.0-1739.8348.el7 will be installed
---> Package srvadmin-ominst.x86_64 0:8.2.0-1739.8348.el7 will be installed
--> Finished Dependency Resolution

Dependencies Resolved

================================================================================
 Package          Arch   Version             Repository                    Size
================================================================================
Installing:
 srvadmin-storageservices-cli
                  x86_64 8.2.0-1739.8348.el7 dell-system-update_dependent 2.7 k
 srvadmin-storageservices-snmp
                  x86_64 8.2.0-1739.8348.el7 dell-system-update_dependent 2.8 k
Installing for dependencies:
 libsmbios        x86_64 2.2.27-1739.8348.el7
                                             dell-system-update_dependent 1.6 M
 smbios-utils-bin x86_64 2.2.27-1739.8348.el7
                                             dell-system-update_dependent  93 k
 srvadmin-deng    x86_64 8.2.0-1739.8348.el7 dell-system-update_dependent 728 k
 srvadmin-deng-snmp
                  x86_64 8.2.0-1739.8348.el7 dell-system-update_dependent  42 k
 srvadmin-hapi    x86_64 8.2.0-1739.8348.el7 dell-system-update_dependent 941 k
 srvadmin-idrac-snmp
                  x86_64 8.2.0-1739.8348.el7 dell-system-update_dependent  61 k
 srvadmin-isvc    x86_64 8.2.0-1739.8348.el7 dell-system-update_dependent 3.6 M
 srvadmin-isvc-snmp
                  x86_64 8.2.0-1739.8348.el7 dell-system-update_dependent 340 k
 srvadmin-nvme    x86_64 8.2.0-1739.8348.el7 dell-system-update_dependent  12 k
 srvadmin-omacore x86_64 8.2.0-1739.8348.el7 dell-system-update_dependent 561 k
 srvadmin-omacs   x86_64 8.2.0-1739.8348.el7 dell-system-update_dependent 2.6 M
 srvadmin-omcommon
                  x86_64 8.2.0-1739.8348.el7 dell-system-update_dependent 1.6 M
 srvadmin-omilcore
                  x86_64 8.2.0-1739.8348.el7 dell-system-update_dependent  30 k
 srvadmin-ominst  x86_64 8.2.0-1739.8348.el7 dell-system-update_dependent 1.2 M
 srvadmin-rac-components
                  x86_64 8.2.0-1739.8348.el7 dell-system-update_dependent  35 k
 srvadmin-realssd x86_64 8.2.0-1739.8348.el7 dell-system-update_dependent  94 k
 srvadmin-smcommon
                  x86_64 8.2.0-1739.8348.el7 dell-system-update_dependent 668 k
 srvadmin-storage x86_64 8.2.0-1739.8348.el7 dell-system-update_dependent 3.1 M
 srvadmin-storage-cli
                  x86_64 8.2.0-1739.8348.el7 dell-system-update_dependent 222 k
 srvadmin-storage-snmp
                  x86_64 8.2.0-1739.8348.el7 dell-system-update_dependent 175 k
 srvadmin-storelib
                  x86_64 8.2.0-1739.8348.el7 dell-system-update_dependent 320 k
 srvadmin-storelib-sysfs
                  x86_64 8.2.0-1739.8348.el7 dell-system-update_dependent  44 k
 srvadmin-sysfsutils
                  x86_64 8.2.0-1739.8348.el7 dell-system-update_dependent  54 k
 srvadmin-xmlsup  x86_64 8.2.0-1739.8348.el7 dell-system-update_dependent  51 k

Transaction Summary
================================================================================
Install  2 Packages (+24 Dependent packages)

Total download size: 18 M
Installed size: 95 M
Is this ok [y/d/N]: y
Downloading packages:
(1/26): smbios-utils-bin-2.2.27-1739.8348.el7.x86_64.rpm   |  93 kB   00:00
(2/26): libsmbios-2.2.27-1739.8348.el7.x86_64.rpm          | 1.6 MB   00:02
(3/26): srvadmin-deng-8.2.0-1739.8348.el7.x86_64.rpm       | 728 kB   00:02
(4/26): srvadmin-deng-snmp-8.2.0-1739.8348.el7.x86_64.rpm  |  42 kB   00:00
(5/26): srvadmin-idrac-snmp-8.2.0-1739.8348.el7.x86_64.rpm |  61 kB   00:00
(6/26): srvadmin-hapi-8.2.0-1739.8348.el7.x86_64.rpm       | 941 kB   00:02
(7/26): srvadmin-isvc-snmp-8.2.0-1739.8348.el7.x86_64.rpm  | 340 kB   00:01
(8/26): srvadmin-isvc-8.2.0-1739.8348.el7.x86_64.rpm       | 3.6 MB   00:03
(9/26): srvadmin-nvme-8.2.0-1739.8348.el7.x86_64.rpm       |  12 kB   00:00
(10/26): srvadmin-omacore-8.2.0-1739.8348.el7.x86_64.rpm   | 561 kB   00:01
(11/26): srvadmin-omacs-8.2.0-1739.8348.el7.x86_64.rpm     | 2.6 MB   00:03
(12/26): srvadmin-omcommon-8.2.0-1739.8348.el7.x86_64.rpm  | 1.6 MB   00:02
(13/26): srvadmin-omilcore-8.2.0-1739.8348.el7.x86_64.rpm  |  30 kB   00:00
(14/26): srvadmin-rac-components-8.2.0-1739.8348.el7.x86_6 |  35 kB   00:00
(15/26): srvadmin-realssd-8.2.0-1739.8348.el7.x86_64.rpm   |  94 kB   00:00
(16/26): srvadmin-ominst-8.2.0-1739.8348.el7.x86_64.rpm    | 1.2 MB   00:01
(17/26): srvadmin-smcommon-8.2.0-1739.8348.el7.x86_64.rpm  | 668 kB   00:01
(18/26): srvadmin-storage-cli-8.2.0-1739.8348.el7.x86_64.r | 222 kB   00:01
(19/26): srvadmin-storage-8.2.0-1739.8348.el7.x86_64.rpm   | 3.1 MB   00:02
(20/26): srvadmin-storageservices-cli-8.2.0-1739.8348.el7. | 2.7 kB   00:00
(21/26): srvadmin-storageservices-snmp-8.2.0-1739.8348.el7 | 2.8 kB   00:00
(22/26): srvadmin-storage-snmp-8.2.0-1739.8348.el7.x86_64. | 175 kB   00:01
(23/26): srvadmin-storelib-sysfs-8.2.0-1739.8348.el7.x86_6 |  44 kB   00:00
(24/26): srvadmin-storelib-8.2.0-1739.8348.el7.x86_64.rpm  | 320 kB   00:01
(25/26): srvadmin-xmlsup-8.2.0-1739.8348.el7.x86_64.rpm    |  51 kB   00:00
(26/26): srvadmin-sysfsutils-8.2.0-1739.8348.el7.x86_64.rp |  54 kB   00:00
--------------------------------------------------------------------------------
Total                                              964 kB/s |  18 MB  00:19
Running transaction check
Running transaction test
Transaction test succeeded
Running transaction
  Installing : srvadmin-xmlsup-8.2.0-1739.8348.el7.x86_64                  1/26
  Installing : srvadmin-smcommon-8.2.0-1739.8348.el7.x86_64                2/26
  Installing : libsmbios-2.2.27-1739.8348.el7.x86_64                       3/26
  Installing : srvadmin-sysfsutils-8.2.0-1739.8348.el7.x86_64              4/26
  Installing : srvadmin-hapi-8.2.0-1739.8348.el7.x86_64                    5/26
  Installing : smbios-utils-bin-2.2.27-1739.8348.el7.x86_64                6/26
  Installing : srvadmin-omilcore-8.2.0-1739.8348.el7.x86_64                7/26
     **********************************************************
     After the install process completes, you may need
     to log out and then log in again to reset the PATH
     variable to access the Server Administrator CLI utilities

     **********************************************************
  Installing : srvadmin-deng-8.2.0-1739.8348.el7.x86_64                    8/26
  Installing : srvadmin-omacs-8.2.0-1739.8348.el7.x86_64                   9/26
  Installing : srvadmin-isvc-8.2.0-1739.8348.el7.x86_64                   10/26
  Installing : srvadmin-deng-snmp-8.2.0-1739.8348.el7.x86_64              11/26
  Installing : srvadmin-isvc-snmp-8.2.0-1739.8348.el7.x86_64              12/26
  Installing : srvadmin-ominst-8.2.0-1739.8348.el7.x86_64                 13/26
  Installing : srvadmin-rac-components-8.2.0-1739.8348.el7.x86_64         14/26
  Installing : srvadmin-idrac-snmp-8.2.0-1739.8348.el7.x86_64             15/26
  Installing : srvadmin-omcommon-8.2.0-1739.8348.el7.x86_64               16/26
  Installing : srvadmin-omacore-8.2.0-1739.8348.el7.x86_64                17/26
  Installing : srvadmin-realssd-8.2.0-1739.8348.el7.x86_64                18/26
  Installing : srvadmin-storelib-sysfs-8.2.0-1739.8348.el7.x86_64         19/26
  Installing : srvadmin-storelib-8.2.0-1739.8348.el7.x86_64               20/26
  Installing : srvadmin-nvme-8.2.0-1739.8348.el7.x86_64                   21/26
  Installing : srvadmin-storage-8.2.0-1739.8348.el7.x86_64                22/26
  Installing : srvadmin-storage-cli-8.2.0-1739.8348.el7.x86_64            23/26
  Installing : srvadmin-storage-snmp-8.2.0-1739.8348.el7.x86_64           24/26
  Installing : srvadmin-storageservices-snmp-8.2.0-1739.8348.el7.x86_64   25/26
  Installing : srvadmin-storageservices-cli-8.2.0-1739.8348.el7.x86_64    26/26
  Verifying  : srvadmin-deng-8.2.0-1739.8348.el7.x86_64                    1/26
  Verifying  : srvadmin-hapi-8.2.0-1739.8348.el7.x86_64                    2/26
  Verifying  : srvadmin-isvc-8.2.0-1739.8348.el7.x86_64                    3/26
  Verifying  : srvadmin-nvme-8.2.0-1739.8348.el7.x86_64                    4/26
  Verifying  : srvadmin-sysfsutils-8.2.0-1739.8348.el7.x86_64              5/26
  Verifying  : srvadmin-deng-snmp-8.2.0-1739.8348.el7.x86_64               6/26
  Verifying  : srvadmin-storage-cli-8.2.0-1739.8348.el7.x86_64             7/26
  Verifying  : srvadmin-smcommon-8.2.0-1739.8348.el7.x86_64                8/26
  Verifying  : srvadmin-storage-8.2.0-1739.8348.el7.x86_64                 9/26
  Verifying  : srvadmin-rac-components-8.2.0-1739.8348.el7.x86_64         10/26
  Verifying  : srvadmin-omacs-8.2.0-1739.8348.el7.x86_64                  11/26
  Verifying  : srvadmin-xmlsup-8.2.0-1739.8348.el7.x86_64                 12/26
  Verifying  : srvadmin-omacore-8.2.0-1739.8348.el7.x86_64                13/26
  Verifying  : srvadmin-idrac-snmp-8.2.0-1739.8348.el7.x86_64             14/26
  Verifying  : srvadmin-storelib-8.2.0-1739.8348.el7.x86_64               15/26
  Verifying  : libsmbios-2.2.27-1739.8348.el7.x86_64                      16/26
  Verifying  : srvadmin-storageservices-cli-8.2.0-1739.8348.el7.x86_64    17/26
  Verifying  : srvadmin-omcommon-8.2.0-1739.8348.el7.x86_64               18/26
  Verifying  : srvadmin-isvc-snmp-8.2.0-1739.8348.el7.x86_64              19/26
  Verifying  : srvadmin-storageservices-snmp-8.2.0-1739.8348.el7.x86_64   20/26
  Verifying  : srvadmin-omilcore-8.2.0-1739.8348.el7.x86_64               21/26
  Verifying  : smbios-utils-bin-2.2.27-1739.8348.el7.x86_64               22/26
  Verifying  : srvadmin-storelib-sysfs-8.2.0-1739.8348.el7.x86_64         23/26
  Verifying  : srvadmin-realssd-8.2.0-1739.8348.el7.x86_64                24/26
  Verifying  : srvadmin-ominst-8.2.0-1739.8348.el7.x86_64                 25/26
  Verifying  : srvadmin-storage-snmp-8.2.0-1739.8348.el7.x86_64           26/26

Installed:
  srvadmin-storageservices-cli.x86_64 0:8.2.0-1739.8348.el7
  srvadmin-storageservices-snmp.x86_64 0:8.2.0-1739.8348.el7

Dependency Installed:
  libsmbios.x86_64 0:2.2.27-1739.8348.el7
  smbios-utils-bin.x86_64 0:2.2.27-1739.8348.el7
  srvadmin-deng.x86_64 0:8.2.0-1739.8348.el7
  srvadmin-deng-snmp.x86_64 0:8.2.0-1739.8348.el7
  srvadmin-hapi.x86_64 0:8.2.0-1739.8348.el7
  srvadmin-idrac-snmp.x86_64 0:8.2.0-1739.8348.el7
  srvadmin-isvc.x86_64 0:8.2.0-1739.8348.el7
  srvadmin-isvc-snmp.x86_64 0:8.2.0-1739.8348.el7
  srvadmin-nvme.x86_64 0:8.2.0-1739.8348.el7
  srvadmin-omacore.x86_64 0:8.2.0-1739.8348.el7
  srvadmin-omacs.x86_64 0:8.2.0-1739.8348.el7
  srvadmin-omcommon.x86_64 0:8.2.0-1739.8348.el7
  srvadmin-omilcore.x86_64 0:8.2.0-1739.8348.el7
  srvadmin-ominst.x86_64 0:8.2.0-1739.8348.el7
  srvadmin-rac-components.x86_64 0:8.2.0-1739.8348.el7
  srvadmin-realssd.x86_64 0:8.2.0-1739.8348.el7
  srvadmin-smcommon.x86_64 0:8.2.0-1739.8348.el7
  srvadmin-storage.x86_64 0:8.2.0-1739.8348.el7
  srvadmin-storage-cli.x86_64 0:8.2.0-1739.8348.el7
  srvadmin-storage-snmp.x86_64 0:8.2.0-1739.8348.el7
  srvadmin-storelib.x86_64 0:8.2.0-1739.8348.el7
  srvadmin-storelib-sysfs.x86_64 0:8.2.0-1739.8348.el7
  srvadmin-sysfsutils.x86_64 0:8.2.0-1739.8348.el7
  srvadmin-xmlsup.x86_64 0:8.2.0-1739.8348.el7

Complete!
```

Server Administrator daemon の起動

```
[root@server ~]# . /etc/profile.d/srvadmin-path.sh
[root@server ~]# srvadmin-services.sh start
Starting instsvcdrv (via systemctl):                       [  OK  ]
Starting dataeng (via systemctl):                          [  OK  ]
Starting dsm_om_shrsvc (via systemctl):                    [  OK  ]
```

それではいよいよ DSU による firmware 更新です `--inventory` をつけて実行すると現状のバージョンが確認できます

```
[root@server ~]# dsu --inventory
Getting System Inventory...

1. OpenManage Server Administrator  ( Version : 8.2.0 )

2. BIOS  ( Version : 1.2.6 )

3. Lifecycle Controller  ( Version : 2.20.20.20 )

4. Dell 32 Bit uEFI Diagnostics, version 4239, 4239A24, 4239.32  ( Version : 4239A24 )

5. OS COLLECTOR 1.1, OSC_1.1, A00  ( Version : OSC_1.1 )

6. Power Supply  ( Version : 00.30.43 )

7. PERC H730P Mini Controller 0 Firmware  ( Version : 25.3.0.0016 )

8. Firmware for  - Disk 0 in Backplane 1 of PERC H730P Mini Controller 0    ( Version : TS04 )

9.  iDRAC  ( Version : 2.20.20.20 )

10. NetXtreme BCM5720 Gigabit Ethernet PCIe (em3)  ( Version : 7.10.61 )

11. NetXtreme BCM5720 Gigabit Ethernet PCIe (em4)  ( Version : 7.10.61 )

12. NetXtreme BCM5720 Gigabit Ethernet PCIe (em1)  ( Version : 7.10.61 )

13. NetXtreme BCM5720 Gigabit Ethernet PCIe (em2)  ( Version : 7.10.61 )

14. Intel(R) Ethernet 10G 2P X540-t Adapter  ( Version : 16.5.20 )

15. Intel(R) Ethernet 10G 2P X540-t Adapter  ( Version : 16.5.20 )

16. 13G SEP Firmware, BayID: 1  ( Version : 2.23 )
```

dsu コマンドを引数なしで実行するとどれを更新するか尋ねられます

```
[root@server ~]# dsu
Getting System Inventory...
Determining Applicable Updates...

|-----------Dell System Updates-----------|
[ ] represents 'not selected'
[*] represents 'selected'
[-] represents 'Component already at repository version (cannot be selected)'
Choose:  q - Quit without update, c to Commit, - To Select/Deselect, a - Select All, n - Select None

[-]1 OS COLLECTOR 1.1, OSC_1.1, A00
 Current Version : OSC_1.1 same as : OSC_1.1

[-]2 13G SEP Firmware, BayID: 1
 Current Version : 2.23 same as : 2.23

[ ]3 NetXtreme BCM5720 Gigabit Ethernet PCIe (em2)
 Current Version : 7.10.61 Upgrade to : 7.10.64

[ ]4 NetXtreme BCM5720 Gigabit Ethernet PCIe (em1)
 Current Version : 7.10.61 Upgrade to : 7.10.64

[ ]5 NetXtreme BCM5720 Gigabit Ethernet PCIe (em4)
 Current Version : 7.10.61 Upgrade to : 7.10.64

[ ]6 NetXtreme BCM5720 Gigabit Ethernet PCIe (em3)
 Current Version : 7.10.61 Upgrade to : 7.10.64

[-]7 Dell 32 Bit uEFI Diagnostics, version 4239, 4239A24, 4239.32
 Current Version : 4239A24 same as : 4239A24

[-]8 PERC H730P Mini Controller 0 Firmware
 Current Version : 25.3.0.0016 same as : 25.3.0.0016

[-]9 Firmware for  - Disk 0 in Backplane 1 of PERC H730P Mini Controller 0
 Current Version : TS04 same as : TS04

[ ]10  iDRAC
 Current Version : 2.20.20.20 Upgrade to : 2.21.21.21

[-]11 OpenManage Server Administrator
 Current Version : 8.2.0 same as : 8.2

[ ]12 Intel(R) Ethernet 10G 2P X540-t Adapter
 Current Version : 16.5.20 Upgrade to : 17.0.12

[ ]13 Intel(R) Ethernet 10G 2P X540-t Adapter
 Current Version : 16.5.20 Upgrade to : 17.0.12

[ ]14 BIOS
 Current Version : 1.2.6 Upgrade to : 1.5.4

[ ]15 Power Supply
 Current Version : 00.30.43 Upgrade to : 00.30.44

Enter your choice : a 
```

`a` で更新可能なもの全てを選択します。

```
|-----------Dell System Updates-----------|
[ ] represents 'not selected'
[*] represents 'selected'
[-] represents 'Component already at repository version (cannot be selected)'
Choose:  q - Quit without update, c to Commit, - To Select/Deselect, a - Select All, n - Select None

[-]1 OS COLLECTOR 1.1, OSC_1.1, A00
 Current Version : OSC_1.1 same as : OSC_1.1

[-]2 13G SEP Firmware, BayID: 1
 Current Version : 2.23 same as : 2.23

[*]3 NetXtreme BCM5720 Gigabit Ethernet PCIe (em2)
 Current Version : 7.10.61 Upgrade to : 7.10.64

[*]4 NetXtreme BCM5720 Gigabit Ethernet PCIe (em1)
 Current Version : 7.10.61 Upgrade to : 7.10.64

[*]5 NetXtreme BCM5720 Gigabit Ethernet PCIe (em4)
 Current Version : 7.10.61 Upgrade to : 7.10.64

[*]6 NetXtreme BCM5720 Gigabit Ethernet PCIe (em3)
 Current Version : 7.10.61 Upgrade to : 7.10.64

[-]7 Dell 32 Bit uEFI Diagnostics, version 4239, 4239A24, 4239.32
 Current Version : 4239A24 same as : 4239A24

[-]8 PERC H730P Mini Controller 0 Firmware
 Current Version : 25.3.0.0016 same as : 25.3.0.0016

[-]9 Firmware for  - Disk 0 in Backplane 1 of PERC H730P Mini Controller 0
 Current Version : TS04 same as : TS04

[*]10  iDRAC
 Current Version : 2.20.20.20 Upgrade to : 2.21.21.21

[-]11 OpenManage Server Administrator
 Current Version : 8.2.0 same as : 8.2

[*]12 Intel(R) Ethernet 10G 2P X540-t Adapter
 Current Version : 16.5.20 Upgrade to : 17.0.12

[*]13 Intel(R) Ethernet 10G 2P X540-t Adapter
 Current Version : 16.5.20 Upgrade to : 17.0.12

[*]14 BIOS
 Current Version : 1.2.6 Upgrade to : 1.5.4

[*]15 Power Supply
 Current Version : 00.30.43 Upgrade to : 00.30.44

Enter your choice : c 
```

選択できたら `c` で commit します。 するとインストールが始まります。

インストールの過程で netstat コマンドが使われるので CentOS 7 の場合は `net-tools` package をインストールしておきます。

```
Installing Network_Firmware_0MT4K_LN_7.10.64...
Collecting inventory...
..
Running validation...

NetXtreme BCM5720 Gigabit Ethernet PCIe (em3)

The version of this Update Package is newer than the currently installed version.
Software application name: NetXtreme BCM5720 Gigabit Ethernet PCIe (em3)
Package version: 7.10.64
Installed version: 7.10.61

NetXtreme BCM5720 Gigabit Ethernet PCIe (em4)

The version of this Update Package is newer than the currently installed version.
Software application name: NetXtreme BCM5720 Gigabit Ethernet PCIe (em4)
Package version: 7.10.64
Installed version: 7.10.61

NetXtreme BCM5720 Gigabit Ethernet PCIe (em1)

The version of this Update Package is newer than the currently installed version.
Software application name: NetXtreme BCM5720 Gigabit Ethernet PCIe (em1)
Package version: 7.10.64
Installed version: 7.10.61

NetXtreme BCM5720 Gigabit Ethernet PCIe (em2)

The version of this Update Package is newer than the currently installed version.
Software application name: NetXtreme BCM5720 Gigabit Ethernet PCIe (em2)
Package version: 7.10.64
Installed version: 7.10.61


Executing update...
WARNING: DO NOT STOP THIS PROCESS OR INSTALL OTHER DELL PRODUCTS WHILE UPDATE IS IN PROGRESS.
THESE ACTIONS MAY CAUSE YOUR SYSTEM TO BECOME UNSTABLE!
.......................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................
The system should be restarted for the update to take effect.
Installing iDRAC-with-Lifecycle-Controller_Firmware_1X82C_LN_2.21.21.21_A00...
Collecting inventory...
.
Running validation...

iDRAC

The version of this Update Package is newer than the currently installed version.
Software application name: iDRAC
Package version: 2.21.21.21
Installed version: 2.20.20.20


Executing update...
WARNING: DO NOT STOP THIS PROCESS OR INSTALL OTHER DELL PRODUCTS WHILE UPDATE IS IN PROGRESS.
THESE ACTIONS MAY CAUSE YOUR SYSTEM TO BECOME UNSTABLE!
...................................................................................................................................................................................................................................................................................................................................................................................................................
The update completed successfully.
Installing Network_Firmware_F8H29_LN_17.0.12_A00...
Collecting inventory...
........
Running validation...

Intel(R) Ethernet 10G 2P X540-t Adapter

The version of this Update Package is newer than the currently installed version.
Software application name: Intel(R) Ethernet 10G 2P X540-t Adapter
Package version: 17.0.12
Installed version: 16.5.20

Intel(R) Ethernet 10G 2P X540-t Adapter

The version of this Update Package is newer than the currently installed version.
Software application name: Intel(R) Ethernet 10G 2P X540-t Adapter
Package version: 17.0.12
Installed version: 16.5.20


Executing update...
WARNING: DO NOT STOP THIS PROCESS OR INSTALL OTHER DELL PRODUCTS WHILE UPDATE IS IN PROGRESS.
THESE ACTIONS MAY CAUSE YOUR SYSTEM TO BECOME UNSTABLE!
............................................................................................
The system should be restarted for the update to take effect.
Installing Power_Firmware_Y181V_LN_00.30.44...
Collecting inventory...
..
Running validation...

Power Supply

The version of this Update Package is newer than the currently installed version.
Software application name: Power Supply
Package version: 00.30.44
Installed version: 00.30.43


Executing update...
WARNING: DO NOT STOP THIS PROCESS OR INSTALL OTHER DELL PRODUCTS WHILE UPDATE IS IN PROGRESS.
THESE ACTIONS MAY CAUSE YOUR SYSTEM TO BECOME UNSTABLE!
..........................................................................
The system should be restarted for the update to take effect.
Installing BIOS_1VCPR_LN_1.5.4...
Collecting inventory...
.........
Running validation...

PowerEdge R530/R430/T430 BIOS

The version of this Update Package is newer than the currently installed version.
Software application name: BIOS
Package version: 1.5.4
Installed version: 1.2.6


Executing update...
WARNING: DO NOT STOP THIS PROCESS OR INSTALL OTHER DELL PRODUCTS WHILE UPDATE IS IN PROGRESS.
THESE ACTIONS MAY CAUSE YOUR SYSTEM TO BECOME UNSTABLE!
......................................................................................
The system should be restarted for the update to take effect.

Done! Please run 'dsu --inventory' to check the inventory

Please reboot the system for update(s) to take effect
```

更新完了です。`dsu --inventory` で本当に更新されているか確認します。 後は reboot で完了です。 らっくちーーーん！！ HPE (HP) には [https://downloads.linux.hpe.com/](https://downloads.linux.hpe.com/) というサイトがありますね。 Fujitsu さんなど日本のメーカーさんもやってくれないかなぁ (Java Applet とか嫌だよぅ)

### 追記 (2017/6/8)

追加で i686 の package が必要な場合があった

```
Fetching ESM_Firmware_J7YYK_LN32_2.85_A00 ...
Installing ESM_Firmware_J7YYK_LN32_2.85_A00
The following packages are required for update package to run:
   compat-libstdc++-33.i686 libstdc++.i686 libxml2.i686
Please check  Update package User guide for instructions for installing the dependencies
ESM_Firmware_J7YYK_LN32_2.85_A00 could not be installed
```
