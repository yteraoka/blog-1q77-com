---
title: 'Nginx で API Management'
date: Sat, 08 Jun 2019 06:39:35 +0000
draft: false
tags: ['nginx']
---

「[NGINX Tokyoハッピーアワー - API：インテリジェントルーティング、セキュリティと管理](https://www.eventbrite.com/e/nginx-tokyo-api-registration-61778490127)」というイベントがありまして

* API作成、バックエンド基盤のセキュリティ保護、トラフィック管理、継続的モニタリンングなど、万全なライフサイクル管理におけるすべての要素について
* APIコールの処理にマイクロゲートウェイの追加を必要としない革新的なアーキテクチャについて

という内容に惹かれて参加してきました。NGINX さん主催ですから製品紹介ではあるのですが、”なるほど、言われてみればそうだわ” という気づきがあったので、OSS 版でも使える API 管理設定をメモっておきます。内容は [NGINX Controller](https://www.nginx.co.jp/products/nginx-controller/) という製品の GUI を使ったデモから**私が想像した設定**です。

### NGINX Controller による API Management

NGINX Controller には [API Management Module for NGINX Controller](https://www.nginx.co.jp/products/nginx-controller/api-management/) というモジュールがあり

* 1\. APIの定義と公開
* 2\. レート制限
* 3\. 認証と権限付与
* 4\. リアルタイムのモニタリングとアラート作成
* 5\. ダッシュボード

という機能をもち、NGINX Controller で管理する複数の NGINX サーバーを一つの管理コンソールから管理できます（設定の配布は管理される側に入れた Agent が pollling します）。これを OSS 版でやろうと思うと、**1** の「APIの定義と公開」は Reverse Proxy 設定ですから特に問題ないですね（NGINX Plus であればアクティブヘルスチェックとか DNS キャッシュの更新ができて便利ではある）。**2** の「レート制限」は [ngx\_http\_limit\_req\_module](http://nginx.org/en/docs/http/ngx_http_limit_req_module.html) で実現可能です。**3** の「認証と権限付与」は任意のヘッダーの値でアクセスを許可したり、JWT での許可設定が可能というものでした。JWT は [njs](https://nginx.org/en/docs/njs/) か [lua-nginx-module](https://github.com/openresty/lua-nginx-module) を使えばできそうではありますがこの記事ではパス。**4**, **5** は Prometheus + Grafana とかかな。ここでは **3** の「認証と権限付与」の設定について OSS 版でどのように設定すると良さそうかを試してみます。**2** のレート制限については以前「[ngx\_http\_limit\_req\_module でリクエストレートをコントロール](/2017/01/ngx_http_limit_req_module/)」という記事を書きました。また「[Rate Limiting with NGINX and NGINX Plus](https://www.nginx.com/blog/rate-limiting-nginx/)」にも詳しい説明がありました。

### API Key をうまく管理する

複数の API Key を発行する場合、`if` 文を並べるのは良くありません。[If Is Evil](https://www.nginx.com/resources/wiki/start/topics/depth/ifisevil/) です。こういう場合は [map](http://nginx.org/en/docs/http/ngx_http_map_module.html) が使えます。

```nginx
map $http_api_key $api_client_name {
    ad6621ea-9632-4fdd-9fb4-64a2a191c9e0 blue;
    2c202c32-b33f-4de2-9d46-60c2509e67ef red;
    990e1f99-35e5-4d5c-a019-5e8f940a84db green;
    2bcbd78f-bf28-4c3c-90d4-64cf8008f982 green;
}

if ($api_client_name = "") {
    return 403;
}
```

上記のように設定することで `map` で定義済みの `API-KEY` ヘッダーが送られてきた場合のみアクセスを許可することが可能です。`blue`, `red`, `green` は任意の名前ですが、ここをうまく使えばクライアントを識別することが可能です。`log_format` で `$api_client_name` をログに出力するように設定も可能です。また、右辺は重複可能ですから API-KEY のローテーションも可能です。

注意点として `map` は http コンテキストにしか書けないため virtual host 単位で別に設定することはできません。map する変数名を別にすることは可能です。また、正規表現を使わない場合のマッチングは case-insensitive です。

### API Key ごとにレート制限する

先の設定に加え、次のように設定することで $api\_client\_name ごとに秒間5リクエストまでに制限することがかのうです。burst とか delay といった設定もありますが、それは上にあるリンクを参照してください。複数台の NGINX を並べる場合、アクセスの振り分け方法によっては全体ではこの制限を超えることが可能ですが、要件によってはそれは問題ではないかもしれません。

```nginx
limit_req_zone $api_client_name zone=zone1:100m rate=5r/s;
limit_req_status 429;
limit_req zone=zone1
```

### まとめ

API Management というと [Kong](https://github.com/Kong/kong) などを導入する必要があると思い込んでしまっていましたが、要件によっては今回書いたような設定で問題ないですし、ずっとシンプルです。思い込みは怖いですね。「あー、これを API Management と呼んでも良かったんだ！！」というのが今回の収穫（気付き）です。NGINX さんありがとうございました。

Tシャツもいただきました！！ありがとうございます。前に SIOS さんからもらった紺色のやつもまだ部屋着として着てます。
<img src="nginx-t-shirt.jpg">

<div style="clear:both"></div>
