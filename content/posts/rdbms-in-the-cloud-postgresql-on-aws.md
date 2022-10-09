---
title: 'RDBMS in the Cloud: PostgreSQL on AWS を読んで'
date: Fri, 12 Jul 2013 15:13:58 +0000
draft: false
tags: ['AWS', 'PostgreSQL']
---

[【AWS発表】AWS上でPostgreSQLを実行する - 新しいホワイトペーパーを公開](http://aws.typepad.com/aws_japan/2013/07/running-postgresql-on-aws.html) にあった [RDBMS in the Cloud: PostgreSQL on AWS](http://media.amazonwebservices.com/AWS_RDBMS_PostgreSQL.pdf) (PDF) を読んだので個人的にフムフムと思ったところをまとめておく。

### Temporary Data and SSD Instance Storage

一時データ用のテーブルを SSD に置く方法。 SSD はインスタンスストレージなので OS 再起動でデータは消えてしまう。 まず、テーブルを作成したらデータを入れる前に関連データファイルを cp コマンドなどでバックアップし、OS　再起動時には PostgreSQL を起動する前にバックアップしたファイルを戻すことで、そのまま利用することができる。もちろん当該テーブルのデータは空っぽだが一時データだからそれを念頭に置いた使い方をする。 Replication を行なっている場合には通常テーブルこれを行うと不整合が発生するため、UNLOGGED テーブルとすることで回避できる。UNLOGGED テーブルは replication の対象外となるため。

### Performance Suggestions

パフォーマンスを上げるには性能の良いインスタンスに切り替えることと、EBS を RAID0 で束ねること。EBS の数を増やすことでパフォーマンスを上げることが可能。Provisioned IOPS を使うこと。ただし、PIOS には制限があって 4,000 IOPS が必要な場合には最低でも 400GB のボリュームが必要（お金が必要） effective\_io\_concurrency の値は EBS のボリューム (RAID0 の stripe) 数に合わせる。 SSD 上で稼働するレプリカの場合は fsync と full\_page\_writes を無効にする。(SSD のデータはクラッシュ時には消えてしまうので)

### Maintenance and Vacuuming

auto vacuum はデフォルトで有効だが、同時実行数、実行間隔、実行タイミングをチューニングすべし。

### Read-Only Servers

メンテナンスのためなどに一時的に DB を Read-Only にするためには

```
ransaction_read_only=on
default_transaction_read_only=on
```

と設定して、pg\_ctl reload する。

### Storing Backups and WAL Files

S3 を使ったバックアップ/アーカイブツールの紹介 [https://github.com/wal-e/wal-e](https://github.com/wal-e/wal-e) 次のコマンドがある

* **backup-push** - フルバックアップを S3 に保存する
* **backup-fetch** - フルバックアップを S3 から取得する
* **wal-push** - archive\_command で使って WAL ファイルを S3 に保存する
* **wal-fetch** - restore\_command で使って WAL ファイルを S3 から取得する
* **backup-list** - バックアップリストを取得する
* **delete** - 指定した base backup より前のファイルを削除する

圧縮と暗号化(GPG)もサポートする。AWS で使う場合、これは便利そう。

### Tunables

* 不要な swap を抑えるために vm.swappiness は 5 以下にする
* ファイルシステムは xfs でマウントオプションに `nobarrier,noatime,noexec,nodiratime` を指定する
* pg\_xlog (WAL) ディレクトリはデータとは別ボリュームにするべし、そして fsync の効率から xfs にするべし。
* postgresql.conf の設定には pgTune ([https://github.com/gregs1104/pgtune/](https://github.com/gregs1104/pgtune/)) が参考になる。ただし、サポートされているバージョンに注意

ext3 を使うなというメッセージが強い。
