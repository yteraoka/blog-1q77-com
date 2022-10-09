---
title: 'Google Home に Amazon Polly の声で喋らせる'
date: Mon, 21 Oct 2019 16:07:07 +0000
draft: false
tags: ['Ubuntu']
---

先日、[go-chromecast で Google Home Mini に任意のメッセージを喋らせる](/2019/10/google-home-mini-and-text-to-speech/) で Google Home に Google の [Text-to-Speech](https://cloud.google.com/text-to-speech/) を使って任意のメッセージを喋らせましたが、Google のサービスには日本語の声色が1種類しかなく楽しくありません。そこで、Amazon Polly にも喋ってもらうことにしました。

また [go-chromecast](https://github.com/vishen/go-chromecast) に手を入れても良いのですが、[Amazon Polly](https://aws.amazon.com/jp/polly/) は awscli でも簡単に音声ファイルを取得可能だったので、shell script でさくっと試しました。Polly は日本語でも女性の声と男性の声の2種類がありました。（いまのところ、しゃべりの滑らかさは Google の方が良さそうです）

[awscli](https://aws.amazon.com/jp/cli/) でテキストから音声ファイルを作成するには次のように実行するだけです。voice-id は女性なら `Mizuki` を、男性なら `Takumi` を指定するだけです。

```
aws polly synthesize-speech \\
    --output-format mp3 \\
    --voice-id $voice\_id \\
    --text "$message" \\
    voice.mp3

```

こうして作成した音声ファイルを再生するには、次のように load サブコマンドを実行するだけです

```
go-chromecast load \\
  /some/where/audio.mp3 \\
  -n $NODE\_NAME -i $INTERFACE

```

次は LINE Bot を使って外から喋らせようかなと。固定電話をやめたら外から家族に電話しても気付けなかったりするので「電話に出てね」と喋らせるのは有効なんじゃないかと思ってる。

と書いた後で、これは Google Home アプリを使えば外出先からもブロードキャスト機能が使えるし、家族を招待することが出来ることに気付いた。