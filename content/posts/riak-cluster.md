---
title: 'Riak cluster を試してみる'
date: Mon, 28 Jan 2013 14:18:32 +0000
draft: false
tags: ['Riak']
---

前回 ([Installing Riak from source package](/2013/01/installing-riak-from-source-package/)) Riak を source からインストールして 3 node の cluster をセットアップしたので、これを使って cluster の操作をテストしてみる。
まず、cluster 操作は node 追加と削除などを同時に行えるように riak-admin で join や leave を実行した後に commit コマンドで反映させる仕様となっている。 **まずは、3台で cluster を組んでいる状態**

```
$ rel/riak1/bin/riak-admin member-status
================================= Membership ==================================
Status     Ring    Pending    Node
-------------------------------------------------------------------------------
valid      34.4%      --      'riak1@127.0.0.1'
valid      32.8%      --      'riak2@127.0.0.1'
valid      32.8%      --      'riak3@127.0.0.1'
-------------------------------------------------------------------------------
Valid:3 / Leaving:0 / Exiting:0 / Joining:0 / Down:0
```

**ここに node4 を追加してみる**

```
$ rel/riak4/bin/riak start

$ rel/riak4/bin/riak-admin cluster join riak1@127.0.0.1
Success: staged join request for 'riak4@127.0.0.1' to 'riak1@127.0.0.1'

$ rel/riak4/bin/riak-admin cluster plan
=============================== Staged Changes ================================
Action         Nodes(s)
-------------------------------------------------------------------------------
join           'riak4@127.0.0.1'
-------------------------------------------------------------------------------


NOTE: Applying these changes will result in 1 cluster transition

###############################################################################
                         After cluster transition 1/1
###############################################################################

================================= Membership ==================================
Status     Ring    Pending    Node
-------------------------------------------------------------------------------
valid      34.4%     25.0%    'riak1@127.0.0.1'
valid      32.8%     25.0%    'riak2@127.0.0.1'
valid      32.8%     25.0%    'riak3@127.0.0.1'
valid       0.0%     25.0%    'riak4@127.0.0.1'
-------------------------------------------------------------------------------
Valid:4 / Leaving:0 / Exiting:0 / Joining:0 / Down:0

Transfers resulting from cluster changes: 47
  5 transfers from 'riak2@127.0.0.1' to 'riak3@127.0.0.1'
  10 transfers from 'riak3@127.0.0.1' to 'riak1@127.0.0.1'
  16 transfers from 'riak2@127.0.0.1' to 'riak4@127.0.0.1'
  16 transfers from 'riak1@127.0.0.1' to 'riak2@127.0.0.1'

$ rel/riak4/bin/riak-admin cluster commit
Cluster changes committed
```

**追加されて、既存データのリバランスが行われる**

```
$ rel/riak4/bin/riak-admin member-status
================================= Membership ==================================
Status     Ring    Pending    Node
-------------------------------------------------------------------------------
valid      32.8%     25.0%    'riak1@127.0.0.1'
valid      34.4%     25.0%    'riak2@127.0.0.1'
valid      28.1%     25.0%    'riak3@127.0.0.1'
valid       4.7%     25.0%    'riak4@127.0.0.1'
-------------------------------------------------------------------------------
Valid:4 / Leaving:0 / Exiting:0 / Joining:0 / Down:0

$ rel/riak4/bin/riak-admin transfers
'riak4@127.0.0.1' waiting to handoff 59 partitions
'riak3@127.0.0.1' waiting to handoff 3 partitions
'riak2@127.0.0.1' waiting to handoff 8 partitions
'riak1@127.0.0.1' waiting to handoff 6 partitions

Active Transfers:

$ rel/riak4/bin/riak-admin member-status
================================= Membership ==================================
Status     Ring    Pending    Node
-------------------------------------------------------------------------------
valid      32.8%     25.0%    'riak1@127.0.0.1'
valid      32.8%     25.0%    'riak2@127.0.0.1'
valid      23.4%     25.0%    'riak3@127.0.0.1'
valid      10.9%     25.0%    'riak4@127.0.0.1'
-------------------------------------------------------------------------------
Valid:4 / Leaving:0 / Exiting:0 / Joining:0 / Down:0
```

**リバランス (handoff) 完了**

```
$ rel/riak4/bin/riak-admin member-status
================================= Membership ==================================
Status     Ring    Pending    Node
-------------------------------------------------------------------------------
valid      25.0%      --      'riak1@127.0.0.1'
valid      25.0%      --      'riak2@127.0.0.1'
valid      25.0%      --      'riak3@127.0.0.1'
valid      25.0%      --      'riak4@127.0.0.1'
-------------------------------------------------------------------------------
Valid:4 / Leaving:0 / Exiting:0 / Joining:0 / Down:0
```

**さらに追加して5 nodeにしてみる** (20% x5 とはならなかった)

```
$ rel/riak5/bin/riak-admin member-status
================================= Membership ==================================
Status     Ring    Pending    Node
-------------------------------------------------------------------------------
valid      18.8%      --      'riak1@127.0.0.1'
valid      18.8%      --      'riak2@127.0.0.1'
valid      18.8%      --      'riak3@127.0.0.1'
valid      25.0%      --      'riak4@127.0.0.1'
valid      18.8%      --      'riak5@127.0.0.1'
-------------------------------------------------------------------------------
Valid:5 / Leaving:0 / Exiting:0 / Joining:0 / Down:0
```

**そしてデータを足してみた**

```
$ du -sh rel/riak?/data/bitcask
129M	rel/riak1/data/bitcask
121M	rel/riak2/data/bitcask
126M	rel/riak3/data/bitcask
168M	rel/riak4/data/bitcask
131M	rel/riak5/data/bitcask
```

**node5 を SIGKILL で停止させてみる**

```
$ rel/riak1/bin/riak-admin ring-status
================================== Claimant ===================================
Claimant:  'riak2@127.0.0.1'
Status:     up
Ring Ready: true

============================== Ownership Handoff ==============================
No pending changes.

============================== Unreachable Nodes ==============================
The following nodes are unreachable: ['riak5@127.0.0.1']

WARNING: The cluster state will not converge until all nodes
are up. Once the above nodes come back online, convergence
will continue. If the outages are long-term or permanent, you
can either mark the nodes as down (riak-admin down NODE) or
forcibly remove the nodes from the cluster (riak-admin
force-remove NODE) to allow the remaining nodes to settle.
```

**この状態で先ほど登録したデータは全て無事に取得できました、 ではもう一台強制停止してみよう**

```
$ rel/riak1/bin/riak-admin ring-status
================================== Claimant ===================================
Claimant:  'riak2@127.0.0.1'
Status:     up
Ring Ready: true

============================== Ownership Handoff ==============================
No pending changes.

============================== Unreachable Nodes ==============================
The following nodes are unreachable: ['riak4@127.0.0.1','riak5@127.0.0.1']

WARNING: The cluster state will not converge until all nodes
are up. Once the above nodes come back online, convergence
will continue. If the outages are long-term or permanent, you
can either mark the nodes as down (riak-admin down NODE) or
forcibly remove the nodes from the cluster (riak-admin
force-remove NODE) to allow the remaining nodes to settle.
```

**2 node 止まってしまうと取得できなくなってしまったオブジェクトがでてきました**

でも bucket の設定で v\_val は 3 ですから 3 つのコピーがあるはずなので 2 台が停止してしまっても取得できることが期待されます。そこで r = quorum を r = 1 にしてしまいましょう。
r の default は quorum でこれは n\_val/2+1 です。n\_val の過半数が正常でないとオブジェクトが取得できません。([HTTP Bucket Properties](http://docs.basho.com/riak/1.3.0/references/apis/http/HTTP-Set-Bucket-Properties/))

```json
{
  props: {
    name: "test",
    allow_mult: false,
    basic_quorum: false,
    big_vclock: 50,
    chash_keyfun: {
      mod: "riak_core_util",
      fun: "chash_std_keyfun"
    },
    dw: "quorum",
    last_write_wins: false,
    linkfun: {
      mod: "riak_kv_wm_link_walker",
      fun: "mapreduce_linkfun"
    },
    n_val: 3,
    notfound_ok: true,
    old_vclock: 86400,
    postcommit: [ ],
    pr: 0,
    precommit: [ ],
    pw: 0,
    r: "quorum",
    rw: "quorum",
    small_vclock: 50,
    w: "quorum",
    young_vclock: 20
  }
}
```

```
$ curl -X PUT \
>  -H "Content-Type: application/json" \
>  -d '{"props":{ "r": 1}}' \
>  http://localhost:8298/buckets/test/props
```

無事に全てのオブジェクトを取得できました。やったね！ 死んでしまった node4, node5 をきちんと消してしまいましょう。

```
$ rel/riak1/bin/riak-admin cluster force-remove riak5@127.0.0.1
Success: staged remove request for 'riak5@127.0.0.1'

$ rel/riak1/bin/riak-admin cluster force-remove riak4@127.0.0.1
Success: staged remove request for 'riak4@127.0.0.1'

$ rel/riak1/bin/riak-admin cluster plan
Cannot plan until cluster state has converged.
Check 'Ring Ready' in 'riak-admin ring_status'
```

おっと、みんな集まらないと plan は実行できないよと。node4, node5 はもういないから集まれないんだよと教えてあげる必要があるみたいです。

```
$ rel/riak1/bin/riak-admin down riak5@127.0.0.1
Success: "riak5@127.0.0.1" marked as down

$ rel/riak1/bin/riak-admin down riak4@127.0.0.1
Success: "riak4@127.0.0.1" marked as down

$ rel/riak1/bin/riak-admin cluster plan
=============================== Staged Changes ================================
Action         Nodes(s)
-------------------------------------------------------------------------------
force-remove   'riak4@127.0.0.1'
force-remove   'riak5@127.0.0.1'
-------------------------------------------------------------------------------

WARNING: All of 'riak4@127.0.0.1' replicas will be lost
WARNING: All of 'riak5@127.0.0.1' replicas will be lost

NOTE: Applying these changes will result in 1 cluster transition

###############################################################################
                         After cluster transition 1/1
###############################################################################

================================= Membership ==================================
Status     Ring    Pending    Node
-------------------------------------------------------------------------------
valid      34.4%     34.4%    'riak1@127.0.0.1'
valid      32.8%     32.8%    'riak2@127.0.0.1'
valid      32.8%     32.8%    'riak3@127.0.0.1'
-------------------------------------------------------------------------------
Valid:3 / Leaving:0 / Exiting:0 / Joining:0 / Down:0

WARNING: Not all replicas will be on distinct nodes

Partitions reassigned from cluster changes: 28
  5 reassigned from 'riak4@127.0.0.1' to 'riak3@127.0.0.1'
  4 reassigned from 'riak5@127.0.0.1' to 'riak3@127.0.0.1'
  5 reassigned from 'riak4@127.0.0.1' to 'riak2@127.0.0.1'
  4 reassigned from 'riak5@127.0.0.1' to 'riak2@127.0.0.1'
  6 reassigned from 'riak4@127.0.0.1' to 'riak1@127.0.0.1'
  4 reassigned from 'riak5@127.0.0.1' to 'riak1@127.0.0.1'

Transfers resulting from cluster changes: 34
  4 transfers from 'riak1@127.0.0.1' to 'riak3@127.0.0.1'
  4 transfers from 'riak1@127.0.0.1' to 'riak2@127.0.0.1'
  3 transfers from 'riak3@127.0.0.1' to 'riak2@127.0.0.1'
  4 transfers from 'riak2@127.0.0.1' to 'riak1@127.0.0.1'
  4 transfers from 'riak5@127.0.0.1' to 'riak3@127.0.0.1'
  4 transfers from 'riak3@127.0.0.1' to 'riak1@127.0.0.1'
  3 transfers from 'riak2@127.0.0.1' to 'riak3@127.0.0.1'
  4 transfers from 'riak5@127.0.0.1' to 'riak2@127.0.0.1'
  4 transfers from 'riak5@127.0.0.1' to 'riak1@127.0.0.1'

$ rel/riak1/bin/riak-admin cluster commit
Cluster changes committed
```

```
$ rel/riak1/bin/riak-admin member-status
================================= Membership ==================================
Status     Ring    Pending    Node
-------------------------------------------------------------------------------
valid      31.3%     34.4%    'riak1@127.0.0.1'
valid      34.4%     32.8%    'riak2@127.0.0.1'
valid      34.4%     32.8%    'riak3@127.0.0.1'
-------------------------------------------------------------------------------
Valid:3 / Leaving:0 / Exiting:0 / Joining:0 / Down:0
```

**掃除終了**

```
$ rel/riak1/bin/riak-admin member-status
================================= Membership ==================================
Status     Ring    Pending    Node
-------------------------------------------------------------------------------
valid      34.4%      --      'riak1@127.0.0.1'
valid      32.8%      --      'riak2@127.0.0.1'
valid      32.8%      --      'riak3@127.0.0.1'
-------------------------------------------------------------------------------
Valid:3 / Leaving:0 / Exiting:0 / Joining:0 / Down:0
```

r を quorum に戻して全てのオブジェクトが取得できるかテスト

```
$ curl -X PUT \
>  -H "Content-Type: application/json" \
>  -d '{"props":{ "r": "quorum" }}' \
>  http://localhost:8298/buckets/test/props
```

無事全てのオブジェクトが取得できました。 node4, node5 としてはまだ cluster に参加しているつもりなので、再度起動してきたらどうなるのだろうか？と気になるところですが、きちんと起動時に確認して、もうメンバーでないことを認識して自ら自分の片付けをして shutdown します。

**では、最後に通常の node 削除を試してみる**

```
$ rel/riak1/bin/riak-admin cluster leave riak3@127.0.0.1
Success: staged leave request for 'riak3@127.0.0.1'

$ rel/riak1/bin/riak-admin cluster plan
=============================== Staged Changes ================================
Action         Nodes(s)
-------------------------------------------------------------------------------
leave          'riak3@127.0.0.1'
-------------------------------------------------------------------------------


NOTE: Applying these changes will result in 2 cluster transitions

###############################################################################
                         After cluster transition 1/2
###############################################################################

================================= Membership ==================================
Status     Ring    Pending    Node
-------------------------------------------------------------------------------
leaving    32.8%      0.0%    'riak3@127.0.0.1'
valid      34.4%     50.0%    'riak1@127.0.0.1'
valid      32.8%     50.0%    'riak2@127.0.0.1'
-------------------------------------------------------------------------------
Valid:2 / Leaving:1 / Exiting:0 / Joining:0 / Down:0

WARNING: Not all replicas will be on distinct nodes

Transfers resulting from cluster changes: 42
  10 transfers from 'riak3@127.0.0.1' to 'riak2@127.0.0.1'
  10 transfers from 'riak2@127.0.0.1' to 'riak1@127.0.0.1'
  11 transfers from 'riak1@127.0.0.1' to 'riak2@127.0.0.1'
  11 transfers from 'riak3@127.0.0.1' to 'riak1@127.0.0.1'

###############################################################################
                         After cluster transition 2/2
###############################################################################

================================= Membership ==================================
Status     Ring    Pending    Node
-------------------------------------------------------------------------------
valid      50.0%      --      'riak1@127.0.0.1'
valid      50.0%      --      'riak2@127.0.0.1'
-------------------------------------------------------------------------------
Valid:2 / Leaving:0 / Exiting:0 / Joining:0 / Down:0

WARNING: Not all replicas will be on distinct nodes

$ rel/riak1/bin/riak-admin cluster commit
Cluster changes committed
```

データは node1, node2 に寄せられています。node3 は leave コマンドで node1,2 に handoff することで空っぽになってます。

```
$ du -sh rel/riak?/data/bitcask
316M	rel/riak1/data/bitcask
279M	rel/riak2/data/bitcask
12K	rel/riak3/data/bitcask
198M	rel/riak4/data/bitcask
131M	rel/riak5/data/bitcask
```

ざっと簡単なパターンのクラスターオペレーションを試してみました。簡単ですね。 Riak CS でないと認証機能がないのがちょっとつらい。認証つけた Proxy を前に置くのかなぁ。 次回はもっと深いところを調べてみよう。
