---
title: 'PostgreSQL 9.4 の新機能'
date: 
draft: true
tags: ['PostgreSQL', 'postgresql']
---

2014/5/15 に PostgreSQL 9.4 の Beta 1 がリリースされていたので 9.4 の新機能を確認してみます。 [What's new in PostgreSQL 9.4](http://wiki.postgresql.org/wiki/What's_new_in_PostgreSQL_9.4) に書いてあることです。

メージャーな新機能
---------

### レプリケーションスロット

Streaming Replicatioin にて replica サーバーがダウンした場合、長時間復旧しないと master 側で古い WAL ファイルが削除され replication が再開できなくなります。これを防ぐための機能です。replication に必要なログは消さないようにできます。これまでは `wal_keep_segments` で多めに WAL を残すことで回避していましたが完全ではありませんでした。

### ロジカルでコーディング

これにより WAL から Query を復元し、replica に適用する logical replication が利用可能になります。logical replication では一部の DB のみを replication したり、双方向の replication が可能となります。双方向はちょっと怖いけど PostgreSQL の upgrade 時に活用できるのかな？ [Bi-Directional Replication User Guide](https://wiki.postgresql.org/wiki/BDR_User_Guide)

### GIN インデックスがより速く小さくなります

### pg\_prewarm

その他の新機能
-------

### ALTER SYSTEM

### REFRESH MATERIALIZED VIEW CONCURRENTLY

### view のアクセスコントロール強化

### WITH CHECK OPTION

### Updatable security barrier views

### WITH ORDINALITY

### Ordered-set aggregates

### Aggregate FILTER clause

### Moving-aggregate support

### state\_data\_size parameter