---
title: 'nodejs がサポートしてなかった結合 gzip ファイル'
date: Mon, 23 Jan 2017 15:15:53 +0000
draft: false
tags: ['AWS', 'Lambda', 'AWS', 'gzip', 'nodejs']
---

[AWS Lambda](https://aws.amazon.com/jp/lambda/) で [Application Load Balancer (ALB)](https://aws.amazon.com/jp/elasticloadbalancing/applicationloadbalancer/) のログを [Elasticsearch](https://aws.amazon.com/jp/elasticsearch-service/) へ投入して Kibana でビジュアライズしようと思い nodejs で Lambda Function を書いてみました。 [https://github.com/awslabs/amazon-elasticsearch-lambda-samples/blob/master/src/s3\_lambda\_es.js](https://github.com/awslabs/amazon-elasticsearch-lambda-samples/blob/master/src/s3_lambda_es.js) ここにサンプルがあって、おっ？これはほぼこのまま使えるのか？って思ってやってみたら

* 使われている [clf-parser](https://www.npmjs.com/package/clf-parser) は Apache の **Common Log Format** にしか対応していない
* Elasticsearch への投入に [Bulk API](https://www.elastic.co/guide/en/elasticsearch/reference/2.3/docs-bulk.html) を使ってない、Lambda には時間制限があるのに1行ずつ登録していては時間が掛かり過ぎる
* S3 のファイルが gzip されてない前提

という残念な感じだった... 初めて書く nodejs でよくわからないながらも stream で処理するようにしてみてやっとできたと思って喜んでみたのもつかの間、何故か 1,000 アクセス、10,000 アクセスしてみても 170 件程度しか Elasticsearch に入らないのです。 あら？なにか stream の使い方がおかしいのかな？と思いファイルをまるっと処理するようにしてみたけど結果が変わらず... さらに調査を進めると同じファイルは常に同じ件数しか登録されない、そもそも gzip から取り出せてないということに気づきました。 もしかしてこれはあれじゃないか？ということでその gzip ファイルを [od](http://man7.org/linux/man-pages/man1/od.1.html) コマンドで開いて見たらやっぱり複数の gzip chunk が1つのファイルに連結されていました。そして AWS Lambda で使われている nodejs 4.3.2 では zlib がこれに対応していなかったのです... orz

```
$ echo 123 | gzip > a.gz
$ echo 456 | gzip >> a.gz
$ echo 789 | gzip >> a.gz
```

こんな感じで追記されてる gzip ファイルから読みだしても最初の 123 しか出てこないのです。（gzip コマンドなどでは問題なく扱えます） Twitter でつぶやいたら nodejs 6.0.0 で対応されたらしいことまでわかりました。7.4 で試したら確かにちゃんと読み出せました。

{{< x user="shuheikagawa" id="823499642092613633" >}}

> [@yteraoka](https://x.com/yteraoka) これですかね。Node 6.0.0 からの模様。 [https://t.co/BeC9SWf2F8](https://t.co/BeC9SWf2F8) [https://t.co/WfqUtatYYh](https://t.co/WfqUtatYYh)
> 
> — Shuhei Kagawa (@shuheikagawa) [2017年1月23日](https://x.com/shuheikagawa/status/823499642092613633)

Lambda は python で書き直しましたとさ。 みんな困ってないのかな？ AWS のサポートにリクエストしておこう。
