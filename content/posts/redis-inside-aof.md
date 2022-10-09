---
title: 'Redis の内部を探ってみる (aof)'
date: Fri, 04 Jan 2013 12:38:45 +0000
draft: false
tags: ['Linux', 'Redis', 'redis']
---

[Redis の内部を探ってみる (save)](/2012/12/redis-inside-save/) の続き、今回は appendonlyfile について見てみよう。 と思ってたら[Redis Persistence](http://redis.io/topics/persistence) (redis.io) に全部書いてあるじゃない... 更新系コマンドについて、レスポンスを返す前にずっとログファイルに追記して、最起動時にはそれを順番にリプレイするんですね。 save はある瞬間の dump でしかないので、電源障害などの時に最後の save 以降のデータを失うが appendonlyfile を有効にすることで回避できる、その分レスポンスタイムは悪くなる。 ファイルへの書き込みの sync タイミングを

*   常に sync
*   1秒おきに sync (default)
*   明示的な sync を行わない

から選べる。(上側がより遅い) 同じキーの更新を続けると無駄にファイルが肥大化する(counterのincrementとか)ので save と同様の仕組みで fork してその時点の dump からの追記へと作りなおすことができる。この処理中の変更はメモリに溜めておいて処理後に追加するが、処理中も古いファイルへ書き込みを続けているので安全。 ちなみに shutdown 時には sync される、aof が無効で save が有効な場合は shutdown 時に save されるので、正常は Redis の再起動ではデータは失われない。 ドットインストールに [Redisの基礎 (全14回)](http://dotinstall.com/lessons/basic_redis) ができてみたいです。 [『Redisの基礎 (全14回)』をドットインストールに追加しました #dotinstall](http://www.ideaxidea.com/archives/2013/01/basic_redis_added.html)