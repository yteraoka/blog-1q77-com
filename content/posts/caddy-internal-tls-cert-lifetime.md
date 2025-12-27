---
title: "Caddy の Internal TLS 証明書の有効期間を指定する"
date: 2023-02-09T23:29:32+09:00
draft: false
tags: ["TLS", "Caddy"]
---

以前 [ワンライナーで https の Reverse Proxy を実行する](/2020/08/one-liner-https-reverse-proxy-caddy/) という記事で [Caddy](https://caddyserver.com/) を使うと local での開発用に任意のドメインの証明書を簡単に発行できるし CA の証明書も OS の証明書ストアに保存してくれるため、ブラウザでアクセスしても警告が出なくて便利というのを書きました。

その証明書を Caddy 以外で使いたくなった際のメモです。

次の内容で `Caddyfile` というテキストファイルを作成します。`reverse_proxy` 行の localhost:8080 はなんでも良いです。アクセスできなくても問題なし。

```
www.example.com, www.example.net, www.example.org
tls {
  issuer internal {
    lifetime 30d
    sign_with_root
  }
}
reverse_proxy localhost:8080
```

作成した `Caddyfile` を指定して caddy コマンドを実行します。

```bash
caddy --adapter caddyfile --config Caddyfile
```

初回であれば CA の証明書を登録するために認証を求められますが、これだけで完了です。

macOS であれば `~/Library/Application Support/Caddy/certificates/local/` 配下に秘密鍵と証明書が作成されているはずです。他の OS の data directory は[ドキュメント](https://caddyserver.com/docs/conventions#data-directory)を参照。

上記の `Caddyfile` では3つのドメインを指定したので3組できているはずです。

デフォルトでは証明書の有効期限が12時間で作成されるのですが、手元の VM 内など他の場所にコピーして使うにはちょっと短すぎて不便です。

上記の `Caddyfile` を見ればなんとなくわかりますが `lifetime 30d` と指定していることで有効期限を30日にしています。

ただし、`lifetime` を設定だけでは7日までしか延ばせませんでした。Caddy はデフォルトで root 証明書で署名された中間証明書を使ってサーバー証明書に署名するのですが、この中間証明書の有効期限が7日であるためこれを超えて期間を延ばすことができませんでした。

そこで出てくるのが `sign_with_root` 設定です。これがあることで中間証明書ではなく root 証明書で署名されます。root 証明書は作成から 3600 日間有効となっていたため30日間有効な証明書を発行することができました。

- [tls (Caddyfile directive) — Caddy Documentation](https://caddyserver.com/docs/caddyfile/directives/tls)
- [github.com/caddyserver/caddy](https://github.com/caddyserver/caddy)
