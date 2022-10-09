---
title: 'nginx  memo'
date: 
draft: true
tags: ['未分類']
---

すぐに忘れちゃうので nginx に関する設定メモ

### Buffering

### Reverse Proxy

[ngx\_http\_proxy\_module](http://nginx.org/en/docs/http/ngx_http_proxy_module.html)

### DNS cache

proxy 先のホスト名は起動時、reload 時にキャッシュされて DNS の TTL は考慮されない。Proxy 先の IP アドレスが変更される可能性があれば変数を使って更新できるようにする。 [nginx proxy の名前解決問題、ファイナルアンサー？](/2016/03/nginx-resolving-proxy-upstream/)

### nginx-build

[https://github.com/cubicdaiya/nginx-build](https://github.com/cubicdaiya/nginx-build) OS 標準の OpenSSL が古くて http2 対応ができない場合などに便利。 OpenResty にも対応している。 [nginx-build internals - Qiita](http://qiita.com/cubicdaiya/items/23786c18c50c6581dcbc)

### X-Forwarded-For

X-Forwarded-For には $proxy\_add\_x\_forwarded\_for をそのまま設定するのではなく [realip\_module](http://nginx.org/en/docs/http/ngx_http_realip_module.html) で信頼できる Reverse Proxy サーバーがセットしたものだけをセットするようにする [nginx実践入門 - 酒日記 はてな支店](http://sfujiwara.hatenablog.com/entry/2016/01/26/175350)

### favicon

favicon を設定する予定がない場合、404 でエラーログが出力されるのはうざいし、404 のログも必要ない。なんなら 200 であってもログは不要ということで

```nginx
location = /favicon {
    access_log off;
    empty_gif;
    expires 30d;
}
```

404 の時のエラーログを抑制するには次の方法もある

```nginx
log_not_found off;
```

### gzip
