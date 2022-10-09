---
title: 'Slony-I の調査'
date: Sun, 30 Dec 2018 14:58:20 +0000
draft: false
tags: ['PostgreSQL', 'slony']
---

[Slony-I 2.2.7 のドキュメント](http://www.slony.info/documentation/2.2/index.html)からの情報です

概要の確認とチュートリアルを試してみます。

Slony-I とは
----------

[Slony-I](http://www.slony.info/) は PostgreSQL のレプリケーションシステムで、複数レプリカの作成、カスケードレプリケーション、プロモーションをサポートしており、次の特徴を持つ

* 異なるメジャーバージョン間でもレプリケーション可能
* 異なるハードウェアアーキテクチャ、OSの間でもレプリケーション可能
* 一部のテーブルだけをレプリケーションすることが可能
* あるテーブルをレプリカ(A)に、別のテーブルをレプリカ(B)にレプリケーションといったことが可能
* テーブル毎にレプリカ元のデータベースサーバーが異なっていてもレプリケーション可能

PostgreSQL は version 10 から [logical replication](https://www.postgresql.jp/document/10/html/logical-replication.html) に対応し、今後のバージョンアップにはこれが使えますが、旧バージョンから 10 に上げるには当然ながら使えません(9.4 から [logical decoding](https://www.postgresql.org/docs/9.4/logicaldecoding.html) が使えるようになっているので追加の何かで logical replication できるような気もします)。ということで旧バージョンからの更新を短いダウンタイムで行うための手段として Slony-I は候補となります。

* [Slony-I (トリガーによる行単位レプリケーションツール) - SRA OSS, Inc. 日本支社](https://www.sraoss.co.jp/technology/postgresql/3rdparty/slony-I.php)
* [第3回「ロジカルレプリケーション」 | NTTデータ先端技術株式会社](http://www.intellilink.co.jp/article/column/oss-postgres03.html)

System Requirements
-------------------

* PostgreSQL 8.3 以降 (8.3.x, 8.4.x , 9.0.x, 9.1.x, 9.2.x, 9.3.x,9.4.x, 9.5.x での動作が確認されている)。これより前のバージョンでは Slony-I 1.2.x を使う必要がある。2.2.6 の release note に Support for PG10 とあるので 10.x にも対応しているはず

以降は推奨

* NTP などで時刻を同期すること、UTC や GMT といった安定したタイムゾーンを使うこと（夏時間のないタイムゾーン、PostgreSQL が認識できるタイムゾーンが好ましい）
* 信頼性の高いネットワーク（WAN 越しにレプリケーションする場合、それぞれの slon プロセスはそれぞれのローカルネットワーク内で実行するべし）
* データベースのエンコーディングは揃えるべし

Slony-I Concepts
----------------

セットアップするためには次の概念を理解する必要がある

* Cluster
* Node
* Replication Set
* Origin, Providers and Subscribers
* slon daemons
* slonik configuration processor

ロシア語の意味も理解しておくと良い

* **slon** は象 🐘
* **slony** は象の複数形 🐘🐘🐘
* **slonik** は小さな象

### Cluster

**Cluster** はレプリケーションを組む PostgreSQL インスタンスの集合で、各 Slonik スクリプトで次のように定義する

```
cluster name = something;
```

**Cluster** 名が `something` だった場合、それぞれのデータベースに `_something` という schema が作成される

### Node

レプリケーションを構成するうちのひとつひとつのデータベースを **Node** と呼び、各 Slonik スクリプトの冒頭で次のように定義される

```
NODE 1 ADMIN CONNINFO = 'dbname=testdb host=server1 user=slony';
```

この [ADMIN CONNINFO](http://www.slony.info/documentation/2.2/admconninfo.html) は libpq の PQconnectdb() 関数に渡される

### Replication Set

**Node** 間でレプリケーションされるテーブルとシーケンスのセット

### Origin, Providers and Subscribers

各 **Replication Set** には **Origin** node があり、それはアプリケーションによるレコードの変更が唯一許されている場所であり、Master **provider** とも呼ばれる。**Replication Set** の他の node は **Subscriber** となります。ただし、Slony-I はカスケードレプリケーションをサポートしているため、Subscriber が別の **Replication set** の **Origin** である可能性もあります

### slon daemons

**Cluster** 内の各 **Node** ではレプリケーションイベントを処理する [slon](http://www.slony.info/documentation/2.2/slon.html) プロセスが稼働している。C 言語で書かれており、処理する主な2つのイベントは次の通り

* **Configuration events**  
  Slonik スクリプトが実行された場合に発生し、クラスタ構成の変更が送られる
* **SYNC events**  
  レプリケーションされたテーブルへの変更が SYNC にまとめられて Subscriber に送られ、適用される

### slonik configuration processor

[Slonik](http://www.slony.info/documentation/2.2/slonik.html) コマンドは小さな言語となっているスクリプトを実行してクラスタの設定変更イベントを送る。このイベントには Node の追加や削除、通信 path の変更、Subscriber の追加、削除が含まれる

Current Limitations
-------------------

Slony-I は次の変更を自動でレプリケートしない

* Large objects (BLOBS)
* DDL
* Uses and Roles

Slony-I は trigger によって変更を捉えているため、これらの変更を捉えることができませんが、[SLONIK EXECUTE SCRIPT](http://www.slony.info/documentation/2.2/stmtddlscript.html) を使うことで DDL を各 Node で実行することができます

Tutorial
--------

### Replicating Your First Database

pgbench を使ってレプリケーション設定を試します。PostgreSQL 9.3 から PostgreSQL 9.6 に同期させてみます。CentOS 7 のサーバー2台 (pg1, pg2) に PGDG リポジトリから PostgreSQL と Slony-I をインストールします。簡略化のために `pg_hba.conf` の認証設定は `trust` で。

#### pg1

```bash
sudo yum -y install yum install https://download.postgresql.org/pub/repos/yum/9.3/redhat/rhel-7-x86_64/pgdg-centos93-9.3-3.noarch.rpm
sudo yum -y install perl
sudo yum -y install postgresql93 postgresql93-contrib slony1-93
sudo /usr/pgsql-9.3/bin/postgresql93-setup
sudo /usr/pgsql-9.3/bin/postgresql93-setup initdb
sudoedit /var/lib/pgsql/9.3/data/pg_hba.conf
sudo systemctl enable postgresql-9.3
sudo systemctl start postgresql-9.3
```

#### pg2

```bash
sudo yum -y install https://download.postgresql.org/pub/repos/yum/9.6/redhat/rhel-7-x86_64/pgdg-centos96-9.6-3.noarch.rpm
sudo yum -y install perl
sudo yum -y install postgresql96 postgresql96-contrib slony1-96
sudo /usr/pgsql-9.6/bin/postgresql96-setup initdb
sudoedit /var/lib/pgsql/9.6/data/pg_hba.conf
sudo systemctl enable postgresql-9.6
sudo systemctl start postgresql-9.6
```

今後の手順で使う環境変数を次のように設定します

```bash
export CLUSTERNAME=slony_example
export MASTERDBNAME=pgbench
export SLAVEDBNAME=pgbench
export MASTERHOST=pg1
export SLAVEHOST=pg2
export REPLICATIONUSER=postgres
export PGBENCHUSER=pgbench
```

### Creating the pgbench User

pgbench 用ユーザーの作成

```bash
sudo -iu postgres createuser -SRD $PGBENCHUSER
```

### Preparing the Databases

pgbench 用のデータベースを作成し、1度 pgbench を実行してテーブルを作成します

```bash
sudo -iu postgres createdb -O $PGBENCHUSER $MASTERDBNAME
/usr/pgsql-9.3/bin/pgbench -i -s 1 -U $PGBENCHUSER $MASTERDBNAME
```

```
pgbench=# \d+
                          List of relations
 Schema |       Name       | Type  |  Owner  |  Size   | Description
--------+------------------+-------+---------+---------+-------------
 public | pgbench_accounts | table | pgbench | 13 MB   |
 public | pgbench_branches | table | pgbench | 40 kB   |
 public | pgbench_history  | table | pgbench | 0 bytes |
 public | pgbench_tellers  | table | pgbench | 40 kB   |
(4 rows)
```

```
pgbench=# \d pgbench_accounts
   Table "public.pgbench_accounts"
  Column  |     Type      | Modifiers
----------+---------------+-----------
 aid      | integer       | not null
 bid      | integer       |
 abalance | integer       |
 filler   | character(84) |
Indexes:
    "pgbench_accounts_pkey" PRIMARY KEY, btree (aid)

pgbench=# \d pgbench_branches
   Table "public.pgbench_branches"
  Column  |     Type      | Modifiers
----------+---------------+-----------
 bid      | integer       | not null
 bbalance | integer       |
 filler   | character(88) |
Indexes:
    "pgbench_branches_pkey" PRIMARY KEY, btree (bid)

pgbench=# \d pgbench_tellers
    Table "public.pgbench_tellers"
  Column  |     Type      | Modifiers
----------+---------------+-----------
 tid      | integer       | not null
 bid      | integer       |
 tbalance | integer       |
 filler   | character(84) |
Indexes:
    "pgbench_tellers_pkey" PRIMARY KEY, btree (tid)

pgbench=#
```

`pgbench_history` テーブルには PRIMARY KEY が存在しないが、Slony は PRIMARY KEY またはそれ相当の INDEX を必要とするため PRIMARY KEY を追加する。

```
pgbench=# \d pgbench_history
          Table "public.pgbench_history"
 Column |            Type             | Modifiers
--------+-----------------------------+-----------
 tid    | integer                     |
 bid    | integer                     |
 aid    | integer                     |
 delta  | integer                     |
 mtime  | timestamp without time zone |
 filler | character(22)               |

pgbench=#
```

```bash
psql -U $PGBENCHUSER -d $MASTERDBNAME -c "ALTER TABLE pgbench_history ADD COLUMN id serial"
psql -U $PGBENCHUSER -d $MASTERDBNAME -c "ALTER TABLE pgbench_history ADD PRIMARY KEY(id)"
```

Slony は PL/PGSQL を使うので createlang で作成する

```bash
sudo -iu postgres createlang plpgsql $MASTERDBNAME
```

pg2 に DB を作成する

```bash
sudo -iu postgres createdb -O $PGBENCHUSER $SLAVEDBNAME
```

pg1 から pg2 へスキーマをコピーする

```bash
pg_dump -s -U $REPLICATIONUSER -h $MASTERHOST $MASTERDBNAME \
  | psql -U $REPLICATIONUSER -h $SLAVEHOST $SLAVEDBNAME
```

### Configuring the Database For Replication

設定テーブル、ストアド・プロシージャ、トリガーの作成と設定はすべて [slonik](http://www.slony.info/documentation/2.2/slonik.html) コマンドをを使って行います

#### Using slonik Command Directly

slonik コマンドへの入力を自分で用意する方法です。簡略化およびミスを減らすために後述の別のツールを使う方法もあります

```bash
sudo /usr/pgsql-9.3/bin/slonik <<_EOF_
	#--
	# レプリケーションシステムのネームスペースを定義する
	# この例では slony_example とする
	#--
	cluster name = $CLUSTERNAME;

	#--
	# admin conninfo で slonik が DB にログインするための情報を定義する
	# 構文は C-API の PQconnectdb に渡すもの
	# --
	node 1 admin conninfo = 'dbname=$MASTERDBNAME host=$MASTERHOST user=$REPLICATIONUSER';
	node 2 admin conninfo = 'dbname=$SLAVEDBNAME host=$SLAVEHOST user=$REPLICATIONUSER';

	#--
	# 最初のノードを初期化する
	# これは _$CLUSTERNAME スキーマを作成する
	#--
	init cluster ( id=1, comment = 'Master Node');
 
	#--
	# Slony-I はレプリケーションテーブルを set として定義する
	# 次のコマンドは 4 つの pgbench 用テーブルを set (id = 1) としている
	# master (origin) は node 1
	#--
	create set (id=1, origin=1, comment='All pgbench tables');
	set add table (set id=1, origin=1, id=1, fully qualified name = 'public.pgbench_accounts', comment='accounts table');
	set add table (set id=1, origin=1, id=2, fully qualified name = 'public.pgbench_branches', comment='branches table');
	set add table (set id=1, origin=1, id=3, fully qualified name = 'public.pgbench_tellers', comment='tellers table');
	set add table (set id=1, origin=1, id=4, fully qualified name = 'public.pgbench_history', comment='history table');

	#--
	# 2 番目の node (id = 2) を定義して node 間で接続するための情報 (path) を定義する
	#--
	store node (id=2, comment = 'Slave node', event node=1);
	store path (server = 1, client = 2, conninfo='dbname=$MASTERDBNAME host=$MASTERHOST user=$REPLICATIONUSER');
	store path (server = 2, client = 1, conninfo='dbname=$SLAVEDBNAME host=$SLAVEHOST user=$REPLICATIONUSER');
_EOF_
```

これを実行すると pg1, pg2 の pgbench データベースの `_slony_example` スキーマに沢山の slony 用テーブルが作成され、レプリケーション対象テーブルに `trigger` が作成されています。

```
pgbench=# set search_path to public,_slony_example;
SET
pgbench=# \d
                         List of relations
     Schema     |            Name            |   Type   |  Owner
----------------+----------------------------+----------+----------
 _slony_example | sl_action_seq              | sequence | postgres
 _slony_example | sl_apply_stats             | table    | postgres
 _slony_example | sl_archive_counter         | table    | postgres
 _slony_example | sl_components              | table    | postgres
 _slony_example | sl_config_lock             | table    | postgres
 _slony_example | sl_confirm                 | table    | postgres
 _slony_example | sl_event                   | table    | postgres
 _slony_example | sl_event_lock              | table    | postgres
 _slony_example | sl_event_seq               | sequence | postgres
 _slony_example | sl_failover_targets        | view     | postgres
 _slony_example | sl_listen                  | table    | postgres
 _slony_example | sl_local_node_id           | sequence | postgres
 _slony_example | sl_log_1                   | table    | postgres
 _slony_example | sl_log_2                   | table    | postgres
 _slony_example | sl_log_script              | table    | postgres
 _slony_example | sl_log_status              | sequence | postgres
 _slony_example | sl_node                    | table    | postgres
 _slony_example | sl_nodelock                | table    | postgres
 _slony_example | sl_nodelock_nl_conncnt_seq | sequence | postgres
 _slony_example | sl_path                    | table    | postgres
 _slony_example | sl_registry                | table    | postgres
 _slony_example | sl_seqlastvalue            | view     | postgres
 _slony_example | sl_seqlog                  | table    | postgres
 _slony_example | sl_sequence                | table    | postgres
 _slony_example | sl_set                     | table    | postgres
 _slony_example | sl_setsync                 | table    | postgres
 _slony_example | sl_status                  | view     | postgres
 _slony_example | sl_subscribe               | table    | postgres
 _slony_example | sl_table                   | table    | postgres
 public         | pgbench_accounts           | table    | pgbench
 public         | pgbench_branches           | table    | pgbench
 public         | pgbench_history            | table    | pgbench
 public         | pgbench_history_id_seq     | sequence | pgbench
 public         | pgbench_tellers            | table    | pgbench
(34 rows)
```

```
pgbench=# \d pgbench_accounts
   Table "public.pgbench_accounts"
  Column  |     Type      | Modifiers
----------+---------------+-----------
 aid      | integer       | not null
 bid      | integer       |
 abalance | integer       |
 filler   | character(84) |
Indexes:
    "pgbench_accounts_pkey" PRIMARY KEY, btree (aid)
Triggers:
    _slony_example_logtrigger AFTER INSERT OR DELETE OR UPDATE ON pgbench_accounts FOR EACH ROW EXECUTE PROCEDURE _slony_example.logtrigger('_slony_example', '1', 'k')
    _slony_example_truncatetrigger BEFORE TRUNCATE ON pgbench_accounts FOR EACH STATEMENT EXECUTE PROCEDURE _slony_example.log_truncate('1')
Disabled triggers:
    _slony_example_denyaccess BEFORE INSERT OR DELETE OR UPDATE ON pgbench_accounts FOR EACH ROW EXECUTE PROCEDURE _slony_example.denyaccess('_slony_example')
    _slony_example_truncatedeny BEFORE TRUNCATE ON pgbench_accounts FOR EACH STATEMENT EXECUTE PROCEDURE _slony_example.deny_truncate()

pgbench=# \d pgbench_branches
   Table "public.pgbench_branches"
  Column  |     Type      | Modifiers
----------+---------------+-----------
 bid      | integer       | not null
 bbalance | integer       |
 filler   | character(88) |
Indexes:
    "pgbench_branches_pkey" PRIMARY KEY, btree (bid)
Triggers:
    _slony_example_logtrigger AFTER INSERT OR DELETE OR UPDATE ON pgbench_branches FOR EACH ROW EXECUTE PROCEDURE _slony_example.logtrigger('_slony_example', '2', 'k')
    _slony_example_truncatetrigger BEFORE TRUNCATE ON pgbench_branches FOR EACH STATEMENT EXECUTE PROCEDURE _slony_example.log_truncate('2')
Disabled triggers:
    _slony_example_denyaccess BEFORE INSERT OR DELETE OR UPDATE ON pgbench_branches FOR EACH ROW EXECUTE PROCEDURE _slony_example.denyaccess('_slony_example')
    _slony_example_truncatedeny BEFORE TRUNCATE ON pgbench_branches FOR EACH STATEMENT EXECUTE PROCEDURE _slony_example.deny_truncate()

pgbench=# \d pgbench_history
                                   Table "public.pgbench_history"
 Column |            Type             |                          Modifiers
--------+-----------------------------+--------------------------------------------------------------
 tid    | integer                     |
 bid    | integer                     |
 aid    | integer                     |
 delta  | integer                     |
 mtime  | timestamp without time zone |
 filler | character(22)               |
 id     | integer                     | not null default nextval('pgbench_history_id_seq'::regclass)
Indexes:
    "pgbench_history_pkey" PRIMARY KEY, btree (id)
Triggers:
    _slony_example_logtrigger AFTER INSERT OR DELETE OR UPDATE ON pgbench_history FOR EACH ROW EXECUTE PROCEDURE _slony_example.logtrigger('_slony_example', '4', 'vvvvvvk')
    _slony_example_truncatetrigger BEFORE TRUNCATE ON pgbench_history FOR EACH STATEMENT EXECUTE PROCEDURE _slony_example.log_truncate('4')
Disabled triggers:
    _slony_example_denyaccess BEFORE INSERT OR DELETE OR UPDATE ON pgbench_history FOR EACH ROW EXECUTE PROCEDURE _slony_example.denyaccess('_slony_example')
    _slony_example_truncatedeny BEFORE TRUNCATE ON pgbench_history FOR EACH STATEMENT EXECUTE PROCEDURE _slony_example.deny_truncate()

pgbench=# \d pgbench_tellers
    Table "public.pgbench_tellers"
  Column  |     Type      | Modifiers
----------+---------------+-----------
 tid      | integer       | not null
 bid      | integer       |
 tbalance | integer       |
 filler   | character(84) |
Indexes:
    "pgbench_tellers_pkey" PRIMARY KEY, btree (tid)
Triggers:
    _slony_example_logtrigger AFTER INSERT OR DELETE OR UPDATE ON pgbench_tellers FOR EACH ROW EXECUTE PROCEDURE _slony_example.logtrigger('_slony_example', '3', 'k')
    _slony_example_truncatetrigger BEFORE TRUNCATE ON pgbench_tellers FOR EACH STATEMENT EXECUTE PROCEDURE _slony_example.log_truncate('3')
Disabled triggers:
    _slony_example_denyaccess BEFORE INSERT OR DELETE OR UPDATE ON pgbench_tellers FOR EACH ROW EXECUTE PROCEDURE _slony_example.denyaccess('_slony_example')
    _slony_example_truncatedeny BEFORE TRUNCATE ON pgbench_tellers FOR EACH STATEMENT EXECUTE PROCEDURE _slony_example.deny_truncate()

pgbench=#
```

pg1 (origin) で slon を起動

```bash
/usr/pgsql-9.3/bin/slon $CLUSTERNAME "dbname=$MASTERDBNAME user=$REPLICATIONUSER host=$MASTERHOST"
```

pg2 (subscriber) で slon を起動

```bash
/usr/pgsql-9.6/bin/slon $CLUSTERNAME "dbname=$SLAVEDBNAME user=$REPLICATIONUSER host=$SLAVEHOST"
```

pg2 で `pg_stat_activity` を見ると次のようなプロセスからの接続がありました

```
slon.local_cleanup
slon.local_listen
slon.local_monitor
slon.local_sync
slon.node_2_listen
slon.origin_2_provider_2
slon.remoteWorkerThread_1
```

slon プロセスがなにやら SYNC してそうな出力をしますが、ここまでではまだ同期が始まっていません

ここで再度 pgbench を実行してみます。今度は `-T 300` で5分間実行されるようにしています。これの実行中に次の subscribe 設定を行うことで、更新中の同期開始を試みます

```bash
/usr/pgsql-9.3/bin/pgbench -s 1 -c 5 -T 300 -U $PGBENCHUSER -h $MASTERHOST $MASTERDBNAME
```

次のようにして slonik で [subscribe](http://www.slony.info/documentation/2.2/stmtsubscribeset.html) 指示を出します

```bash
sudo /usr/pgsql-9.3/bin/slonik <<_EOF_
	 # ----
	 # This defines which namespace the replication system uses
	 # ----
	 cluster name = $CLUSTERNAME;

	 # ----
	 # 各 node への接続情報
	 # ----
	 node 1 admin conninfo = 'dbname=$MASTERDBNAME host=$MASTERHOST user=$REPLICATIONUSER';
	 node 2 admin conninfo = 'dbname=$SLAVEDBNAME host=$SLAVEHOST user=$REPLICATIONUSER';

	 # ----
	 # Node 2 subscribes set 1
	 # Subscriber が cascade や failover で provider になるのであれば forward は yes とします
	 # ----
	 subscribe set ( id = 1, provider = 1, receiver = 2, forward = no);
_EOF_
```

これによって origin テーブルのレコードをコピーし、完了後、コピー開始時からの変更を反映していきます

#### Using the altperl Scripts

`cluster name` や `admin conninfo` など slonik のへの入力を毎度生成するのは大変なので `/etc/slony1-93/slon_tools.conf` の設定を元に生成してくれるツールがあります。 次のようにして pipe で slonik に渡すことで初期化や起動、Subscribe などの指示を出せます。

```
# Initialize cluster:
$ slonik_init_cluster  | slonik 

# Start slon  (here 1 and 2 are node numbers)
$ slon_start 1    
$ slon_start 2

# Create Sets (here 1 is a set number)
$ slonik_create_set 1 | slonik             

# subscribe set to second node (1= set ID, 2= node ID)
$ slonik_subscribe_set 1 2 | slonik
```

### テーブル / レコードの比較

正しく同期できているかどうか、次のスクリプトで確認することができます。`order by` つきでそれぞれのデータベースからレコードを取得して diff で比較しています

```bash
#!/bin/sh
echo -n "**** comparing sample1 ... "
psql -U $REPLICATIONUSER -h $MASTERHOST $MASTERDBNAME >dump.tmp.1.$$ <<_EOF_
         select 'accounts:'::text, aid, bid, abalance, filler
                  from pgbench_accounts order by aid;
         select 'branches:'::text, bid, bbalance, filler
                  from pgbench_branches order by bid;
         select 'tellers:'::text, tid, bid, tbalance, filler
                  from pgbench_tellers order by tid;
         select 'history:'::text, tid, bid, aid, delta, mtime, filler, id
                  from pgbench_history order by id;
_EOF_
psql -U $REPLICATIONUSER -h $SLAVEHOST $SLAVEDBNAME >dump.tmp.2.$$ <<_EOF_
         select 'accounts:'::text, aid, bid, abalance, filler
                  from pgbench_accounts order by aid;
         select 'branches:'::text, bid, bbalance, filler
                  from pgbench_branches order by bid;
         select 'tellers:'::text, tid, bid, tbalance, filler
                  from pgbench_tellers order by tid;
         select 'history:'::text, tid, bid, aid, delta, mtime, filler, id
                  from pgbench_history order by id;
_EOF_

if diff dump.tmp.1.$$ dump.tmp.2.$$ >$CLUSTERNAME.diff ; then
         echo "success - databases are equal."
         rm dump.tmp.?.$$
         rm $CLUSTERNAME.diff
else
         echo "FAILED - see $CLUSTERNAME.diff for database differences"
fi
```

Conclusion
----------

リアルワールドでは pgbench の用な単純な構成ではないため、実際にこれを使ってデータベースのアップグレードを行うにはより詳しく調査する必要がありますが、なんとなく概要がわかりました
