---
title: 'ReverseProxyのretry機能を調査'
date: Thu, 15 Jun 2017 15:44:44 +0000
draft: false
tags: ['Apache', 'HAProxy', 'Nginx']
---

Apache, nginx, HAProxy の ReverseProxy において、proxy 先の障害をどう回避するかを調べてみます。

### Apache

Apache 2.4.x の mod\_proxy\_balancer, mod\_proxy\_http を調査対象とします (より正確には CentOS 7 の httpd-2.4.6-45.el7.centos.4.x86\_64 です)。 [mod\_proxy\_hcheck](http://qiita.com/yteraoka/items/380ded6b68b630bb9388) については触れません。 次のような mod\_proxy\_balancer を使わない Proxy 設定では retry は行われません

```apache
ProxyPass / http://backend:8080/
```

```apache
ProxyPass / balancer://backend/

<Proxy balancer://backend>
  BalancerMember http://backend1:8080
  BalancerMember http://backend2:8080
  BalancerMember http://backend3:8080
</Proxy>
```

BalancerMember が複数設定されている場合は、接続できない限りは順に次のサーバーで retry されます、デフォルトでは Member の数だけ試行されます。BalancerMember が1つの場合は ProxyPass がデフォルトのままでは retry されません。接続できなかった Member はエラー状態とされ、BalancerMember オプションの retry (秒) で指定されて時間はリクエストが割り振られなくなります。retry のデフォルトは 60 (秒) です。

```apache
  BalancerMember http://backend1:8080 retry=10
```

全ての Member がエラー状態ではリクエストを捌けなくなるので retry の時間を待たずして全て復活します。ProxyPass のオプションで `forcerecovery=Off` と指定すれば全滅の場合も retry を待ちます (forcerecovery の default は On です)。 接続のタイムアウトは BalancerMember に `connectiontimeout` で指定します(デフォルトの単位は秒ですが ms をつけることでミリ秒指定が可能)。接続後のタイムアウトは `timeout` (秒) です。接続後の `timeout` ではリトライされません。504 Proxy Error がクライアントに返されます。デフォルトではこのタイムアウトでは Error 状態にならないので次からのリクエストもその Member へ振り分けられます。この場合も Error にするには ProxyPass 設定で `failontimeout` を `On` にします。サーバーが 500 や 503 を返した場合もデフォルトでは Error 状態になりませんが、`failonstatus=500,503` などとカンマ区切りでステータスを並べることで Error 状態にでき、`retry` 秒間リクエストが割り振られません。 ProxyPass の `maxattempts` でリトライの回数を指定できます。これを指定すれば BalancerMember が1つでも接続のリトライが可能です。デフォルトでは BalancerMember を全部試すように調整されます。Member の数を超える数を指定すると往復するようなかんじでリトライされます。

```apache
ProxyPass / balancer://backend/ maxattempts=10
<Proxy balancer://backend>
  BalancerMember http://backend1:8080 retry=10 disablereuse=On connectiontimeout=2 timeout=2
  BalancerMember http://backend2:8080 retry=10 disablereuse=On connectiontimeout=2 timeout=2
  BalancerMember http://backend3:8080 retry=10 disablereuse=On connectiontimeout=2 timeout=2
</Proxy>
```

こんな感じで、どれにも接続できないとすると 1 -> 2 -> 3 -> 3 -> 2 -> 1 -> 1 -> 2 -> 3 -> 3 -> ... という順でリトライされました。

`ping` 設定で各リクエストを送る前に proxy 先が生きているかどうか、あるいはレスポンスが遅くないかを確認するとあります ([http://httpd.apache.org/docs/2.4/mod/mod\_proxy.html#proxypass](http://httpd.apache.org/docs/2.4/mod/mod_proxy.html#proxypass)) が試してみてもどうもそんな動作をしてないなと思って mod\_proxy\_http.c を確認したら、POST などリクエストに BODY が含まれる場合だけになっていました。

```
    do_100_continue = (worker->s->ping_timeout_set
                       && ap_request_has_body(r)
                       && (PROXYREQ_REVERSE == r->proxyreq)
                       && !(apr_table_get(r->subprocess_env, "force-proxy-request-1.0")));
```

POST で試してみると `Expect: 100-Continue` というヘッダーが追加されていました。この場合、`100 Continue` が返ってこないと継続データを送りません。全てが1度の write buffer に収まってる場合は追加で送るデータはありませんが、`100 Continue` が期待の時間内に返ってこなければ切断してしまうので処理がされません。

```
[Proxy => Backend]
POST / HTTP/1.1
Host: 127.0.0.1:8080
User-Agent: curl/7.29.0
Accept: */*
Content-Type: application/x-www-form-urlencoded
Expect: 100-Continue
X-Forwarded-For: 127.0.0.1
X-Forwarded-Host: 127.0.0.1
X-Forwarded-Server: ::1
Connection: Keep-Alive
Content-Length: 3

a=b

[Proxy <= Backend]
HTTP/1.1 100 Continue

[Proxy => Backend]
POST データの残り(あれば)

[Proxy <= Backend]
HTTP/1.1 200 OK
Date: Sat, 01 Jul 2017 10:29:25 GMT
Server: Apache/2.4.26 (Unix) OpenSSL/1.0.1e-fips
Last-Modified: Mon, 11 Jun 2007 18:53:14 GMT
ETag: "2d-432a5e4a73a80"
Accept-Ranges: bytes
Content-Length: 45
Keep-Alive: timeout=62, max=100
Connection: Keep-Alive
Content-Type: text/html
```

#### Apache のまとめ

接続できてしまったらリトライされません。遅いサーバーはとっとと諦めて次に移るということができない。エラー状態になればダウンしているサーバーへのアクセスを試みることがなくなり、無駄なタイムアウト待ちを減らせますが、retry の指定秒を経過すると実際のサーバーの状態にかかわらず(まだダウンしているかもしれないのに)再度リクエストを割り振られてしまいます。

### nginx

nginx mainline repository の RPM package を CentOS 7 で実行して試しています (nginx-1.13.1-1.el7.ngx.x86\_64) nginx 1.9.13 から POST, LOCK, PATCH メソッドの場合、デフォルトではリトライされないようになっています。 nginx で Load Balance & retry を行うには [upstream module](http://nginx.org/en/docs/http/ngx_http_upstream_module.html) を使う必要があります。これを使わないで

```nginx
proxy_pass http://backend.example.com;
```

とした場合は接続に失敗しても retry が行われません。

```nginx
upstream backend {
  server backend1:8080;
  server backend2:8080;
  server backend3:8080;
}
...
server {
  location / {
    proxy_pass http://backend;
  }
}
```

と、upstream module を使うと接続に失敗したり、timeout すると順に次のサーバーに対して retry が試みられます。 proxy 先が1つしか無い場合にも接続に失敗したら retry して欲しい場合にはどうしたら良いか？

```nginx
upstream backend {
  server backend1:8080;
  server backend1:8080;
  server backend1:8080;
}
```

同じサーバーを並べることで retry が可能になります (Apache の場合は同一の proxy 先は1つにまとめられてしまいます)。
タイムアウト時の retry が続く場合はどこかで諦めないと10台とかに2秒ずつとか待っていられないのでどこかで早めに打ち切らせるべきです。試行回数を制限したい場合は [proxy\_next\_upstream\_tries](http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_next_upstream_tries) で回数を指定します。デフォルトでは upstream に指定したサーバーの数となります。Apache と違い失敗した後の試行回数ではなく最初の試行からカウントされます。合計の待ち時間を制限したい場合は [proxy\_next\_upstream\_timeout](http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_next_upstream_timeout) で時間を指定します。retry を繰り返す間にこの時間に到達すると 504 Gateway Timeout がクライアントに返されます。retries と timeout を両方していすることもできます。どちらか先に達した方でエラーが返されます。

接続の失敗やタイムアウトしたサーバーは一時的に無効状態にされ、しばらくリクエストを割り振られなくなります。このしばらくという時間は [server](http://nginx.org/en/docs/http/ngx_http_upstream_module.html#server) のパラーメーター `fail_timeout` で指定します。デフォルトは10秒です。何回失敗したら無効にするかというと、`fail_timeout` の間に `max_fails` 回となっています。デフォルトは `fail_timeout=10`, `max_fails=1` となっているので1度の失敗で10秒間無効にされます。

失敗、失敗と書きましたが何を持って失敗とするかは [proxy\_next\_upstream](http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_next_upstream) の値が関係してきます。デフォルトでは接続の失敗とタイムアウトとサーバーから異常なレスポンスがあった場合です。これらは `proxy_next_upstream` で指定せずとも失敗としてカウントされます。`http_500`, `http_502`, `http_503`, `http_504`, `http_429` は `proxy_next_upstream` で指定した場合のみカウントされます。`http_403` と `http_404` は `proxy_next_upstream` で指定したとしてもカウントされません。`proxy_next_upstream` はリトライするかどうかの指定でもあり、その意味では設定したもののみがリトライ対象となります。デフォルト値から変更し `connect` や `timeout` を指定しなければ、失敗としてカウントされはするもののリトライはされません。

HTTP CODE の 500 や 503 でも失敗としたい場合は `proxy_next_upstream http_500 http_503` と指定します。`error`, `timeout`, `invalid_header` は指定しなくても常に失敗として扱われます。`http_403`, `http_404` は指定しても失敗扱いになりません。(POST, LOCK, PATCH でもリトライさせたい場合は `non_idempotent` を指定します) サーバーのパラメーター指定は次のようにします。

```nginx
upstream backend {
  server backend1:8080 max_fail=1 fail_timeout=15;
  server backend2:8080 max_fail=1 fail_timeout=15;
  server backend3:8080 max_fail=1 fail_timeout=15;
}
```

パラメーターはこれ以外にも `weight`, `max_conns`, `backup`, `down` が使えます。 失敗が続き、retry 可能な別のサーバーが無くなった場合は最後のレスポンスを返します。すでに全てのサーバーが無効状態であれば 502 Bad Gateway が返されます。

| Name          | Type   | Default | Description |
|---------------|--------|---------|-------------|
| weight        | number | 1       | サーバー振り分けの重み付け |
| mx\_conns     | number | 0       | 同時接続数の上限を指定する。共有メモリを使うように zone が指定されていなければ workker プロセス単位で制限となる。非商用版で使えるのは 1.11.5 以降のみ |
| max\_fails    | number | 1       | `fail_timeout` 単位時間にここで指定した回数の失敗が発生すると `fail_timeout` の間サーバーを無効にする (リクエストを割り振らない) |
| fail\_timeout | time   | 10秒    | `max_fails` の説明を参照 |
| backup        | -      | -       | backup でないサーバーが全て無効になった場合にのみ有効になる |
| down          | -      | -       | ずっと無効にしておく |

有償版の nginx ではさらに `resolve`, `route`, `service`, `slow_start` という便利そうなパラメーターが使えるようです。

#### nginx のまとめ

失敗が続く限りは upstream に指定したサーバー全てに順にリトライする。失敗の定義は [proxy\_next\_upstream](http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_next_upstream) で行い、リトライの回数、時間の制限は [proxy\_next\_upstream\_tries](http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_next_upstream_tries), [proxy\_next\_upstream\_timeout](http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_next_upstream_timeout) で制限する。サーバーの数を超えるリトライ回数は意味をなさない。単位時間(fail\_timeout)内の失敗の回数(max\_fails)によってサーバーが一時的(fail\_timeout)に無効になる。 Proxy 先が1台でも retry したい場合は同じサーバーを複数定義する。 retry したくない場合は `proxy_next_upstream off` とする (`proxy_next_upstream_tries 1` でも良さそうな気がする)。

```nginx
upstream backend {
  server backend1:8080 max_fail=1 fail_timeout=20 weight=1;
  server backend2:8080 max_fail=1 fail_timeout=20 weight=2;
  server backend3:8080 max_fail=1 fail_timeout=20 weight=3;
  server backend4:8080 backup;
}
...
server {
  location / {
    proxy_connect_timeout 2s;
    proxy_read_timeout 2s;
    proxy_next_upstream_timeout 5s;
    proxy_next_upstream_tries 3;
    proxy_pass http://backend;
  }
}
```

### HAProxy

HAProxy 1.5.18 で確認しました (CentOS 6 の haproxy-1.5.18-1.el6.x86\_64 で試したが CentOS 7 でも yum で入るのは haproxy-1.5.18-3.el7\_3.1.x86\_64 なので同じでしょう) HAProxy には active check があります、任意の間隔で proxy 先のチェックを行えます。(Apache の [mod\_proxy\_hcheck](http://qiita.com/yteraoka/items/380ded6b68b630bb9388) はまだイマイチで nginx は有償版だけで使える)

#### Active Check を行わない場合 (リトライしない)

```haproxy
backend test-be
    balance roundrobin
    server test1 backend1:8080
    server test2 backend2:8080
    server test3 backend3:8080
```

単純に順番に server で指定したサーバーに proxy します。接続できない場合は別のサーバーにトライせずに 503 Service Unavailable を返します。

#### Active Check を行わない場合 (リトライする)

redispatch を有効にすると接続できない場合は次のサーバー、それでもダメならさらに次のサーバーへとリトライしてくれます。

```haproxy
backend test-be
    balance roundrobin
    option redispatch
    server test1 backend1:8080
    server test2 backend2:8080
    server test3 backend3:8080
```

#### Active Check をする場合 (リトライしない)

`server` に `check` パラメータをつけるとそのサーバーに接続できるかどうかをチェックします。`default-server` でチェック間隔を指定します。`inter` で通常時の間隔を、`downinter` で DOWN 状態の間隔、`fastinter` で DOWN から UP に変わる途中の間隔を。 途中というのは下の例では `rise 3` としているので DOWN 状態になると 3 回チェックに成功しないと UP 状態にならなず、1 回成功した後 UP になるまでの間です。`rise` のデフォルトは 2 で、`fall` のデフォルトは 3 で、3 回エラーになると DOWN 状態になります。下の例では 1 回の失敗で DOWN になります。 定期的に監視して DOWN 状態になれば DOWN 中はそのサーバーにリクエストを振り分けなくなりますが、それまでは振り分けてしまってエラーを返してしまいます。

```haproxy
backend test-be
    balance roundrobin
    default-server inter 5000 downinter 10000 fastinter 3000 rise 3 fall 1
    server test1 backend1:8080 **check**
    server test2 backend2:8080 **check**
    server test3 backend3:8080 **check**
```

`option httpchk` 設定で TCP の接続確認だけでなく HTTP でのチェックができます。レスポンスが 2xx か 3xx であれば成功、それ以外が失敗です。

```haproxy
backend test-be
    balance roundrobin
    option httpchk GET /healthcheck
    default-server inter 5000 downinter 10000 fastinter 3000 rise 3 fall 1
    server test1 backend1:8080 check
    server test2 backend2:8080 check
    server test3 backend3:8080 check
```

#### Active Check をする場合 (リトライする)

`option redispatch` を設定すれば、接続できなかったりしても次のサーバーにリトライしてくれるのでクライアントにエラーを返さないですみます。

```haproxy
backend test-be
    balance roundrobin
    option redispatch
    default-server inter 5000 downinter 10000 fastinter 3000 rise 3 fall 1
    server test1 backend1:8080 check
    server test2 backend2:8080 check
    server test3 backend3:8080 check
```

#### 通常のリクエストもエラーカウントの対象にする

`check` に加えてて `observe layer4` を設定することで通常のリクエストの処理でエラーになったものも fall のカウントに使われます。短い間隔で check を実行するよりもこの機能を使う方が監視のアクセスによる負荷を減らせます。沢山の HAProxy サーバーから頻繁な監視アクセスがあるとその処理内容によっては負荷が気になるかもしれないので。`layer7` も使えます。この場合 100 から 499 と 501, 505 が成功として扱われます。404 Not Found で DOWN になったりしないように。

```haproxy
backend test-be
    balance roundrobin
    option httpchk GET /healthcheck
    default-server inter 5000 downinter 10000 fastinter 3000 rise 3 fall 1
    server test1 backend1:8080 check observe layer4
    server test2 backend2:8080 check observe layer4
    server test3 backend3:8080 check observe layer4
```

まだ書きかけ
