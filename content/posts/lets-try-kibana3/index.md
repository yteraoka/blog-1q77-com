---
title: 'Kibana3 を使ってみよう #kibana3'
date: Wed, 02 Oct 2013 15:59:50 +0000
draft: false
tags: ['elasticsearch', 'kibana3']
---

話題の kibana3 を使ってみたメモです。

[fluentd-plugin-elasticsearch](https://github.com/uken/fluent-plugin-elasticsearch) で [ElasticSearch](http://www.elasticsearch.org/) に突っ込めば簡単に Kibana3 を試せるよっていうブログはちょいちょい見るのですが、Kibana3 をどうやって使うのか書かれてるものが少ないようなので書いてみます。そういうことなので、ElasticSearch に取り込むところまでは省略。

でも一点だけ、ElasticSearch の [template](http://www.elasticsearch.org/guide/reference/api/admin-indices-templates/) 機能を使ったほうが良いですよ（と会社の同僚に教えてもらいました）。

fluentd-plugin-elasticsearch はすべてのフィールドを文字列として送ってしまうので、ElasticSearch 側でこのフィールドは Integer だよとか、日付型だよって教えてあげないと行けませんが、Kibana では日毎のインデックスを使うのでインデックス毎に設定するのは厳しいです。template を設定しておくと、指定したルールにマッチするインデックスに自動でスキーマが適用されます。全部のフィールドを指定する必要がありません。文字列で良いフィールドは放置でOK。複数サービスでも使えるようにインデックスの名前と template のマッチ条件を合わせてあげるのが良いです。Integer 指定は重要で、Kibana3 で合計や平均値をグラフにするのに必要です。文字列よりもインデックスサイズが小さくなりますしね。

{{< figure src="top.png" >}}

これが、Kibana3 の初期ページです。  

右下の

1.  Sample Dashboard
2.  Unconfigured Dashboard
3.  Blank Dashboard

から始めても良いですし、左上の Introduction と書いてある右の歯車アイコンで、このページを直接いじっても良いです。

それでは、歯車から設定していきましょう。

{{< figure src="kibana3-index.png" caption="Index 指定" >}}

まずは、インデックス名の指定です。 Timestamping で none 以外を選択すると左のフォームが表示されるので、`[logstash-]YYYY.MM.DD` の logstash- 部分を自分で指定したものに変更しましょう。  

次はパーツを配置するための行 (rows) を作成します。

{{< figure src="kibana3-rows.png" caption="Kibana3 row 設定" >}}

行のタイトルと高さ（ピクセル）を指定して作成します。順番は後から変更できます。行を作成するとページの左端に行のタイトルが表示されます。それぞれの行にどのパーツを配置するかはタイトルの上にある小さな歯車アイコンから行います。  

{{< figure src="kibana3-panels.png" caption="Kibana3 panels" >}}

Twieer Bootstrap なので（ですよね？）各パーツの幅を12段階から選択します。  
パネルの種類には次のものがあります。

* bettermap
* column
* dashcontrol
* derivequeries
* fields
* filtering
* histgram
* hits
* map
* pie
* query
* table
* terms
* text
* timepicker
* trends

が、ここでは私の使ったものだけを簡単に紹介します。

[![全体像はこんな感じ](http://158.101.138.193/wp-content/uploads/2013/10/kibana3-example.png)](http://158.101.138.193/wp-content/uploads/2013/10/kibana3-example.png)
{{< figure src="kibana3-example.png" >}}

全体像はこんな感じ。  

{{< figure src="kibana3-timepicker-panel.png" >}}

まずは TImepicker から。これで対象範囲を期間で絞ります。Relative, Absolute, Since の3タイプがあります。ワンクリックで相互切り替えできます。  

{{< figure src="kibana3-timepicker-relative.png" caption="Timepicker relative" >}}

Relative: ワンクリックで過去5分とか過去6時間とか切り替えられます。並べるリストもカスタマイズ可能です。

{{< figure src="kibana3-timepicker-absolute.png" caption="Timepicker absolute" >}}

Absolute: 開始、終了日時を直接指定します

{{< figure src="kibana3-timepicker-since.png" caption="Timepicker since" >}}

Since: 指定の日時以降を対象にします

{{< figure src="kibana3-search.png" caption="Search" >}}

期間が絞れたところで、次は query で対象を絞ります。複数の検索条件を保存でき、それぞれの条件を使ってグラフなどを表示することができます。検索クエリの Syntax は Lucene のページを確認しましょう。
[LuceneTutorial.com](http://www.lucenetutorial.com/lucene-query-syntax.html) とか？最後の欄にある「＋」アイコンをクリックすることでクエリを追加できます。  

{{< figure src="query_alias.png" caption="Query Alias" >}}

色のついて丸いところをクリックすると別の色を選択することができます、また、クエリが長いとわかりづらいので名前をつけることができます。日本語も可。グラフの方にはその名前で表示されます。左上のピンアイコンをクリックすると pinned 状態にできます。グラフのパネルで queries 選択で pinned, unpinned を選択することで pinned したものを対象にしたり、その逆にしたりをして簡単に表示対象を切り替えることができます。  

{{< figure src="kibana3-access-count-panel.png" caption="Kibana3 Access Count Panel" >}}

続いてヒストグラムを使って、アクセス数を表示します。この例では Lines を選択しています。線の太さも選べます。複数の線グラフを並べるので Stack のチェックを外してあります。  

{{< figure src="kibana3-access-count.png" caption="Kibana3 Access Count" >}}

こんなグラフになります。Countだじゃなくて、Max, Mean, Min というのもあるのでレスポンスタイムの最大値や平均値のグラフも簡単にできます。  

{{< figure src="kibna3-responsetime-histgram.png" caption="Kibana3 Response Time" >}}

これもヒストグラムですが、今度はレスポンスタイム毎に Stack する棒グラフにしてみました。「< 200ms」などクエリのAliasが表示されていますね。このクエリは「usec:\[0-199999\]」てな感じです。  

{{< figure src="kibana3-pie.png" caption="Pie Chart" >}}

お次はステータスコードのパイチャート  

あと、全体像の下につらつらと表示されているのは「table」というパネルで、検索条件にマッチしたログがリスト表示されます。ページングサイズも指定可能。クリックするとそのログについてインデックスされているすべての情報が確認できます。User-Agent とか Remote Host とか。  

{{< figure src="kibana3-save.png" caption="Kibana3 Save" >}}

苦労して設定したパネルは右上のフロッピーディスクアイコン（若者にはわからない？）をクリックし、名前をつけて保存しておきましょう。次からフォルダアイコンから呼び出せます。デフォルトに指定することもできます。  

はあ〜長かった（画像が多いだけか）。 どうでしょう？試してみたくなりました？ もっとこうやったら良いとか便利情報お待ちしてます。 あ、そうそう、日別に作られてるインデックスは貯めこまないで削除しましょう。APIを駆使すれば自動化可能です。Vagrant で 1GB heap の環境で試してたけど、このブログのアクセスログ（少ない）を数ヶ月分突っ込んでみたら、ちょいちょい応答がなくなって ElasticSearch を再起動すると復活するような感じでした。
