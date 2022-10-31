---
title: 'GlusterFS + NFS-Ganesha で HA な NFS サーバーを構築する (3)'
date: Sat, 20 May 2017 15:33:14 +0000
draft: false
tags: ['CentOS', 'GlusterFS']
---

[前回](/2017/05/building-ha-nfs-server-part2/)からの続き、[GlusterFS シリーズ](/tags/glusterfs/)です。

今回は snapshot 機能を試します。これのために初回に Thin Provisioned Volume で構築しています。

```
[root@client ~]# ls /vol1
01  03  05  07  09  11  13  15  17  19  21  23  25  27  29  31  33  35  37  39
02  04  06  08  10  12  14  16  18  20  22  24  26  28  30  32  34  36  38  40
```

上記状態の vol1 で snapshot を作成します。

```
[root@gluster1 ~]# gluster snapshot create snaptest01 vol1
snapshot create: success: Snap snaptest01_GMT-2017.05.20-14.56.39 created successfully
```

snapshot はデフォルトで名前に日時が追加されます、便利

```
[root@gluster1 ~]# gluster snapshot list vol1
snaptest01_GMT-2017.05.20-14.56.39
```

```
[root@client ~]# rm -f /vol1/*
[root@client ~]# ls /vol1/
[root@client ~]# for s in $(seq -w 41 60); do touch /vol1/$s; done
[root@client ~]# ls /vol1
41  42  43  44  45  46  47  48  49  50  51  52  53  54  55  56  57  58  59  60
```

```
[root@gluster1 ~]# gluster snapshot create snaptest02 vol1
snapshot create: success: Snap snaptest02_GMT-2017.05.20-14.59.23 created successfully
```

```
[root@gluster1 ~]# gluster snapshot list vol1
snaptest01_GMT-2017.05.20-14.56.39
snaptest02_GMT-2017.05.20-14.59.23
```

Thin Provisioning LVM の snapshot なのでパフォーマンス低下を気にせず沢山作成できます。 snapshot01 のファイルを参照したい場合は `snapshot activate` コマンドで有効化すればクライアントからマウントできるようになります。

```
[root@gluster1 ~]# gluster snapshot info snaptest01_GMT-2017.05.20-14.56.39
Snapshot                  : snaptest01_GMT-2017.05.20-14.56.39
Snap UUID                 : 15e8d464-32a9-44c4-a516-101b093cb2c0
Created                   : 2017-05-20 14:56:39
Snap Volumes:

	Snap Volume Name          : ec6da9f837a14187b869f33249024721
	Origin Volume name        : vol1
	Snaps taken for vol1      : 2
	Snaps available for vol1  : 254
	Status                    : Stopped
 
[root@gluster1 ~]# gluster snapshot activate snaptest01_GMT-2017.05.20-14.56.39
Snapshot activate: snaptest01_GMT-2017.05.20-14.56.39: Snap activated successfully
[root@gluster1 ~]# gluster snapshot info snaptest01_GMT-2017.05.20-14.56.39
Snapshot                  : snaptest01_GMT-2017.05.20-14.56.39
Snap UUID                 : 15e8d464-32a9-44c4-a516-101b093cb2c0
Created                   : 2017-05-20 14:56:39
Snap Volumes:

	Snap Volume Name          : ec6da9f837a14187b869f33249024721
	Origin Volume name        : vol1
	Snaps taken for vol1      : 2
	Snaps available for vol1  : 254
	Status                    : Started
```

Status が Started になりました、この状態でクライアントからマウントします

```
[root@client ~]# mount -t glusterfs gluster1:/snaps/snaptest01_GMT-2017.05.20-14.56.39/vol1 /vol1-snap
[root@client ~]# ls /vol1-snap
01  03  05  07  09  11  13  15  17  19  21  23  25  27  29  31  33  35  37  39
02  04  06  08  10  12  14  16  18  20  22  24  26  28  30  32  34  36  38  40
```

用が終わったら umount して deactivate します。

```
[root@gluster1 ~]# gluster snapshot deactivate snaptest01_GMT-2017.05.20-14.56.39
Deactivating snap will make its data inaccessible. Do you want to continue? (y/n) y
Snapshot deactivate: snaptest01_GMT-2017.05.20-14.56.39: Snap deactivated successfully
```

volume の中身を特定の snapshot のものにごっそり入れ替えてしまいたい場合は `snapshot restore` コマンドで入れ替え可能です。restore するためにはまず volume を stop する必要があります。クライアントがマウントしたままの状態でも stop は可能です。もちろん stop 中は volume にアクセスできませんが。

```
[root@gluster1 ~]# gluster volume stop vol1
Stopping volume will make its data inaccessible. Do you want to continue? (y/n) y
volume stop: vol1: success
[root@gluster1 ~]# gluster snapshot restore snaptest01_GMT-2017.05.20-14.56.39
Restore operation will replace the original volume with the snapshotted volume. Do you still want to continue? (y/n) y
Snapshot restore: snaptest01_GMT-2017.05.20-14.56.39: Snap restored successfully
[root@gluster1 ~]# gluster volume start vol1
volume start: vol1: success
```

これで入れ替わりました。クライアント側で確認してみます。

```
[root@client ~]# ls /vol1
01  03  05  07  09  11  13  15  17  19  21  23  25  27  29  31  33  35  37  39
02  04  06  08  10  12  14  16  18  20  22  24  26  28  30  32  34  36  38  40
```

restore するとその snapshot は消えますが、それより前の snapshot も後の snapshot も残っており使用可能です。 snapshot は保存可能な数に上限があります。`snapshot config` で確認できます。上限を超えたものの自動削除を有効にすることもできます。

```
[root@gluster1 ~]# gluster snapshot config

Snapshot System Configuration:
snap-max-hard-limit : 256
snap-max-soft-limit : 90%
auto-delete : disable
activate-on-create : disable

Snapshot Volume Configuration:

Volume : vol1
snap-max-hard-limit : 256
Effective snap-max-hard-limit : 256
Effective snap-max-soft-limit : 230 (90%)

Volume : vol2
snap-max-hard-limit : 256
Effective snap-max-hard-limit : 256
Effective snap-max-soft-limit : 230 (90%)
```

次はいよいよ NFS-Ganesha に進みます。
