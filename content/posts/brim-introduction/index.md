---
title: 'tcpdump のお供に Brim を使いましょう'
date: Thu, 10 Dec 2020 00:10:37 +0900
draft: false
tags: ['Brim', 'Network', 'Advent Calendar 2020']
---

[Advent Calendar 2020 全部オレシリーズ](https://qiita.com/advent-calendar/2020/yteraoka) 9日目です。もう完走は諦めましたがなんとか続いています。

今日も tcpdump と戯れてました。クラウドメインになってからも tcpdump は必須です。

ですが、問題の再現手順がはっきりしない場合は30分とか1時間、あるいは数時間のキャプチャファイルからお目当てのものを探す必要があったりします、wireshark だけでは苦行すぎます。そこで使えるのが今日紹介する [Brim](https://www.brimsecurity.com/) です。

紹介と言ってもサイトに動画へのリンクがあって、それを見てねで終わってしまうのですが...

{{< youtube InT-7WZ5Y2Y >}}

まず起動して pcap ファイルを開くと、巨大なキャプチャファイルでも解析が用意な znq ファイルへの変換処理が走って次のような表示になります。裏で zqd サーバーが起動してそれとの通信を行っているようです。春先に使ってた時とちょっと様子が違う。昔は pcap ファイルと同じディレクトリに .brim suffix のついたディレクトリができてそこに zng ファイルとメタデータファイルが保存されていたのに今はちょっと違うようだ。今日、しばらくぶりに起動したらアプリの更新が走ってその後データの migration が行われたようだ。今は `~/Library/Application Support/Brim/data/spaces` 配下に作られるみたい。

{{< figure src="brim-01.png" >}}

過去に開いて変換したファイルはずっと残っていて左上のペインにリスト表示されている。不要になったものは右クリックから削除をしておくのが良さそうです。

さて、開いたら検索を行うわけですが、各値のところで右クリックをすると次のようなメニューが表示されます。

{{< figure src="brim-02.png" >}}

ここで `Filter = value` か `Filter != value` を選択するとその条件が上の検索バーに追加されて、その条件に合うものだけの表示にフィルターされます。

`_path = "conn"` を検索条件にしたのが次の画面です。どんどん右クリックで追加していけば AND 条件で絞っていけます。この検索クエリは ZQL (zq log query language) というものです。詳細は[ドキュメント](https://github.com/brimsec/zq/tree/master/zql/docs)を参照ください。

{{< figure src="brim-03.png" >}}

↑これは一行一行が TCP Session です。  
ダブルクリックすると次のようなウインドウが開きます。

{{< figure src="brim-04.png" >}}

この FIELDS に表示されている項目は全てクエリに使えます。

`conn_state` は次のような意味を持っています。ドキュメントは[こちら](https://docs.zeek.org/en/current/scripts/base/protocols/conn/main.zeek.html)。これを検索の条件として使うことでおかしな TCP Session を素早く見つけることができます。

{{< figure src="brim-conn_state.png" >}}

例えば、`conn_state` が `SF` のものは **Normal establishment and termination.** ですから `conn_state!="SF"` で除外すると `S1` と `S3` というのが見つかりました。`S1` は問題ない session ですが、`S3` はまずそうですね、そう、今日はこれを調べていたのです。

{{< figure src="brim-05.png" >}}

(上部の View というボタンで Left Pane, Right Pane の表示・非表示を切り替えられます。Left を消して Right を表示してみました。)

で、ここからが Brim のさらに便利なところなのですが、Session を選択して上の Wireshark ボタンをクリックするとその Session だけを抜き出した pcap ファイルを生成して Wireshark で開いてくれるのです。さらには、2つ、3つと別ウインドウで開くことができるので並べて表示できて超便利なのです！！！

{{< figure src="brim-06.png" >}}

他にも `history` は次のような意味を持っているので、`SYN` を送ったけど `SYN,ACK` が返ってきていないものとか、`SYN` の再送があるものとか、`RST` を含むものとかを探すことができます。

{{< figure src="brim-history.png" >}}

それでは良いパケキャプライフを。
