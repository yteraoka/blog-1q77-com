---
title: 'Rancher 2.0 サーバーへのサーバー証明書の持ち込み'
date: Sun, 16 Sep 2018 07:38:13 +0000
draft: false
tags: ['Docker', 'Rancher']
---

設定方法は「[Choose an SSL Option and Install Rancher](https://rancher.com/docs/rancher/v2.x/en/installation/single-node/#2-choose-an-ssl-option-and-install-rancher)」に書いてあるわけですが、どうやら最近の Chrome では HTST の設定されたサーバーは自己署名の証明書ではアクセスできないみたいなので [Let's Encrypt](https://letsencrypt.org/) で取得して設定することにします。

{{< figure src="chrome-privacy-error.png" caption="NET::ERR_CERT_AUTHORITY_INVALID" >}}

Rancher サーバーは docker container として実行するので、証明書取得も docker を使いましょう。Single ノードでの方法です

### rancher での証明書指定方法

rancher は `/etc/rancher/ssl/cert.pem`, `/etc/rancher/ssl/key.pem` に置かれたものを使うので、docker container 起動時に `-v /host/file/path:/etc/rancher/ssl/cert.pem:ro` などどしてマウントしてやれば良い。 そして `--no-cacerts` オプションを追加して自前 CA を作成しないようにします。

### lego を使って証明書を取得

```bash
docker run \
  --rm \
  -v /etc/rancher:/etc/rancher \
  -p 80:80 \
  xenolf/lego \
    --path /etc/rancher \
    --domains "証明書のドメイン名" \
    --email "自分のメールアドレス" \
    --filename server \
    --accept-tos run
```

これで、`/etc/rancher/certificates/server.crt`, `/etc/rancher/certificates/server.key` が生成されます。（他のファイルもある） 上記のコマンドは `http-01` ですが、[lego](https://github.com/xenolf/lego) は dns-01 や tls-alpn-01 にも対応しています。

### rancher 起動

```bash
docker run -d --restart=unless-stopped -p 80:80 -p 443:443 \
  -v /etc/rancher/certificates/server.crt:/etc/rancher/ssl/cert.pem \
  -v /etc/rancher/certificates/server.key:/etc/rancher/ssl/key.pem \
  rancher/rancher:v2.0.8 --no-cacerts
```

これで Chrome でもアクセスできる。

プライベートなドメインの場合は CA 作って `/etc/rancher/ssl/cacerts.pem` も置いて、ブラウザにも登録しましょう。
