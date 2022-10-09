---
title: 'ワンライナーで https の Reverse Proxy を実行する'
date: Wed, 19 Aug 2020 16:31:46 +0000
draft: false
tags: ['Caddy', 'TLS']
---

ローカルで使うための https な Reverse Proxy が欲しい
-------------------------------------

Kubernetes で実行している Web サービスにて対して kubectl port-forward でアクセスすることが良くありますが、そのサービスが Cookie を使っており、secure フラグが必須となっている場合があります。大変面倒です。便利な Reverse Proxy サーバーがないものかと探しました。nodejs で書かれた [local-ssl-proxy](https://www.npmjs.com/package/local-ssl-proxy) は見つかりましたが、私は nodejs が好きじゃないのでこれをローカルには入れたくありません。Docker で動かすにしても mac なので docker から host の localhost にアクセスするにはどうすれば良いのでしょう？調べるのも面倒です...

**追記**  
Docker on Mac, Docker on Windows の場合、 `host.docker.internal` という名前で Host にアクセスすることができます。Host 側で loopback device (127.0.0.1, ::1) しか bind していなくてもアクセス可能でした。でも、先の [local-ssl-proxy](https://www.npmjs.com/package/local-ssl-proxy) は proxy 先のホストを自由に指定できないので使えそうにない。

思い出した
-----

Go で書かれたシングルバイナリのものとかないかな、なかったら自分用に書こうかななんて思っていた時、思い出しました。[Caddy](https://caddyserver.com/) です。[このブログでも 2017 年に紹介しました。](/2017/04/caddy/) 当時のライセンスの影響か、広く普及はしませんでしたがまだ死んでいません。

Mac の homebrew でインストール可能です。

ワンライナーで Reverse Proxy
---------------------

[サイト](https://caddyserver.com/) にもある通り、Production Ready な Reverse Proxy がたったこの1行で起動するんですって！！ ステキですね、望んでいたやつですね。

```
$ caddy reverse-proxy --from example.com --to localhost:9000

```

で、実際にこれを実行すると example.com の証明書を Let's Encrypt の TLS-ALPN-01 や HTTP-01 で取得しようとします。公開サーバーで使うなら必要ですが、ローカルではそれは望んでいないんですよね。

そこで、from 指定をやめてみると localhost 用の証明書を作ってくれました。

```
$ caddy reverse-proxy --to localhost:9000
```

certutil が無いよと言われたら `brew install nss` でインストールしましょう。

```
Warning: "certutil" is not available, install "certutil" with "brew install nss" and try again
```

Mac では証明書などは `~/Library/Application Support/Caddy` 配下にファイルとして保存されます。また root 証明書として Keychain や Java の keystore、 Firefox に保存しようとします。これを削除したい場合は [`caddy untrust`](https://caddyserver.com/docs/command-line#caddy-untrust) コマンドを実行すれば良いみたいです。

```
$ find ~/Library/Application\ Support/Caddy -type f
/Users/teraoka/Library/Application Support/Caddy/certificates/local/localhost/localhost.crt
/Users/teraoka/Library/Application Support/Caddy/certificates/local/localhost/localhost.json
/Users/teraoka/Library/Application Support/Caddy/certificates/local/localhost/localhost.key
/Users/teraoka/Library/Application Support/Caddy/autosave.json
/Users/teraoka/Library/Application Support/Caddy/pki/authorities/local/root.crt
/Users/teraoka/Library/Application Support/Caddy/pki/authorities/local/intermediate.key
/Users/teraoka/Library/Application Support/Caddy/pki/authorities/local/root.key
/Users/teraoka/Library/Application Support/Caddy/pki/authorities/local/intermediate.crt
```

autosave.json は Caddy 用の設定ファイルで Reverse Proxy 設定が保存されています。

証明書の情報は次のようになっていました。

```
# root.crt

Issuer: CN=Caddy Local Authority - 2020 ECC Root
Validity
    Not Before: Aug 19 05:41:08 2020 GMT
    Not After : Jun 28 05:41:08 2030 GMT
Subject: CN=Caddy Local Authority - 2020 ECC Root
```

```
# intermediate.crt

Issuer: CN=Caddy Local Authority - 2020 ECC Root
Validity
    Not Before: Aug 19 05:41:08 2020 GMT
    Not After : Aug 26 05:41:08 2020 GMT
Subject: CN=Caddy Local Authority - ECC Intermediate
```

```
# localhost.crt

Issuer: CN=Caddy Local Authority - ECC Intermediate
Validity
    Not Before: Aug 19 14:37:39 2020 GMT
    Not After : Aug 20 02:38:39 2020 GMT
Subject: 
...
    X509v3 Subject Alternative Name: 
        DNS:localhost
```

SNI が必須なので openssl コマンドでは `-servername` オプションが必要です。 (ちゃんと設定ファイルを書くなら `default_sni` という設定もある)

```
$ openssl s_client -connect localhost:443 -servername localhost -showcerts
```

curl でアクセスするには `-k` / `--insecure` をつけるか `--cacert` で root.crt を指定します。

```
$ curl --cacert "/Users/teraoka/Library/Application Support/Caddy/pki/authorities/local/root.crt" https://localhost/
```

肝心のブラウザからのアクセスですが、Keychain に root 証明書として登録されているけど Chrome はアクセスを認めてくれませんし、Firefox でも警告が出ます 😢

数ヶ月後、再度試してみたところ警告は出なくなっていました。警告が出る場合はキーチェーンアクセスを開いて Caddy Local Authority が信頼されているかどうかを確認します。Caddy Local Authority をダブルクリックで開いて**信頼**セクションを開いて SSL が「常に信頼」となっていることを確認します。なっていなければ変更します。

その他、証明書に関する情報は [Automatic HTTPS](https://caddyserver.com/docs/automatic-https) ページに書かれています。

localhost 以外で証明書を自動発行させる方法
--------------------------

これまでの情報で localhost や 127.0.0.1 に対しては intermediate.crt を使って証明書を発行してくれることがわかりましたが、実際にサービスで使っているドメインを使用したい場合もあります。

どうするか

`caddy reverse-proxy` コマンドを諦めて、設定ファイルを書きます。

でも非常に簡単です。例えば、caddy.1q77.com というドメインを使い、localhost:8080 に Proxy したい場合は次のように任意のファイルに書くだけです。ここではファイル名は Caddyfile とします。

```
caddy.1q77.com

tls internal
reverse_proxy localhost:8080
```

これを使って起動させるには `caddy run` コマンドを使います。background で実行したい場合は `caddy start` とします。

```
$ caddy run --config Caddyfile
```

別で発行した証明書を使いたい場合
----------------

せっかく任意のドメインでも証明書が発行できるようになったのですが、やはり Chrome と Safari は中間証明書が信用ならんと言ってアクセスさせてくれません... この件はまた後日調査する

これでは困るので別途取得済みの証明書を使う方法です。[lego](https://github.com/go-acme/lego) を使い、 Let's Encrypt の DNS-01 で取得したものを使ってみます。これも簡単で設定ファイルに次のように書くだけです。

```
caddy.1q77.com

tls /Users/teraoka/.lego/certificates/caddy.1q77.com.crt /Users/teraoka/.lego/certificates/caddy.1q77.com.key
reverse_proxy localhost:8080
```

起動方法は先ほどと同じ。ドキュメントは[こちら(tls)](https://caddyserver.com/docs/caddyfile/directives/tls)。マルチドメインで Proxy したい場合は `{}` を使った構文にする必要があります。[ドキュメント](https://caddyserver.com/docs/caddyfile/concepts)を参照してください。

Caddy 内での証明書発行には [https://smallstep.com/certificates/](https://smallstep.com/certificates/) が使われているみたいです。

ではでは、良いローカル開発ライフを！
