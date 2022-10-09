---
title: 'go-chromecast で Google Home Mini に任意のメッセージを喋らせる'
date: Mon, 07 Oct 2019 15:37:20 +0000
draft: false
tags: ['Go', 'GoogleHome']
---

[Google Home Mini](https://store.google.com/jp/product/google_home_mini) に任意のメッセージを喋らせる OSS は昔からいくつかあるし、過去にそれをいじってブラウザから任意のメッセージを与えて喋らせるアプリを書いたりもしていました（go の source code を紛失）が、今回は cron などで目覚まし時計代わりに使おうと思って Google の [Text-to-Speech](/2018/08/google-text-to-speech-golang/) 使って何か書こうかなって思ったわけですが、[go-chroemcast](https://github.com/vishen/go-chromecast) が良くできていたので、これをいじって遊びました。私に必要だったコードは Pull Request しておきました。Merge してもらいました。

私の感じる go-chromecast の良い点は、デバイスを名前や UUID で指定できること。mDNS で探して名前で選んでくれます（デバイス名を日本語（マルチバイト）にしていると対応できない、使いたかったらプルリクしましょう）。未指定だと一覧を表示して選択を求められます。

### ハマった点

go-chromecast は一時的に HTTP サーバーを立ち上げて、Google Home にその URL を伝えてメディアファイルをダウンロードさせるわけですが、Network Interface が複数ある場合はどの Interface を Listen させるかを指定してあげないと、Google Home からアクセスできなくて再生させられません。我が家のラズパイは VPN サーバーとしても使っているため、この VPN で払い出すサブネットのIPアドレスを Listen してることに気づかずにしばらくハマりました。でもちゃんと Interface 名を指定するオプションがありました。すばらしい。

### いじった点

Text-to-Speech が使えるようはなっていたのですが、言語が en-US 固定だったので、コマンドラインオプションで指定可能にしました。また、[gocui](https://github.com/jroimartin/gocui) を使った [ui](https://github.com/vishen/go-chromecast#user-interface) からでないと volume のコントロールができなかったので volume コマンドを追加しました。

次のようにして喋らせることができるようになりました。

```
#!/bin/bash

NODE_NAME=Bedroom
INTERFACE=wlan0
MESSAGE="起きてください、遅刻します"

volume=$(go-chromecast -n $NODE_NAME volume)

go-chromecast -n $NODE_NAME volume 0.8

go-chromecast tts \
  "$MESSAGE" \
  --google-service-account ~/account.json \
  --language-code ja-JP \
  -n $NODE_NAME -i $INTERFACE

go-chromecast -n $NODE_NAME volume $volume
```

### 課題

声が味気ない・・・。でも [go-chroemcast](https://github.com/vishen/go-chromecast) は音声ファイルを再生させることもできるので、目覚ましボイスを YouTube で探そうかなと思ってます。ちらっと見てたら「世にも奇妙な物語」のテーマが出てきました、ひどく恐ろしい寝起きとなりそうです 😱

息子が目覚ましかけないから、面白メッセージで起こしてやろうとしてるのに嫌だと言って Google Home Mini の電源を切ってしまうのが一番の問題...

### おまけ

```
$ go-chromecast
Control your Google Chromecast or Google Home Mini from the
command line.

Usage:
  go-chromecast [command]

Available Commands:
  help        Help about any command
  load        Load and play media on the chromecast
  ls          List devices
  next        Play the next available media
  pause       Pause the currently playing media on the chromecast
  playlist    Load and play media on the chromecast
  previous    Play the previous available media
  restart     Restart the currently playing media
  rewind      Rewind by seconds the currently playing media
  seek        Seek by seconds into the currently playing media
  status      Current chromecast status
  stop        Stop casting
  tts         text-to-speech
  ui          Run the UI
  unpause     Unpause the currently playing media on the chromecast
  volume      Get or set volume
  watch       Watch all events sent from a chromecast device

Flags:
  -a, --addr string          Address of the chromecast device
      --debug                debug logging
  -d, --device string        chromecast device, ie: 'Chromecast' or 'Google Home Mini'
  -n, --device-name string   chromecast device name
      --disable-cache        disable the cache
  -h, --help                 help for go-chromecast
  -i, --iface string         Network interface to use when looking for a local address to use for the http server
  -p, --port string          Port of the chromecast device if 'addr' is specified (default "8009")
  -u, --uuid string          chromecast device uuid
      --with-ui              run with a UI

Use "go-chromecast [command] --help" for more information about a command.
```

### Amazon Polly (追記)

GCP の Text-to-Speech には日本語の声の種類がひとつしかなく、機械っぽい声なので楽しくありません。AWS には [Amazon Polly](https://aws.amazon.com/jp/polly/) というサービスがあり、こちらには男女1つずつの声がありました。（結局のところどっちも残念な感じであったが）

Amazon Polly は awscli でも簡単に音声ファイルを取得することが可能です。**Mizuki** が女性で **Takumi** が男性の声です。

```
aws polly synthesize-speech \
    --output-format mp3 \
    --voice-id Mizuki \
    --text 'テストです' \
    mizuki.mp3

aws polly synthesize-speech \
    --output-format mp3 \
    --voice-id Takumi \
    --text 'テストです' \
    takumi.mp3
```

音声ファイルが生成できたら go-chromecast の load コマンドで再生させることが可能です。

```
go-chromecast load /path/to/mizuki.mp3 -n $NODE_NAME -i $INTERFACE
```
