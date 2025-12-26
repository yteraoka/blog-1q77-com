---
title: 'Asterisk のハンズオンに参加してきた'
date: Sat, 12 Apr 2014 14:22:36 +0000
draft: false
tags: ['Asterisk', 'IP電話', 'Linux', 'SIP']
---

「[クラウドでIP電話サーバを動かそう！ハンズオン](http://asterisk-on-vps.doorkeeper.jp/events/9715)」に参加してきました。 講師の皆様お疲れ様でした。 参加者にはさくらのクラウド20,000円分のクーポンが配られました。さくらインターネットさん、横田さんありがとうございました。 そのクーポンを使ってさくらのクラウドで Asterisk を動かして、IP電話を使ってみようという内容でした。 [Asterisk](http://www.asterisk.org/) ([Wikipedia](http://ja.wikipedia.org/wiki/Asterisk_(PBX))) の存在はかなり前から知ってはいましたが、実際に試してみたことはありませんでした。触ってみたいなとは思っていたので『おぉ、これはちょうど良い機会』と思って参加してみました。 VPS やクラウドがなかった時代にはこういうハンズオンは難しかったですよねぇ。 IP電話もあたりまえの時代で、ハードの所有なしに外線の発着もできます。スマホがIP電話端末になりますし。 今回の内容

1.  [FUSION IP Phone SMART](http://ip-phone-smart.jp/) に signup (外線発着用SIPアカウントの取得)
    *   このサービスは月額基本料金が不要なので
    *   ISPの提供しているIP電話を契約済みでそのSIP情報がわかっていればそれを使うことも可能なのかも ([Wikipedia](http://ja.wikipedia.org/wiki/Asterisk_(PBX))にはひかり電話でもできそうなことが書いてある)
2.  [さくらのクラウド](http://cloud.sakura.ad.jp/)アカウントの取得
3.  さくらのクラウドで CentOS 6.5 サーバーをセットアップ
    *   さくらさん CentOS 6.5 のイメージの OpenSSL が古かったよ〜
4.  Asterisk のインストール
    *   インストール手順はほぼ[Asterisk 11](http://www.voip-info.jp/index.php/Asterisk_11)に書いてあるとおり
    *   サンプルのコンフィグファイルが多すぎてビビりました!!
        
        > $ ls /etc/asterisk/\*.conf | wc -l 98 え...
        > 
        > — yteraoka (@yteraoka) [April 12, 2014](https://x.com/yteraoka/statuses/454861001964285952)
        
        でも実際に使ったのはファイル2つだけで内容もシンプルなものでした
5.  PC のソフトフォンとスマホのIP電話アプリで内線通話を行う
    *   私の PC は　Linux Mint で 配られた資料に Linux 用のソフトフォン情報はなかったので VirtualBox に Windows を入れて [X-Lite](https://www.counterpath.com/x-lite.html) を使ってみたものの、発着信音は出るのに通話の音がでない...
    *   [zoiper](http://www.zoiper.com/en) が Linux 対応してたのでこれでイケました
    *   iPhone でも [zoiper](https://itunes.apple.com/us/app/zoiper-softphone/id438949960?mt=8) を使いました
    *   おぉ!!とっても簡単にスマホでの無料通話が!!
6.  FUSIONのSIPアカウントで外線発信、外線の着信を指定の端末に転送
    *   FUSIONの050番号に着信した電話を指定のSIPアカウントに転送する
    *   ソフトフォンからFUSIONの050番号で一般の電話に発信する
    *   ただ、スマホから050で発信したいだけならスマホアプリだけでできますけどね

資料が公開されたら誰でも簡単に試せそう。 PBX とはなにか、Asterisk で何ができるのかの説明もありました。 参考資料「[入門ガイド コールセンターのシステムを基礎から解説](http://www.callcenter-japan.com/sswr/guide/detail.php?no=19)」 [FreePBX](http://www.voip-info.jp/index.php/FreePBX) という Asterisk のウェブインターフェースがあるそうです。Schmoozeとパートナー契約をしている日本の株式会社クルーグが正式な日本語版をリリースしたそうです。 講師をされた方の会社の紹介 http://www.youwire.jp/ 懇親会には参加できなかったのですが、参加できてたら @nouphet さんに OTRS の話を聞いてみたかった。
