---
title: "iPhone の通信を覗く"
date: 2022-10-14T22:10:09+09:00
draft: false
tags: ['tcpdump', 'iPhone']
---

先日 iPhone のアプリが https で通信している内容を覗いてみようと HTTP プロキシに [OWSAP ZAP](https://www.zaproxy.org/) を指定して覗いてみました。
OWASP ZAP が動的に証明書を発行してくれるので、その発行元となる CA を iPhone に登録しておけば HTTP 通信も中身を覗くことができます。(アプリで Certificate Pinning とかされていなければ)

Pinning といえば [CAA (Certificate Authority Authorization)](https://www.rfc-editor.org/rfc/rfc8659) っていう DNS レコードもありますね。(余談)

で、今回やりたいことは HTTP に限らず iPhone の通信の中身を覗きたいということです

ルーターとかで packet をキャプチャするとか mirror port を使うとかいう手もありますが、ググってみると mac と Lightling ケーブルで接続すれば簡単に tcpdump や wireshark で覗けるようです


## XCode のインストール

rvictl というコマンドを実行する必要があるのですが、これが XCode に含まれているため XCode がインストールされていない場合は
[Apple のサイト](https://developer.apple.com/download/all/) からダウンロードしてインストールします

`/Library/Apple/usr/bin/rvictl` にインストールされました


## System Integrity Protection (SIP) を無効にする

今回の環境は次の通り

- Intel 版 MacBook Pro (16-inch, 2019)
- macOS Monterey (12.6)
- iPhone SE2 (iOS 16)

この環境では System Integrity Protection とやらを無効にしないと仮想ネットワークデバイスの作成ができませんでした

1. mac をリカバリモードで起動する (起動時に `Command + R`)
2. Utilities メニューから Terminal を起動する
3. `csrutil disable` コマンドを実行
4. OS 再起動

[Disabling and Enabling System Integrity Protection](https://developer.apple.com/documentation/security/disabling_and_enabling_system_integrity_protection)


## iPhone の UUID 確認

iPhone を mac と接続したら Finder を開き `場所` にある iPhone を開き、iPhone の名前が表示されている下の部分

iPhone のモデル名とかストレージ容量などが表示されている場所をクリックします、クリックする度に表示内容が切り替わります

{{< figure src="finder-iphone.png" >}}

UUID が表示されたら二本指タップで `UUID をコピー`  を選択します


## 仮想 Network Device を作成する

先ほど確認した UUID を rvictl -s の引数で指定して実行することで

```
$ rvictl -s 00001234-0123456789ABCDEF
```

次のように出力されれば成功です

```
Starting device 00001234-0123456789ABCDEF [SUCCEEDED] with interface rvi0
```

インターフェースの確認

```
$ rvictl -l

Current Active Devices:

	[1] 00001234-0123456789ABCDEF with interface rvi0
```

```
$ ifconfig rvi0
rvi0: flags=3005<UP,DEBUG,LINK0,LINK1> mtu 0
```


## tcpdump で確認

tcpdump で確認できます

```
sudo tcpdump -i rvi0
```

[Wireshark](https://www.wireshark.org/) も [Brim](/2020/12/brim-introduction/) も便利です


## 仮想 Network Device の削除

```
rvictl -x 00001234-0123456789ABCDEF
```


## System Integrity Protection (SIP) を有効に戻す

無効にしたのと同じ手順で `csrutil enable` を実行する
