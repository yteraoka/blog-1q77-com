---
title: 'Redash でコケてしまったタスク情報の掃除'
date: Tue, 17 Jul 2018 15:06:38 +0000
draft: false
tags: ['Redash', 'redis']
---

[Redash](https://redash.io/) でクエリの実行は redis の queue を通して [celery](http://www.celeryproject.org/) にて実行されているようです、この celery で実行している処理が不慮の事故で死んでしまうと Redash の画面上ではずっと IN PROGRESS 状態として残ってしまうという問題がありました。これを削除するためにやったことのメモです。 最初は Database (PostgreSQL) に入ってるのかなと思ったけど、それらしきレコードは見つかりませんでした

```
                  List of relations
 Schema |           Name            | Type  | Owner
--------+---------------------------+-------+--------
 public | access_permissions        | table | redash
 public | alembic_version           | table | redash
 public | alert_subscriptions       | table | redash
 public | alerts                    | table | redash
 public | api_keys                  | table | redash
 public | changes                   | table | redash
 public | dashboards                | table | redash
 public | data_source_groups        | table | redash
 public | data_sources              | table | redash
 public | events                    | table | redash
 public | groups                    | table | redash
 public | notification_destinations | table | redash
 public | organizations             | table | redash
 public | queries                   | table | redash
 public | query_results             | table | redash
 public | query_snippets            | table | redash
 public | users                     | table | redash
 public | visualizations            | table | redash
 public | widgets                   | table | redash
```

それでは redis だろうと `redis-cli keys \*` でキーの一覧を出してみる

```
data_source:schema:1
data_source:schema:2
data_source:schema:3
data_source:schema:4
data_source:schema:5
data_source:schema:6
data_source:schema:7
data_source:schema:8
data_source:schema:9
data_source:schema:10
_kombu.binding.celery
_kombu.binding.celeryev
_kombu.binding.celery.pidbox
_kombu.binding.queries
_kombu.binding.scheduled_queries
_kombu.binding.schemas
new_version_available
query_task_trackers:done
redash:status
schemas
sq:executed_at
celery-task-meta-UUID <-- いろんな UUID で沢山
query_task_tracker:UUID <-- いろんな UUID で沢山
```

UUID はログから分かっていたので `keys *UUID*` を試してみたら `query_task_tracker:164b9632-40a5-4af4-8500-21022b06215d` というのがあった。 中身は JSON でこんなのが入ってました。

```json
{
  "username": "user@example.com",
  "retries": 0,
  "started_at": 1527501588.652453,
  "task_id": "164b9632-40a5-4af4-8500-21022b06215d",
  "created_at": 1527501564.920558,
  "updated_at": 1527501588.652842,
  "state": "executing_query",
  "query_id": 91,
  "run_time": null,
  "scheduled": false,
  "scheduled_retries": 0,
  "data_source_id": 2,
  "query_hash": "2b0cc6eac4188b1b0097b02b9d4f1f6e"
}
```

でも IN PROGRESS のリストにこの情報が出るってことはこの key=value だけじゃなくてどこかにこの key を持ったリストのようなデータがあるはず、ということで **redis-cli monitor** で redis に対してどんなリクエストが発行されてるかを眺めてみました。 上に並べた `keys *` のリストは IN PROGRESS のクエリがない状態なので存在しませんが、`monitor` コマンドで確認したら `query_task_trackers:in_progress` というキーがありました。名前からしてこれですね。 さて、`query_task_trackers:in_progress` の型は何だろうか？ そんな場合は [type](https://redis.io/commands/type) コマンドで確認できます。これは `zset` でした。

```
> type query_task_trackers:in_progress
zset
```

**zset** のリストを全部取り出すには次の様に [zrange](https://redis.io/commands/zrange) で 0 から -1 までと指定します

```
> zrange query_task_trackers:in_progress 0 -1
```

この zset から当該の task 情報を削除すれば良さそうなので [zrem](https://redis.io/commands/zrem) で消します

```
> zrem query_task_trackers:in_progress query_task_tracker:164b9632-40a5-4af4-8500-21022b06215d
```

めでたしめでたし。 Redis の調査には「[Redis に保存されてる値を見ようと思った時に覚えておきたい redis コマンド | そんなこと覚えてない](https://blog.eiel.info/blog/2014/08/26/remember-redis/)」が大変参考になりました。
