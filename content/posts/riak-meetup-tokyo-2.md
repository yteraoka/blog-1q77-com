---
title: 'Riak Meetup Tokyo 2 に参加してきた #riakjp'
date: Wed, 10 Jul 2013 16:30:30 +0000
draft: false
tags: ['Riak']
---

2013/07/10 Yahoo! JAPAN にて開催された [Riak Meetup Tokyo #2](http://connpass.com/event/2656/) に参加してきたのでメモ

### セッション1 FreakOut 久森さん 「Riak環境をプロダクションで構築＆運用してみた（仮）」

[RTB](http://rtbsquare.ciao.jp/?page_id=401) ([こっちじゃない](http://monjiro.net/dic/rank/29/83316/33)) という「50ms or die」な環境で Riak を導入してみて...というお話。 SSP からのリクエストに 100ms 以内にリクエストを返さないと、リクエストすら来なくなるというハードな世界。ネットワークの TTL が 10ms 程度で、アプリ側の処理は 50ms に抑えたいという。 このような環境でデータストアとして Kyoto なんとか Tokyo なんとかを使ってきたがアプリ側での計算による分散であるため、スケールアウトが容易ではないという問題を解決するために Riak の導入にチャレンジしている。 構成はアプリとの間に [HA Proxy](http://haproxy.1wt.eu/) を挟む [Engine Yard](http://www.engineyard.co.jp/) 方式 (前回の Meetup で紹介されていました) を採用。 で、どうだったかというと HA Proxy が RoundRobin などで振り分けてしまうため、実際に必要なデータを持っていない node に振られることが多く、その場合、そこから更にデータを持っている node から取ってきて返すという処理 (Redirect) が発生し、そのレスポンス待ちでアプリの worker が詰まってしまい 100ms を超えてしまう状況が発生してしまった。 今後は HA Proxy の層を撤廃し、どの node がデータを持っているかを bucket と key から計算してダイレクトに node に問い合わせる方法を検討されているとのこと。 FreakOut のアプリは Perl がメインで今回の Riak クライアントも Perl (XS) で実装。 既存の Perl Module は遅かったので自作されたとのこと。Protocol は PBC [https://github.com/myfinder/p5-riak-lite](https://github.com/myfinder/p5-riak-lite) パフォーマンス比較 [https://gist.github.com/myfinder/5232845](https://gist.github.com/myfinder/5232845) Riak を空きポートで起動させてテストするためのコードも [https://github.com/myfinder/p5-riak-lite-pbc](https://github.com/myfinder/p5-riak-lite-pbc) @johtani さんの [Riak Meetup Tokyo #2に参加しました。](http://blog.johtani.info/blog/2013/07/10/riak-meetup-tokyo-no2/) を見て思い出したので追記 (2013/7/11)

* HA Proxy 構成では厳しいので今はホットなデータを memcached にキャッシュしている
* Riak の backend は Bitcask (とりあえずデフォルトで評価というのと expire 機能に期待)
* Bucket の r, w は最初デフォルトの r:2, w:3 で、r:1 に変えてみたけど求める速度には至らなかった

### LT IIJ 曽我部さん、田中さん 「Yokozuna 日本語検索性能を評価しました」

Riak に Solr を組み合わせた Yokozuna というものが日本語に対応したということで、その検証レポート。まだまだ検証途中のようです。 Solr だからスキーマは定義して上げる必要がある。Bucket 単位で Solr の core を作成する。データは yz\_extractor が plain text / JSON / XML を parse してくれる。 タイトルだけ見た段階では、「それなら Elastic Search じゃない？」って思いましたが Riak へのデータ登録、削除、node の増減にも追随するということなら良いかもと思いました。が、そのあたりはまだテストできてないとのことでしたので要望として上げておこう。

* すでにデータの存在する Bucket に設定すると index してくれるのか
* Re-index する機能があるのか
* スキーマを変えたい時は別のスキーマを指定した index を追加して切り替えられるのか
* データの更新・削除は index に反映されるのか
* node の追加、削除時に hand off に合わせて index も移動するのか
* Solr (Java) だけが一時的に落ちてしまった場合の対応方法 (Java のチューニングで再起動とかはありそう)
* Solr への登録は同期？非同期？

とか？ Solr の distributed search って全部からの応答を待つし、一つでもエラーがあったらエラーになってしまう記憶があるので、ちょっとでも遅いサーバーがあったりすると全体に影響するのかな？ しかし、テストのために32台もの結構良いスペックのサーバーが使えるなんて IIJ さんうらやましい。

### Drinkup

[Riak Drinkup Tokyo #2](http://connpass.com/event/2771/) こちらも参加させていただきました。ごちそうさまでした。

### おまけ

Bucket と Key から Hash 値を取得する方法とか、Hash 値から node を取得する方法とか書いてあるサイト見つけました。参考になる。 [第２回　NOSQL実機ハンズオン（Riak、Hibari）](http://ossforum-jp-nosql.github.io/hands-on/hands-on.html) [https://github.com/ossforum-jp-nosql/hands-on](https://github.com/ossforum-jp-nosql/hands-on)
