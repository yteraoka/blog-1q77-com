---
title: 'WAL-G で PostgreSQL の Backup や Replica 作成'
date: Sat, 22 Jun 2019 12:35:15 +0000
draft: false
tags: ['PostgreSQL']
---

以前、WAL-E について書きました「[WAL-E で PostgreSQL の Backup / Restore](/2016/09/postgressql-backup-and-restore-using-wal-e/)」。今回はその後継っぽい [WAL-G](https://github.com/wal-g/wal-g) を試してみます。WAL-E の4倍速いとのこと ([Introducing WAL-G by Citus: Faster Disaster Recovery for Postgres](https://www.citusdata.com/blog/2017/08/18/introducing-wal-g-faster-restores-for-postgres/))。その後、2019-04-22 に 0.2 (0.2.9) がリリースされてより便利になっているようです ([WAL-G v0.2 released](https://www.postgresql.org/message-id/EC878C0E-38CA-4B35-A163-9C39D4F5E434%40yandex-team.ru))。WAL-G はGo言語で書かれているためインストールが楽ですね。

WAL-G の特徴
---------

### 圧縮

WAL-E は圧縮に LZO が使われていましたが、WAL-G では LZ4, LZMA, Brotli から選択可能になっています。Brotli が圧縮率と速度のバランスが良く、LZMA は遅すぎとのこと。

### 対応ストレージ

WAL-E と同様に多くのオブジェクトストレージに対応しています

*   S3 (SSE にも対応) とその互換
*   Azure Storage
*   Google Cloud Storage
*   Swift
*   Local Filesystem

### 帯域制限

Backup 時のDBファイルの読み出しレート、オブジェクトストレージへの転送レート、ダウンロードの並列度などを制御することが可能です。

### Delta Backup

WAL-delta backups (a.k.a. fast block-level incremental backup). This feature enables scanning of WAL during archivation, the gathered information is used to make delta backup much faster.

1つの Full Backup に対していくつの Delta Backup を持たせるかという環境変数 `WALG_DELTA_MAX_STEPS` をデフォルトの 0 から 1 以上に増やすと機能するようです。

### 暗号化

S3 の SSE (KMS 対応) も使えるが、GPG で暗号化して保存することも可能で、外部の gpg コマンドも必要ない。

試してみる
-----

### サーバー環境

2台の CentOS 7 サーバーにそれぞれ PostgreSQL 11 をインストールし、Warm スタンバイ構成とする。 スタンバイ(レプリカ)側で [Minio](https://min.io/) サーバーを起動させて WAL-G のファイル保存先とする。

### PostgreSQL のインストール

PGDG のリポジトリから PostgreSQL 11 をインストールする

```
$ sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
$ sudo yum install -y postgresql11-server
```

### wal-g コマンドのインストール

```
$ curl -LO https://github.com/wal-g/wal-g/releases/download/v0.2.9/wal-g.linux-amd64.tar.gz
$ sudo tar -C /usr/local/bin -xvf wal-g.linux-amd64.tar.gz
$ sudo chmod +x /usr/local/bin/wal-g

```

### Minio server のダウンロードと起動

レプリカ側のサーバーで起動させます

```
$ curl -LO https://dl.min.io/server/minio/release/linux-amd64/minio
$ chmod +x minio
$ mkdir data
$ ./minio server data &

```

minio を起動させると AccessKey と SecretKey が表示されます。(data/.minio.sys/config/config.json にも保存されてます)

### Minio client のダウンロードと設定

```
$ sudo curl -Lo /usr/local/bin/mc https://dl.min.io/client/mc/release/linux-amd64/mc
$ sudo chmod +x /usr/local/bin/mc

```

#### 認証設定

Bucket 作成や bucket 内のオブジェクト確認のために使います

```
$ mc config host add local http://localhost:9000 NRZJHAVRWVWPN8X8SYGZ iwJLitwBL32iO1lWD7FtfegZ2P6XBPf601x5s67H

```

#### WAL-G 用 Bucket 作成

```
$ mc mb local/wal-g
Bucket created successfully `local/wal-g`.
$ mc ls local/
[2019-06-22 06:55:50 UTC]      0B wal-g/
```

### PostgreSQL の initdb と起動

```
$ sudo PGSETUP_INITDB_OPTIONS="-E utf8 --no-locale --data-checksums" \
/usr/pgsql-11/bin/postgresql-11-setup initdb
$ sudo systemctl start postgresql-11
```

### pgbench を実行してみる

特に意味はないけど DB のデータ更新ツールとして

```
$ sudo -iu postgres createdb pgbench
$ sudo -iu postgres /usr/pgsql-11/bin/pgbench -i pgbench
dropping old tables...
NOTICE:  table "pgbench_accounts" does not exist, skipping
NOTICE:  table "pgbench_branches" does not exist, skipping
NOTICE:  table "pgbench_history" does not exist, skipping
NOTICE:  table "pgbench_tellers" does not exist, skipping
creating tables...
generating data...
100000 of 100000 tuples (100%) done (elapsed 0.16 s, remaining 0.00 s)
vacuuming...
creating primary keys...
done.
```

### Local Filesystem へ WAL-G でバックアップしてみる

バックアップ先ディレクトリを作成

```
$ sudo install -o postgres -g postgres -m 0700 -d /backup
```

バックアップの一覧確認コマンドを実行してみる。まだバックアップしてないので "No backups found"

```
$ sudo -iu postgres WALE_FILE_PREFIX=/backup /usr/local/bin/wal-g backup-list
ERROR: 2019/06/22 07:08:35.529498 No backups found
```

`wal-g backup-push` でフルバックアップを取得。ここでは Unix Domain Socket で通信するために PGHOST に socket ファイルのパスを指定している

```
$ sudo -iu postgres PGHOST=/tmp/.s.PGSQL.5432 WALE_FILE_PREFIX=/backup /usr/local/bin/wal-g backup-push /var/lib/pgsql/11/data
INFO: 2019/06/22 07:14:45.762189 Doing full backup.
INFO: 2019/06/22 07:14:45.877402 Walking ...
INFO: 2019/06/22 07:14:45.877928 Starting part 1 ...
INFO: 2019/06/22 07:14:46.183716 Finished writing part 1.
INFO: 2019/06/22 07:14:46.183757 Starting part 2 ...
INFO: 2019/06/22 07:14:46.183768 /global/pg_control
INFO: 2019/06/22 07:14:46.185711 Finished writing part 2.
INFO: 2019/06/22 07:14:47.218344 Starting part 3 ...
INFO: 2019/06/22 07:14:47.221441 backup_label
INFO: 2019/06/22 07:14:47.221920 tablespace_map
INFO: 2019/06/22 07:14:47.222044 Finished writing part 3.
```

PostgreSQL のログから次のクエリが実行されたことがわかります。`pg_start_backup()` や `pg_stop_backup()` が実行されています。

```
2019-06-22 07:14:45.772 UTC [12227] LOG:  execute <unnamed>: select t.oid,
                case when nsp.nspname in ('pg_catalog', 'public') then t.typname
                        else nsp.nspname||'.'||t.typname
                end
        from pg_type t
        left join pg_type base_type on t.typelem=base_type.oid
        left join pg_namespace nsp on t.typnamespace=nsp.oid
        where (
                  t.typtype in('b', 'p', 'r', 'e')
                  and (base_type.oid is null or base_type.typtype in('b', 'p', 'r'))
                )
2019-06-22 07:14:45.773 UTC [12227] LOG:  execute <unnamed>: select t.oid, t.typname
        from pg_type t
          join pg_type base_type on t.typelem=base_type.oid
        where t.typtype = 'b'
          and base_type.typtype = 'e'
2019-06-22 07:14:45.774 UTC [12227] LOG:  execute <unnamed>: select t.oid, t.typname, t.typbasetype
        from pg_type t
          join pg_type base_type on t.typbasetype=base_type.oid
        where t.typtype = 'd'
          and base_type.typtype = 'b'
2019-06-22 07:14:45.774 UTC [12227] LOG:  execute <unnamed>: show archive_mode
2019-06-22 07:14:45.774 UTC [12227] LOG:  execute <unnamed>: show archive_command
2019-06-22 07:14:45.774 UTC [12227] LOG:  execute <unnamed>: select (current_setting('server_version_num'))::int
2019-06-22 07:14:45.775 UTC [12227] LOG:  execute <unnamed>: SELECT case when pg_is_in_recovery() then '' else (pg_walfile_name_offset(lsn)).file_name end, lsn::text, pg_is_in_recovery() FROM pg_start_backup($1, true, false) lsn
2019-06-22 07:14:45.775 UTC [12227] DETAIL:  parameters: $1 = '2019-06-22 07:14:45.77465243 +0000 UTC m=+0.018118250'
2019-06-22 07:14:45.876 UTC [12227] LOG:  execute <unnamed>: select timeline_id, bytes_per_wal_segment from pg_control_checkpoint(), pg_control_init()
2019-06-22 07:14:46.187 UTC [12227] LOG:  execute <unnamed>: select (current_setting('server_version_num'))::int
2019-06-22 07:14:46.187 UTC [12227] LOG:  statement: begin
2019-06-22 07:14:46.187 UTC [12227] LOG:  statement: SET statement_timeout=0;
2019-06-22 07:14:46.187 UTC [12227] LOG:  execute <unnamed>: SELECT labelfile, spcmapfile, lsn FROM pg_stop_backup(false)
2019-06-22 07:14:47.217 UTC [12227] LOG:  statement: commit
```

`wal-g backup-list` でバックアップの一覧を確認

```
$ sudo -iu postgres WALE_FILE_PREFIX=/backup /usr/local/bin/wal-g backup-list
name                          last_modified        wal_segment_backup_start
base_000000010000000000000006 2019-06-22T07:14:47Z 000000010000000000000006
```

バックアップ先ディレクトリには次のようなファイルができていました

```
$ sudo find /backup -type f
/backup/basebackups_005/base_000000010000000000000006/tar_partitions/part_001.tar.lz4
/backup/basebackups_005/base_000000010000000000000006/tar_partitions/pg_control.tar.lz4
/backup/basebackups_005/base_000000010000000000000006/tar_partitions/part_003.tar.lz4
/backup/basebackups_005/base_000000010000000000000006_backup_stop_sentinel.json
```

lz4 で圧縮された tar ファイルは次のようにしてファイルのリストを確認できます (gz, bz2, xz なんかは GNU Tar は自分で判断して処理してくれますけど lz4 には対応してないみたい)

```
sudo lz4cat /backup/basebackups_005/base_000000010000000000000006/tar_partitions/part_001.tar.lz4 | tar tf -
```

### WAL を minio にアーカイブする

wal-g を環境変数して実行するために wrapper を作ります

```
$ cat | sudo tee /usr/local/bin/wal-g.sh <<'EOF'
#!/bin/bash

export AWS_ACCESS_KEY_ID="NRZJHAVRWVWPN8X8SYGZ"
export AWS_SECRET_ACCESS_KEY="iwJLitwBL32iO1lWD7FtfegZ2P6XBPf601x5s67H"
export WALE_S3_PREFIX="s3://wal-g"
export AWS_ENDPOINT="http://10.130.59.155:9000"
export AWS_S3_FORCE_PATH_STYLE="true"
export AWS_REGION="us-east-1"

exec /usr/local/bin/wal-g "$@"
EOF
$ sudo chmod +x /usr/local/bin/wal-g.sh
```

```
archive_mode = on
archive_command = '/usr/local/bin/wal-g.sh wal-push "%p"'
archive_timeout = 30
```

PostgreSQL のログに次のように出ました

```
INFO: 2019/06/22 07:46:02.628958 FILE PATH: 000000010000000000000009.lz4

```

minio 側でもファイルが確認できました

```
$ mc ls local/wal-g
[2019-06-22 07:46:11 UTC]      0B wal_005/
$ mc ls local/wal-g/wal_005/
[2019-06-22 07:46:02 UTC]   65KiB 000000010000000000000009.lz4
```

次に、この状態で replica を作ります。近くにあるサーバー同士であれば pg\_basebackup でデータをコピーすれば良いのですがここではあえて WAL-G の `backup-push` と `backup-fetch` を使っている。オンプレにある DB のレプリカをクラウドに作るのに使えるのではないかと

1.  (master) replication のための設定 streaming replication しない場合は不要だった
2.  (master) WAL-G の `backup-push` で minio に backup を保存
3.  (replica) WAL-G の `backup-fetch` で /var/lib/pgsql/11/data にリストア
4.  (replica) recovery.conf を設定して起動 (restore\_command に wal-g wal-fetch を設定)

#### バックアップを minio に保存

```
$ sudo -iu postgres PGHOST=/tmp/.s.PGSQL.5432 /usr/local/bin/wal-g.sh backup-push /var/lib/pgsql/11/data
INFO: 2019/06/22 08:00:49.706362 Doing full backup.
INFO: 2019/06/22 08:00:49.858714 Walking ...
INFO: 2019/06/22 08:00:49.859470 Starting part 1 ...
INFO: 2019/06/22 08:00:50.130802 Finished writing part 1.
INFO: 2019/06/22 08:00:50.375493 Starting part 2 ...
INFO: 2019/06/22 08:00:50.375529 /global/pg_control
INFO: 2019/06/22 08:00:50.407612 Finished writing part 2.
INFO: 2019/06/22 08:00:51.437201 Starting part 3 ...
INFO: 2019/06/22 08:00:51.452981 backup_label
INFO: 2019/06/22 08:00:51.453106 tablespace_map
INFO: 2019/06/22 08:00:51.453188 Finished writing part 3.
```

minio の bucket 内を確認

```
$ mc ls local/wal-g
[2019-06-22 08:00:57 UTC]      0B basebackups_005/
[2019-06-22 08:00:57 UTC]      0B wal_005/
$ mc ls local/wal-g/basebackups_005/
[2019-06-22 08:00:51 UTC]  126KiB base_00000001000000000000000C_backup_stop_sentinel.json
[2019-06-22 08:01:06 UTC]      0B base_00000001000000000000000C/
$ mc ls local/wal-g/basebackups_005/base_00000001000000000000000C/
[2019-06-22 08:01:14 UTC]      0B tar_partitions/
$ mc ls local/wal-g/basebackups_005/base_00000001000000000000000C/tar_partitions/
[2019-06-22 08:00:50 UTC]   11MiB part_001.tar.lz4
[2019-06-22 08:00:51 UTC]    536B part_003.tar.lz4
[2019-06-22 08:00:50 UTC]    488B pg_control.tar.lz4
```

#### minio からバックアップを取り出す

`LATEST` と指定すれば最新のバックアップが取り出せる

```
$ sudo -iu postgres /usr/local/bin/wal-g.sh backup-fetch /var/lib/pgsql/11/data LATEST
INFO: 2019/06/22 08:07:16.142053 LATEST backup is: 'base_00000001000000000000000C'
INFO: 2019/06/22 08:07:16.290391 Finished decompression of part_003.tar.lz4
INFO: 2019/06/22 08:07:16.290412 Finished extraction of part_003.tar.lz4
INFO: 2019/06/22 08:07:19.771957 Finished decompression of part_001.tar.lz4
INFO: 2019/06/22 08:07:19.772172 Finished extraction of part_001.tar.lz4
INFO: 2019/06/22 08:07:19.785737 Finished decompression of pg_control.tar.lz4
INFO: 2019/06/22 08:07:19.785761 Finished extraction of pg_control.tar.lz4
INFO: 2019/06/22 08:07:19.785770
Backup extraction complete.
```

指定した `/var/lib/pgsql/11/data` に展開された

```
$ sudo ls -l /var/lib/pgsql/11/data
total 56
-rw-------. 1 postgres postgres   253 Jun 22 08:07 backup_label
drwx------. 7 postgres postgres    71 Jun 22 08:07 base
-rw-------. 1 postgres postgres    30 Jun 22 08:07 current_logfiles
drwx------. 2 postgres postgres  4096 Jun 22 08:07 global
drwx------. 2 postgres postgres    32 Jun 22 08:07 log
drwx------. 2 postgres postgres     6 Jun 22 08:07 pg_commit_ts
drwx------. 2 postgres postgres     6 Jun 22 08:07 pg_dynshmem
-rw-------. 1 postgres postgres  4269 Jun 22 08:07 pg_hba.conf
-rw-------. 1 postgres postgres  1636 Jun 22 08:07 pg_ident.conf
drwx------. 4 postgres postgres    68 Jun 22 08:07 pg_logical
drwx------. 4 postgres postgres    36 Jun 22 08:07 pg_multixact
drwx------. 2 postgres postgres     6 Jun 22 08:07 pg_notify
drwx------. 2 postgres postgres     6 Jun 22 08:07 pg_replslot
drwx------. 2 postgres postgres     6 Jun 22 08:07 pg_serial
drwx------. 2 postgres postgres     6 Jun 22 08:07 pg_snapshots
drwx------. 2 postgres postgres     6 Jun 22 08:07 pg_stat
drwx------. 2 postgres postgres     6 Jun 22 08:07 pg_stat_tmp
drwx------. 2 postgres postgres     6 Jun 22 08:07 pg_subtrans
drwx------. 2 postgres postgres     6 Jun 22 08:07 pg_tblspc
drwx------. 2 postgres postgres     6 Jun 22 08:07 pg_twophase
-rw-------. 1 postgres postgres     3 Jun 22 08:07 PG_VERSION
drwx------. 2 postgres postgres     6 Jun 22 08:07 pg_wal
drwx------. 2 postgres postgres    18 Jun 22 08:07 pg_xact
-rw-------. 1 postgres postgres    88 Jun 22 08:07 postgresql.auto.conf
-rw-------. 1 postgres postgres 23854 Jun 22 08:07 postgresql.conf
-rw-------. 1 postgres postgres     0 Jun 22 08:07 tablespace_map
$
```

#### recovery.conf を作成して PostgreSQL を起動

```
$ cat | sudo -u postgres tee /var/lib/pgsql/11/data/recovery.conf <<'EOF'
standby_mode = on
restore_command = '/usr/local/bin/wal-g.sh wal-fetch "%f" "%p"'
EOF
$ sudo systemctl start postgresql-11
```

ps コマンドで確認。WAL 待ちになっていることがわかる

```
$ ps -ef | grep postg
postgres 11821     1  0 08:21 ?        00:00:00 /usr/pgsql-11/bin/postmaster -D /var/lib/pgsql/11/data/
postgres 11823 11821  0 08:21 ?        00:00:00 postgres: logger
postgres 11824 11821  0 08:21 ?        00:00:00 postgres: startup   waiting for 00000001000000000000000E
postgres 11835 11821  0 08:21 ?        00:00:00 postgres: checkpointer
postgres 11836 11821  0 08:21 ?        00:00:00 postgres: background writer
postgres 11838 11821  0 08:21 ?        00:00:00 postgres: stats collector
centos   11865 11243  0 08:21 pts/0    00:00:00 grep --color=auto postg
```

ログ確認

```
2019-06-22 08:21:18.339 UTC [11824] LOG:  database system was interrupted; last known up at 2019-06-22 08:00:49 UTC
2019-06-22 08:21:18.339 UTC [11824] LOG:  creating missing WAL directory "pg_wal/archive_status"
2019-06-22 08:21:18.363 UTC [11824] LOG:  entering standby mode
2019-06-22 08:21:18.580 UTC [11824] LOG:  restored log file "00000001000000000000000C" from archive
2019-06-22 08:21:18.675 UTC [11824] LOG:  redo starts at 0/C000028
2019-06-22 08:21:18.677 UTC [11824] LOG:  consistent recovery state reached at 0/C000130
2019-06-22 08:21:18.678 UTC [11821] LOG:  database system is ready to accept read only connections
2019-06-22 08:21:18.983 UTC [11824] LOG:  restored log file "00000001000000000000000D" from archive
ERROR: 2019/06/22 08:21:19.022706 Archive '00000001000000000000000E' does not exist.
ERROR: 2019/06/22 08:21:19.043264 Archive '00000001000000000000000E' does not exist.
...
2019-06-22 08:25:55.821 UTC [11824] LOG:  restored log file "00000001000000000000000E" from archive
...
```

### 掃除

wal-push で WAL を送り続けるとひたすらたまり続けてしまうので掃除してやる必要がある。`wal-g delete` コマンドで指定の basebackup より前のものを削除することができる、残す世代数を指定しいて削除することも可能

```
Usage:
  wal-g delete [command]

Available Commands:
  before
  retain
```

```
Usage:
  wal-g delete before [FIND_FULL] backup_name|timestamp [flags]

Examples:
  before base_0123              keep everything after base_0123 including itself
  before FIND_FULL base_0123    keep everything after the base of base_0123
```

```
Usage:
  wal-g delete retain [FULL|FIND_FULL] backup_count [flags]

Examples:
  retain 5                      keep 5 backups
  retain FULL 5                 keep 5 full backups and all deltas of them
  retain FIND_FULL 5            find necessary full for 5th and keep everything after it
```

```
$ /usr/local/bin/wal-g.sh backup-list
name                          last_modified        wal_segment_backup_start
base_00000001000000000000000C 2019-06-22T08:00:51Z 00000001000000000000000C
base_00000001000000000000001B 2019-06-22T08:36:29Z 00000001000000000000001B
base_00000001000000000000001D 2019-06-22T08:40:45Z 00000001000000000000001D
```

### 圧縮率確認

圧縮アルゴリズムの変更は環境変数 `WALG_COMPRESSION_METHOD` に `lz4`, `lzma`, `brotli` のいずれかを設定します。デフォルトは lz4 です。

負荷は全然見ていないけれども圧縮後のサイズを見るにこれは brotli が良さそう

basebackup は元データにほぼ差がない状態での比較

```
$ mc ls local/wal-g/basebackups_005/base_00000001000000000000001D/tar_partitions/
[2019-06-22 08:40:44 UTC]   14MiB part_001.tar.lz4
[2019-06-22 08:40:45 UTC]    538B part_003.tar.lz4
[2019-06-22 08:40:44 UTC]    488B pg_control.tar.lz4
$ mc ls local/wal-g/basebackups_005/base_000000010000000000000021/tar_partitions/
[2019-06-22 08:59:18 UTC]  5.4MiB part_001.tar.br
[2019-06-22 08:59:20 UTC]    270B part_003.tar.br
[2019-06-22 08:59:18 UTC]    264B pg_control.tar.br
```

WAL は内容によるけど、ほぼ変更がない場合の brotli がとても小さい

```
[2019-06-22 08:26:22 UTC]   66KiB 00000001000000000000000F.lz4
[2019-06-22 08:26:52 UTC]  2.0MiB 000000010000000000000010.lz4
[2019-06-22 08:27:22 UTC]  2.3MiB 000000010000000000000011.lz4
[2019-06-22 08:27:52 UTC]  2.2MiB 000000010000000000000012.lz4
[2019-06-22 08:28:22 UTC]  2.0MiB 000000010000000000000013.lz4
[2019-06-22 08:28:52 UTC]  3.4MiB 000000010000000000000014.lz4
[2019-06-22 08:29:22 UTC]  3.5MiB 000000010000000000000015.lz4
[2019-06-22 08:29:53 UTC]  3.7MiB 000000010000000000000016.lz4
[2019-06-22 08:30:23 UTC]  1.4MiB 000000010000000000000017.lz4
[2019-06-22 08:31:23 UTC]   80KiB 000000010000000000000018.lz4
[2019-06-22 08:33:23 UTC]   64KiB 000000010000000000000019.lz4
[2019-06-22 08:36:27 UTC]   64KiB 00000001000000000000001A.lz4
[2019-06-22 08:36:28 UTC]    269B 00000001000000000000001B.00000028.backup.lz4
[2019-06-22 08:36:28 UTC]   65KiB 00000001000000000000001B.lz4
[2019-06-22 08:40:44 UTC]   64KiB 00000001000000000000001C.lz4
[2019-06-22 08:40:44 UTC]    268B 00000001000000000000001D.00000028.backup.lz4
[2019-06-22 08:40:44 UTC]   65KiB 00000001000000000000001D.lz4
[2019-06-22 08:45:44 UTC]    179B 00000001000000000000001E.br
[2019-06-22 08:58:53 UTC]    111B 00000001000000000000001F.br
[2019-06-22 08:59:18 UTC]    110B 000000010000000000000020.br
[2019-06-22 08:59:19 UTC]    198B 000000010000000000000021.00000028.backup.br
[2019-06-22 08:59:19 UTC]    178B 000000010000000000000021.br
[2019-06-22 09:02:03 UTC]  2.1MiB 000000010000000000000022.br
[2019-06-22 09:02:33 UTC]  2.2MiB 000000010000000000000023.br
[2019-06-22 09:03:03 UTC]  1.9MiB 000000010000000000000024.br
[2019-06-22 09:03:33 UTC]  2.0MiB 000000010000000000000025.br
[2019-06-22 09:04:03 UTC]  1.2MiB 000000010000000000000026.br
[2019-06-22 09:04:33 UTC]  2.2KiB 000000010000000000000027.br
```

その他
---

#### MySQL 対応？

WAL-G は [MySQL](https://github.com/wal-g/wal-g/blob/master/MySQL.md) にも対応しようとしてるみたいです。MySQL ナニモワカラナイ..

#### 古い OS で実行する場合の注意

今のところ、古い OS (glibc) では GitHub で公開されてるバイナリが動かない。CentOS 6 などで実行する必要がある場合は自前でビルドする必要がある

[https://github.com/wal-g/wal-g/issues/300](https://github.com/wal-g/wal-g/issues/300)

#### 他のツール

PostgreSQL のバックアップツール沢山あって困る...

* [WAL-E](https://github.com/wal-e/wal-e)
* [WAL-G](https://github.com/wal-g/wal-g)
* [pgBackRest](https://pgbackrest.org/)
  * [Efficiently Backing up Terabytes of Data with pgBackRest (PGDay Russia 2017)](https://pgday.net/presentation/164/59648dd450ca4.pdf)
  * [High Performance pgBackRest (PGCon 2019)](https://www.pgcon.org/2019/schedule/attachments/533_High-Performance-pgBackRest.pdf)
  * [How to backup PostgreSQL in mass volume production environments | Inceptum](https://www.inceptum.hr/how-to-backup-postgresql/)
* [pg\_rman](https://ossc-db.github.io/pg_rman/index-ja.html)
  * [pg\_rman (PostgreSQL のバックアップ/リストア管理ツール) - SRA OSS, Inc. 日本支社](https://www.sraoss.co.jp/technology/postgresql/3rdparty/pg_rman.php)
  * [PostgreSQLの周辺ツール ～ pg\_rmanでバックアップ・リカバリーを管理する ～：PostgreSQLインサイド : 富士通](https://www.fujitsu.com/jp/products/software/resources/feature-stories/pgrman/?article-index)
* [Barman](https://www.pgbarman.org/)
  * [Barman（PostgreSQL PITR 補助ツール）](https://www.sraoss.co.jp/tech-blog/pgsql/barman/)

まだ他にもあるけど pgBackRest が良さそうなのかな

[![](//ws-fe.amazon-adsystem.com/widgets/q?_encoding=UTF8&ASIN=4297100894&Format=_SL250_&ID=AsinImage&MarketPlace=JP&ServiceVersion=20070822&WS=1&tag=ytera-22&language=ja_JP)](https://www.amazon.co.jp/%E6%94%B9%E8%A8%82%E6%96%B0%E7%89%88-%E5%86%85%E9%83%A8%E6%A7%8B%E9%80%A0%E3%81%8B%E3%82%89%E5%AD%A6%E3%81%B6PostgreSQL-%E8%A8%AD%E8%A8%88-%E9%81%8B%E7%94%A8%E8%A8%88%E7%94%BB%E3%81%AE%E9%89%84%E5%89%87-Software-Design/dp/4297100894/ref=as_li_ss_il?ie=UTF8&linkCode=li3&tag=ytera-22&linkId=004770e7f4620e7ffc9363c63e657592&language=ja_JP)![](https://ir-jp.amazon-adsystem.com/e/ir?t=ytera-22&language=ja_JP&l=li3&o=9&a=4297100894) [![](//ws-fe.amazon-adsystem.com/widgets/q?_encoding=UTF8&ASIN=4774198145&Format=_SL250_&ID=AsinImage&MarketPlace=JP&ServiceVersion=20070822&WS=1&tag=ytera-22&language=ja_JP)](https://www.amazon.co.jp/%E3%81%93%E3%82%8C%E3%81%8B%E3%82%89%E3%81%AF%E3%81%98%E3%82%81%E3%82%8B-PostgreSQL%E5%85%A5%E9%96%80-%E9%AB%98%E5%A1%9A-%E9%81%99/dp/4774198145/ref=as_li_ss_il?__mk_ja_JP=%E3%82%AB%E3%82%BF%E3%82%AB%E3%83%8A&keywords=PostgreSQL&qid=1561786336&s=gateway&sr=8-2&linkCode=li3&tag=ytera-22&linkId=1b0482c38b4d89582e5fcaf01961e92a&language=ja_JP)![](https://ir-jp.amazon-adsystem.com/e/ir?t=ytera-22&language=ja_JP&l=li3&o=9&a=4774198145)
