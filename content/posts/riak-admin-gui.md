---
title: 'Riak Admin GUI'
date: Wed, 13 Feb 2013 16:19:45 +0000
draft: false
tags: ['Riak']
---

Riak の bucket 設定とか、オブジェクトの管理ツールを Ruby on Rails の勉強がてら作ってみようかなぁと思ってたら... [ひとりでやるRiak Advent Calendar 2012 day1 - 入門 - kuenishi's blog](http://kuenishi.hatenadiary.jp/entry/2012/12/01/131759) ん？！

> しかし私は軟弱なのでGUIを使う。riak\_controlというイカしたWeb UIがあるのだ。

なんですとっ！！標準添付されてた... では早速試してみよう。 etc/app.config を書き換えて stop / start http と https を両方有効にしてどちらも 0.0.0.0 で listen させて、http から admin\_gui にアクセスしようとしたら https://0.0.0.0:xxx/ というリンクになってたからここは 0.0.0.0 は使わないほうが良さそう。 そしてアクセスしてみた。かっちょいい！！ ![](/wp-content/uploads/2013/02/riak_admin_gui_current_snapshot-e1360771788531.png) ![](/wp-content/uploads/2013/02/riak_admin_gui_cluster_management-e1360771774445.png) ![](/wp-content/uploads/2013/02/riak_admin_gui_current_ring-e1360771736607.png) あれれ？？ Bucket の設定とか Object の操作するインターフェースがないなぁ。上西さんの blog の画像にはそんな機能が見えるのにな（グレーアウトしてる感じだけど） 1.2.1 だけどどうやってインストールしたんだっけなぁ [Installing Riak from source package](/2013/01/installing-riak-from-source-package/) これか。git clone してるな。
