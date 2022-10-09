---
title: 'nginx の Connection Draining'
date: Mon, 13 Jun 2016 15:36:56 +0000
draft: false
tags: ['LoadBalancer', 'nginx']
---

docker 化をすすめるにあたり、[consul-template](https://github.com/hashicorp/consul-template) と [registrator](http://gliderlabs.com/registrator/latest/) で [nginx](https://nginx.org/https://nginx.org/) の upstream を動的に更新しようと思いました。 ところで、

```nginx
upstream backend {
  server 10.1.2.3:3456;
  server 10.1.2.4:4567;
  server 10.1.2.5:5678;
}
```

という状態から1つ減って

```nginx
upstream backend {
  server 10.1.2.3:3456;
  server 10.1.2.4:4567;
}
```

となった場合、消えた 10.1.2.5:5678 とつながっていたクライアントとの通信はどうなるのでしょうか？ LoadBalancer には Connection Draining という機能・設定があります。 ELB にもあります（[ロードバランサーの Connection Draining を設定する](http://docs.aws.amazon.com/ja_jp/ElasticLoadBalancing/latest/DeveloperGuide/config-conn-drain.html)）。 nginx ではどうなるのか試してみました。version は 1.11.1 nginx で

```nginx
upstream backend {
  server 127.0.0.1:8080;
  server 127.0.0.1:8081;
  server 127.0.0.1:8082;
  server 127.0.0.1:8083;
}
```

とし、Apache にてざっとこんな感じで 8080, 8081, 8082, 8083 で CGI が動くようにし、

```
Listen 8080
Listen 8081
Listen 8082
Listen 8083

ScriptAlias /cgi-bin/ "/var/www/cgi-bin/"

 AllowOverride None
    Options None
    Order allow,deny
    Allow from all 
```

こんな CGI で各ポートに接続され、出力が流れている状態で nginx の `upstream` を減らして `nginx -s reload` すると通信が止まるかどうか

```perl
#!/usr/bin/perl
use strict;
use warnings;

$| = 1;

print "Content-Type: text/plain\n\n";

for my $i (0 .. 60) {
    printf "%3d %s\n", $i, $ENV{SERVER_PORT};
    sleep 1;
}
```

結果は「通信は途切れない」、もちろん新規の接続は upstream に残った proxy 先にのみ振られます。 良かった良かった、これで安心して思う存分コンテナの入れ替えができます。
