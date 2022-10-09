---
title: 'Redash でコケてしまったタスク情報の掃除'
date: Tue, 17 Jul 2018 15:06:38 +0000
draft: false
tags: ['Redash', 'Redash', 'redis']
---

[Redash](https://redash.io/) でクエリの実行は redis の queue を通して [celery](http://www.celeryproject.org/) にて実行されているようです、この celery で実行している処理が不慮の事故で死んでしまうと Redash の画面上ではずっと IN PROGRESS 状態として残ってしまうという問題がありました。これを削除するためにやったことのメモです。 最初は Database (PostgreSQL) に入ってるのかなと思ったけど、それらしきレコードは見つかりませんでした```
                  List of relations
 Schema |           Name            | Type  | Owner
--------+---------------------------+-------+--------
 public | access\_permissions        | table | redash
 public | alembic\_version           | table | redash
 public | alert\_subscriptions       | table | redash
 public | alerts                    | table | redash
 public | api\_keys                  | table | redash
 public | changes                   | table | redash
 public | dashboards                | table | redash
 public | data\_source\_groups        | table | redash
 public | data\_sources              | table | redash
 public | events                    | table | redash
 public | groups                    | table | redash
 public | notification\_destinations | table | redash
 public | organizations             | table | redash
 public | queries                   | table | redash
 public | query\_results             | table | redash
 public | query\_snippets            | table | redash
 public | users                     | table | redash
 public | visualizations            | table | redash
 public | widgets                   | table | redash

```それでは redis だろうと **\`redis-cli keys \\\*\`** でキーの一覧を出してみる```
data\_source:schema:1
data\_source:schema:2
data\_source:schema:3
data\_source:schema:4
data\_source:schema:5
data\_source:schema:6
data\_source:schema:7
data\_source:schema:8
data\_source:schema:9
data\_source:schema:10
\_kombu.binding.celery
\_kombu.binding.celeryev
\_kombu.binding.celery.pidbox
\_kombu.binding.queries
\_kombu.binding.scheduled\_queries
\_kombu.binding.schemas
new\_version\_available
query\_task\_trackers:done
redash:status
schemas
sq:executed\_at
celery-task-meta-UUID <-- いろんな UUID で沢山
query\_task\_tracker:UUID <-- いろんな UUID で沢山

```UUID はログから分かっていたので **keys \*UUID\*** を試してみたら **query\_task\_tracker:164b9632-40a5-4af4-8500-21022b06215d** というのがあった。 中身は JSON でこんなのが入ってました。```
{
  "username": "user@example.com",
  "retries": 0,
  "started\_at": 1527501588.652453,
  "task\_id": "164b9632-40a5-4af4-8500-21022b06215d",
  "created\_at": 1527501564.920558,
  "updated\_at": 1527501588.652842,
  "state": "executing\_query",
  "query\_id": 91,
  "run\_time": null,
  "scheduled": false,
  "scheduled\_retries": 0,
  "data\_source\_id": 2,
  "query\_hash": "2b0cc6eac4188b1b0097b02b9d4f1f6e"
}

```でも IN PROGRESS のリストにこの情報が出るってことはこの key=value だけじゃなくてどこかにこの key を持ったリストのようなデータがあるはず、ということで **redis-cli monitor** で redis に対してどんなリクエストが発行されてるかを眺めてみました。 上に並べた **keys \*** のリストは IN PROGRESS のクエリがない状態なので存在しませんが、**monitor** コマンドで確認したら **query\_task\_trackers:in\_progress** というキーがありました。名前からしてこれですね。 さて、**query\_task\_trackers:in\_progress** の型は何だろうか？ そんな場合は [type](https://redis.io/commands/type) コマンドで確認できます。これは **zset** でした。```
\> type query\_task\_trackers:in\_progress
zset

```**zset** のリストを全部取り出すには次の様に [zrange](https://redis.io/commands/zrange) で 0 から -1 までと指定します```
\> zrange query\_task\_trackers:in\_progress 0 -1

```この zset から当該の task 情報を削除すれば良さそうなので [zrem](https://redis.io/commands/zrem) で消します```
\> zrem query\_task\_trackers:in\_progress query\_task\_tracker:164b9632-40a5-4af4-8500-21022b06215d

```めでたしめでたし。 Redis の調査には「[Redis に保存されてる値を見ようと思った時に覚えておきたい redis コマンド | そんなこと覚えてない](https://blog.eiel.info/blog/2014/08/26/remember-redis/)」が大変参考になりました。