---
title: 'ngx_http_limit_req_module でリクエストレートをコントロール'
date: Sun, 22 Jan 2017 14:00:25 +0000
draft: false
tags: ['nginx']
---

いつか使いたくなった時のためにメモ。 nginx には [ngx\_http\_limit\_req\_module](http://nginx.org/en/docs/http/ngx_http_limit_req_module.html) というモジュールがあり、リクエストレートをコントロールすることができる。

```nginx
limit_req_zone $binary_remote_addr zone=one:10m rate=1r/s;
```

とすればクライアントのIPアドレス単位でリクエストのレートがコントロールされる

`$binary_remote_addr` は 192.168.1.1 のような文字列として扱うよりもメモリを節約できる。`zone=one:10m` は one という名前で10MBの管理領域を確保する。`rate=1r/s` で `$binary_remote_addr` あたり1秒に1リクエストしか処理しないように制限する。
このルールを使って実際に制限するには **server** 内で `limit_req zone=zone1 burst=1;` などと設定する。**location** で制限する場所を指定することもできる`burst=1` によって同時アクセスが1までであれば r/s で指定したレートに落としてレスポンスを返すようになる。同時に2つ以上のリクエストが来ると `limit_req_status` で設定したコードを返す。デフォルトは 503 (Service Unavailable) を返す。`limit_req_status 429` として 429 (Too Many Requests) を返すのが良いのではないかと思う。
**burst** を設定しない場合は r/s を超える頻度でのアクセスには即座に拒否を返す。
IP アドレスだけでの制限であった場合、通常 HTML から CSS や画像を呼び出すのでこれらは除外しておかないと制限にかかりまくります。redirect で別の path へとか、http から https への redirect でも制限にかかってしまいます。 制限に使用する key は自由に指定可能で、その値が空だった場合は制限がかからない。 IPアドレスだけでは携帯キャリアの proxy を経由したアクセスなどが制限されまくりということになってしまうため、利用者単位で制限をかけられることが望ましい。 アプリが session id を cookie で扱っていればこれを使うことができる。API などにクライアントに識別子を送ってくる場合はそれを使うこともできる。 cookie であれば `$cookie_xxx`, `QUERY_STRING` であれば `$arg_xxx` が使える。
ブラウザがなにかおかしな挙動をして同一 URL に対して大量のアクセスをしてくるものを防ぎたい場合の例。

```nginx
http {
    ...

    limit_req_zone $limit_key zone=zone1:100m rate=5r/s;
    limit_req_status 429;

    upstream backend {
        server ...;
        ...
    }

    server {
        ...

        set $limit_key "";
        # sessionid cookie があれば url + sessionid 単位で
        if ($cookie_sessionid) {
            set $limit_key $cookie_sessionid$uri;
        }

        # さらに xxx パラメータがあればそれも key に追加
        if ($arg_xxx) {
            set $limit_key $cookie_sessionid$uri$arg_xxx;
        }

        location /some/limit/path {
            limit_req zone=zone1 burst=1;
            ...
            proxy_pass  http://backend;
        }
    }
}
```
