---
title: '「OK Google, おはよう」で TimeTree の予定を教えてもらう'
date: Sat, 30 May 2020 04:24:43 +0000
draft: false
tags: ['Home']
---

タイトルの通りです。家の予定は [TimeTree](https://timetreeapp.com/) で共有しておりまして、我が家には Google Home mini も Amazon Echo Dot もあるわけですが、Google はもちろん Google Calendar ですし、Alexa も Google, Microsoft, Apple のカレンダーとのリンクしかサポートしていません。TimeTree と連携させてもわざわざ「**TimeTree につないで今日の予定を教えて**」なんて言わないといけないわけで、使っていませんでした。Google Home や Alexa のアプリってこんな感じで呼び出す必要があって呼び出し方覚えられねーよって感じ。

それでも毎朝、今日の予定くらいは読み上げて欲しいなと思ってました。[TimeTree の API](https://developers.timetreeapp.com/ja/docs/api) はしばらく前に公開されてて、今は予定の取得も可能になっていました。（公開当初は予定の取得ができなくてなんじゃコレって思ってました）。これを使って定期的に予定を取ってきて Google cast で喋らせればいいんじゃないかと思ってコードを書きかけていましたが、ふと Google Home のルーチン機能を思い出して調べてみたら任意の操作を登録できるし、TimeTree アプリも存在したのでこの設定を行うことにしました。

TimeTree を Google Home から呼び出せるようにするための設定は「[Google Home連携](https://support.timetreeapp.com/hc/ja/articles/900000322166-Google-Home%E9%80%A3%E6%90%BA)」で説明されています。Google Home のルーティン設定は「[ルーティンの設定と管理](https://support.google.com/googlenest/answer/7029585?co=GENIE.Platform%3DAndroid&hl=ja)」にあります。

* * *

{{< figure src="google-nest-timetree-01.png" >}}


Google Home アプリ ([Android](https://play.google.com/store/apps/details?id=com.google.android.apps.chromecast.app&hl=ja), [iOS](https://apps.apple.com/jp/app/google-home/id680819774))を起動して「ルーティン」をタップします。

* * *

{{< figure src="google-nest-timetree-02.png" >}}

「**おはよう**」を選択します。「**おやすみ**」とかで明日の予定を確認するのも良いかもしれません。

* * *

{{< figure src="google-nest-timetree-03.png" >}}

デフォルトでは他にも選択されていた気がしますが私は天気予報が聞ければ良いので、それだけ選択して、後は TimeTree を追加するために「**＋ 操作の追加**」をタップします。

* * *

{{< figure src="google-nest-timetree-04.png" >}}

「**TimeTree につないで今日の予定を教えて**」と入力して右上の「追加」をタップ。

* * *

{{< figure src="google-nest-timetree-05.png" >}}

コレで「保存」すれば完成です。「**Ok Google, おはよう**」と話しかけてみましょう。

* * *

タイマーと天気予報以外に使い道ができてめでたしめでたし・・・

ところで、Google Home なの？ Google Nest なの？

（まあ、TimeTree じゃなくて Google Calendar 使えば良いんですけどねぇ、共有だってできるし）
