---
title: 'GlusterFS + NFS-Ganesha で HA な NFS サーバーを構築する (2)'
date: Sat, 20 May 2017 14:30:05 +0000
draft: false
tags: ['CentOS', 'GlusterFS']
---

[前回](/2017/05/building-ha-nfs-server-part1/) GlusterFS の volume を作成してクライアントとなる Linux からマウントするところまでをやってみました。今回は一部のサーバーが停止してしまったらどうなるのかを試してみます。

```
[root@client ~]# df -h /vol1 /vol2
Filesystem      Size  Used Avail Use% Mounted on
gluster1:/vol1 1021M   33M  988M   4% /vol1
gluster1:/vol2  2.0G   66M  2.0G   4% /vol2
```

`/vol1` は Replicated Volume (1G + 1G = 1G) で /vol2 は Distributed Volume (1G + 1G = 2G) です。 置いたファイルがサーバー側でどう見えるかを確認してみます

```
[root@client ~]# for s in $(seq -w 1 20); do touch /vol1/$s /vol2/$s; done
[root@client ~]# ls /vol1 /vol2
/vol1:
01  02  03  04  05  06  07  08  09  10  11  12  13  14  15  16  17  18  19  20

/vol2:
01  02  03  04  05  06  07  08  09  10  11  12  13  14  15  16  17  18  19  20
[root@client ~]# 
```

```
[root@gluster1 ~]# ls /gluster/vol1/brick1/brick/
01  02  03  04  05  06  07  08  09  10  11  12  13  14  15  16  17  18  19  20
[root@gluster1 ~]# ls /gluster/vol2/brick1/brick/
03  04  05  11  13  18  19  20
[root@gluster1 ~]# 
```

```
[root@gluster2 ~]# ls /gluster/vol1/brick1/brick/
01  02  03  04  05  06  07  08  09  10  11  12  13  14  15  16  17  18  19  20
[root@gluster2 ~]# ls /gluster/vol2/brick1/brick/
01  02  06  07  08  09  10  12  14  15  16  17
[root@gluster2 ~]# 
```

こんな感じで vol1 は gluster1,2 の両方に全部が、vol2 はファイルごとに gluster1,2 のどちらかにだけ存在します。 これで、gluster1 を down させると vol1 はそれでも全てのファイルにアクセス可能で、vo2 は gluster2 にあるファイルだけにアクセスできるというのが期待される動作です。試してみます。 gluster1 停止後は次のようになりました。

```
[root@client ~]# ls /vol1 /vol2
/vol1:
01  02  03  04  05  06  07  08  09  10  11  12  13  14  15  16  17  18  19  20

/vol2:
01  02  06  07  08  09  10  12  14  15  16  17
[root@client ~]# 
```

停止時間がどうだったかというと53秒ほど ls の結果が待たされました。

```
2017-05-20 13:03:23.715827382
2017-05-20 13:04:17.859390739
```

クライアント側の syslog には次のログが出ていました。

```
May 20 13:04:17 client vol1[9362]: [2017-05-20 13:04:17.335765] C [rpc-clnt-ping.c:160:rpc_clnt_ping_timer_expired] 0-vol1-client-0: server 10.130.49.27:49152 has not responded in the last 42 seconds, disconnecting.
```

42秒というのは GlusterFS の volume 毎に設定する network.ping-timeout の値だということなのでこれを短くすることで固まる時間を短くできるのではないかということで試してみます。

```
$ sudo gluster volume get vol1 network.ping-timeout
Option                                  Value                                   
------                                  -----                                   
network.ping-timeout                    42                                      
$ sudo gluster volume set vol1 network.ping-timeout 5
volume set: success
$ sudo gluster volume get vol1 network.ping-timeout
Option                                  Value                                   
------                                  -----                                   
network.ping-timeout                    5                                       
```

`ls /vol1` だけにして試してみたところ停止時間は8秒程度になりました。 次に gluster1 が停止している状態で vol1, vol2 それぞれにファイルを追加するとどうなるかを確認します。 gluster1 は停止しているので Disconnected 状態です。

```
[root@gluster2 ~]# gluster peer status
Number of Peers: 1

Hostname: gluster1
Uuid: 6d9fa83a-dd3b-4a36-956e-4a069e74745e
State: Peer in Cluster (Disconnected)
```

vol1, vol2 それぞれに 21 から 40 というファイルを置いてみます。

```
[root@client ~]# for s in $(seq -w 21 40); do touch /vol1/$s /vol2/$s; done
touch: cannot touch ‘/vol2/23’: Transport endpoint is not connected
touch: cannot touch ‘/vol2/24’: Transport endpoint is not connected
touch: cannot touch ‘/vol2/26’: Transport endpoint is not connected
touch: cannot touch ‘/vol2/27’: Transport endpoint is not connected
touch: cannot touch ‘/vol2/28’: Transport endpoint is not connected
touch: cannot touch ‘/vol2/32’: Transport endpoint is not connected
touch: cannot touch ‘/vol2/33’: Transport endpoint is not connected
touch: cannot touch ‘/vol2/35’: Transport endpoint is not connected
touch: cannot touch ‘/vol2/38’: Transport endpoint is not connected
[root@client ~]# ls /vol1 /vol2
/vol1:
01  03  05  07  09  11  13  15  17  19  21  23  25  27  29  31  33  35  37  39
02  04  06  08  10  12  14  16  18  20  22  24  26  28  30  32  34  36  38  40

/vol2:
01  06  08  10  14  16  21  25  30  34  37  40
02  07  09  12  15  17  22  29  31  36  39
```

Distributed Volume な vol2 は計算によって gluster1 に置かれるべきファイルはサーバーが存在しないということでエラーになりました。 もう gluster1 は起動してこないので諦めようという場合は当該 brick を切り離すことで書き込めるようになります。 `volume status` では見えない brick がどれだったかわからないので

```
[root@gluster2 ~]# gluster volume status vol2
Status of volume: vol2
Gluster process                             TCP Port  RDMA Port  Online  Pid
------------------------------------------------------------------------------
Brick gluster2:/gluster/vol2/brick1/brick   49153     0          Y       28864
 
Task Status of Volume vol2
------------------------------------------------------------------------------
There are no active volume tasks
```

`volume info` で確認します

```
[root@gluster2 ~]# gluster volume info vol2
 
Volume Name: vol2
Type: Distribute
Volume ID: 35be21b5-c624-4cdb-a20f-96cdb6efefbd
Status: Started
Snapshot Count: 0
Number of Bricks: 2
Transport-type: tcp
Bricks:
Brick1: gluster1:/gluster/vol2/brick1/brick
Brick2: gluster2:/gluster/vol2/brick1/brick
Options Reconfigured:
network.ping-timeout: 5
transport.address-family: inet
nfs.disable: on
```

`volume remove-brick` で brick を削除します。アクセスできないので `force` を指定してますし、データロスするよと警告が出ていますが、アクセスできる状態では `start`, `commit` でデータを他の brick に移して安全に削除することができます。

```
[root@gluster2 ~]# gluster volume remove-brick vol2 gluster1:/gluster/vol2/brick1/brick force
Removing brick(s) can result in data loss. Do you want to Continue? (y/n) y
volume remove-brick commit force: success
```

削除できたのでどんなファイルでも書き込めるようになりました。

```
[root@client ~]# for s in $(seq -w 1 40); do touch /vol2/$s; done
[root@client ~]# ls /vol2
01  03  05  07  09  11  13  15  17  19  21  23  25  27  29  31  33  35  37  39
02  04  06  08  10  12  14  16  18  20  22  24  26  28  30  32  34  36  38  40
```

gluster1 を起動させると Replicated Volume の vol1 brick には停止中に書き込んだファイルが自動で同期されています。

```
[root@gluster1 ~]# ls /gluster/vol1/brick1/brick/
01  03  05  07  09  11  13  15  17  19  21  23  25  27  29  31  33  35  37  39
02  04  06  08  10  12  14  16  18  20  22  24  26  28  30  32  34  36  38  40
```

gluster1 の /gluster/vol2/brick1/brick を vol2 に再度追加してみます

```
[root@gluster1 ~]# gluster volume add-brick vol2 gluster1:/gluster/vol2/brick1/brick
volume add-brick: failed: /gluster/vol2/brick1/brick is already part of a volume
```

前のデータが残っているのでそのままでは追加できないため、消してから再登録します。

```
[root@gluster1 ~]# rm -fr /gluster/vol2/brick1/brick
[root@gluster1 ~]# gluster volume add-brick vol2 gluster1:/gluster/vol2/brick1/brick
volume add-brick: success
```

追加されましたが、自動で再配置されるわけではありません。`volume rebalance` コマンドで再配置させられます。

```
[root@gluster1 ~]# gluster volume rebalance vol2 start
volume rebalance: vol2: success: Rebalance on vol2 has been started successfully. Use rebalance status command to check status of the rebalance process.
ID: 4f1bca89-8929-4b84-8e82-cbdf3528a640
```

`volume rebalance` の `status` コマンドでリバランス処理の進み具合を確認できます。今回はファイルが少ししかないので一瞬で終わってます。

```
[root@gluster1 ~]# gluster volume rebalance vol2 status
                                    Node Rebalanced-files          size       scanned      failures       skipped               status  run time in h:m:s
                               ---------      -----------   -----------   -----------   -----------   -----------         ------------     --------------
                               localhost                0        0Bytes             0             0             0            completed        0:00:00
                                gluster2               17        0Bytes            40             0             0            completed        0:00:00
volume rebalance: vol2: success
```

brick のディレクトリを確認するとファイルが移動されています。

```
[root@gluster1 ~]# ls /gluster/vol2/brick1/brick/
03  04  05  11  13  18  19  20  23  24  26  27  28  32  33  35  38
```

```
[root@gluster2 ~]# ls /gluster/vol2/brick1/brick/
01  06  08  10  14  16  21  25  30  34  37  40
02  07  09  12  15  17  22  29  31  36  39
```

snapshot はまた[次回](/2017/05/building-ha-nfs-server-part2/)
