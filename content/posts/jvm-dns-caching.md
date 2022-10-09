---
title: 'JVM が DNS の結果を永久にキャッシュするのは 1.5 まで'
date: 
draft: true
tags: ['未分類']
---

スマホのブラウザのタブが90を超えて「ありゃりゃ、これはお掃除せねば」ということで古いタブを整理してたらこんなページがありました [Web Application Server を動かす時の Java8 起動オプションのメモ](http://moznion.hatenadiary.com/entry/2016/03/11/121343)  
[http://moznion.hatenadiary.com/entry/2016/03/11/121343](http://moznion.hatenadiary.com/entry/2016/03/11/121343) 確かに見た気がする。けど、Java 8 なのに

> デフォルトでは DNS の成功結果を未来永劫キャッシュするようになっていてアレなので，0を設定することでキャッシュしないようにする．

ってそんなことはないでしょ？そんなの昔の話だよってことで調べてみたよ。 まぁ、リンク先で引用されてる中にも書いてあるんだけど

> The default behavior is to cache forever when a security manager is installed, and to cache for an implementation specific period of time, when a security manager is not installed.

「セキュリティマネージャがインストールされてる場合は永久にキャッシュを持ち続けるけど、そうでない場合は実装依存の時間だけキャッシュします」と。 セキュリティマネージャってなんぞや？ってことですが