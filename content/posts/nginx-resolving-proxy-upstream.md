---
title: 'nginx proxy の名前解決問題、ファイナルアンサー？'
date: Thu, 17 Mar 2016 15:10:12 +0000
draft: false
tags: ['nginx']
---

自分の理解を整理できたのでメモ nginx を次のような設定で reverse proxy とした場合、起動時に名前解決した `upstream.example.com` の IP アドレスをずっと使い続けるため、IP アドレスが変更されるとアクセスできなくなってしまいます。 proxy 先が AWS の ELB だったりすると頻繁に IP アドレスが変わるためすぐに問題が顕在化します。

```nginx
location / {
    proxy_pass http://upstream.example.com;
}
```

よくある問題なのでググると解決方法の書かれたサイトが沢山出てきます。
proxy 先のホスト名を変数にセットして使えば良いというものもあれば、`$request_uri` と `resolver` 設定の `valid` を短く設定しろというものなど。

```nginx
resolver 192.168.0.1 192.168.0.2;
set $upstream_server upstream.example.com;
location / {
    proxy_pass http://$upstream_server;
}
```

```nginx
resolver 192.168.0.1 192.168.0.2 valid=30s;
location / {
    proxy_pass http://upstream.example.com$request_uri;
}
```

パターン1の設定でも DNS の TTL に合わせて問い合わせが発生するので ELB の自動的な IP アドレス変更であれば resolver に短い valid 設定をする必要はない。予期せぬ IP アドレスの変更への対応が必要であれば短くしておくに越したことはない。 パターン2でも valid で指定した時間を超えると DNS への問い合わせが発生するためホスト名を変数にする必要はない。nginx がリクエストに対して設定する変数を使うことでも良い。 よって次のように書くことでも TTL にしたがって DNS への問い合わせてくれます。だた、https で受けて http で proxy するといった場合には困ります。

```nginx
resolver 192.168.0.1 192.168.0.2;
location / {
    proxy_pass $scheme://upstream.example.com;
}
```

`proxy_pass` に変数を使うことで困るのは /foo/var.html へのアクセスを /var.html へ proxy するといった場合です。変数を使わない場合は次のように書けますが、

```nginx
location /foo/ {
    proxy_pass http://upstream.example.com/;
}
```

変数を使うと /foo が削られないまま proxy されてしまいます。こんな場合は

```nginx
location /foo/ {
    rewrite ^/foo(/.*) $1 break;
    proxy_pass $scheme://upstream.example.com;
}
```

または

```nginx
location /foo/ {
    rewrite ^/foo(/.*) $1 break;
    proxy_pass http://upstream.example.com$uri;
}
```

とすることで実現できます。`$request_uri` は `rewrite` では書き換わらないので注意。 `resolver` を忘れずに。`valid` はお好みで。 結局のところ、ホスト名を変数に入れるのが一番わかりやすいのかな？ ※ 2016/09/01 追記 `upstream` を使った場合は効かなかった...

```nginx
upstream backend {
  server be1.example.com;
  server be2.example.com;
  server be3.example.com;
}
```

などとし

```nginx
location / {
  proxy_pass http://bakcend;
}
```

とした場合は `proxy_pass` の値に変数を入れてもダメでした... `balancer_by_lua` というのが使えるようだ [Nginx balancer\_by\_luaの話とupstream名前解決の話](http://qiita.com/toritori0318/items/a9305d528b52936c0573)
[![](//ws-fe.amazon-adsystem.com/widgets/q?_encoding=UTF8&ASIN=4774178667&Format=_SL160_&ID=AsinImage&MarketPlace=JP&ServiceVersion=20070822&WS=1&tag=ytera-22)](https://www.amazon.co.jp/nginx%E5%AE%9F%E8%B7%B5%E5%85%A5%E9%96%80-WEB-DB-PRESS-plus/dp/4774178667/ref=as_li_ss_il?_encoding=UTF8&pd_rd_i=4774178667&pd_rd_r=062ZRMCDATPXQFGFDNPS&pd_rd_w=0kpVG&pd_rd_wg=xgz4R&psc=1&refRID=A0EGF8Q7JT9W61M466QR&linkCode=li2&tag=ytera-22&linkId=4840d637b7e902c7df91072454fa22f6)![](https://ir-jp.amazon-adsystem.com/e/ir?t=ytera-22&l=li2&o=9&a=4774178667)
