---
title: 'Go 言語での TCP keepalive'
date: Thu, 10 Dec 2020 15:21:48 +0000
draft: false
tags: ['Go', 'advent calendar 2020', 'go']
---

[Advent Calendar 2020 全部オレシリーズ](https://qiita.com/advent-calendar/2020/yteraoka) 10日目です。もうめんどくせえなあ。

gRPC と NLB での Idle Timeout というあるある問題の調査で Go 言語で書いたクライアントとサーバーを使った際に知ったことのメモです。

まずは TCP keepalive を送らないクライアントとサーバーでの動作検証だ、と思って tcpdump を実行しながら試してみたらなぜか 15 秒おきに TCP keepalive を送り合うんです... は！？

そんなコード書いてないのに？？

で、確認してみるとクライアント(Dial)側は Go 1.12 からデフォルトで TCP keepalive が有効になっていたみたいです。1.12 ってもうだいぶ前ですね。keepalive の送信は最後の通信から15秒後から15秒おきに送信します。切断までの連続失敗回数は未指定なので kernel の設定が使われます。Linux のデフォルトは9回が多いようです。

https://github.com/golang/go/commit/5bd7e9c54f946eec95d32762e7e9e1222504bfc1

Go 1.13 ではサーバー側もデフォルトで有効になりました。最初は3分間隔でしたが

https://github.com/golang/go/commit/1abf3aa55bb8b346bb1575ac8db5022f215df65a

その後、クライアント側と同じ15秒に変更されました

https://github.com/golang/go/commit/b98cecff882e42c7f0842c7adae1deeca1b99002

Kernel の設定確認はこんな感じで

```
$ sudo sysctl -a 2> /dev/null | grep tcp_keepalive 
net.ipv4.tcp_keepalive_intvl = 75
net.ipv4.tcp_keepalive_probes = 9
net.ipv4.tcp_keepalive_time = 7200
```

TCP keepalive は　net.ipv4.tcp_keepalive_time で最後の通信から何秒無通信が続いたら送り始めるか、net.ipv4.tcp_keepalive_intvl で何秒おきに送信するか、net.ipv4.tcp_keepalive_probes で何回連続して応答が返ってこなかったら切断するかを指定します。

上記の Go のコードでは `net.ipv4.tcp_keepalive_time` (`syscall.TCP_KEEPIDLE`) と `net.ipv4.tcp_keepalive_intvl` (`syscall.TCP_KEEPINTVL`) を同じ値で設定するようになっています。

回数 (`net.ipv4.tcp_keepalive_probes`) も指定したい場合は、socket に対して自分で `syscall.SetsockoptInt()` で設定する必要があります。Kubernetes の場合、Pod の kernel パラメーターをいじるのはだいぶ面倒です。

ところで、gRPC を使うコードで私は TCP keepalive を無効にしたかったのです、1.11 は流石に古過ぎるし [https://pkg.go.dev/google.golang.org/grpc](https://pkg.go.dev/google.golang.org/grpc) の Dial でどうやって無効にするのかな、ちゃんとやるの面倒だなと思ってた時に気付きました。[src/net/dial.go](https://github.com/golang/go/blob/9b955d2d3fcff6a5bc8bce7bafdc4c634a28e95b/src/net/dial.go#L17) を書き換えれば良いんだ！！って気付きました。例えば `vi /usr/local/go/src/net/dial.go` です。15秒のところをずっと大きな数字にしちゃえば ok です。この状態で go build すれば keepalive が送られないようになります。

ところで ALB も End-to-End の HTTP2 で gRPC をサポートしましたが、これには罠はないんですかね？

nginx の場合は [http2\_idle\_timeout](http://nginx.org/en/docs/http/ngx_http_v2_module.html#http2_idle_timeout) (デフォルト180秒) ってのがあって、この間リクエストが無いと nginx 側から切断してくれます。

nginx ついでに言うと [listen](http://nginx.org/en/docs/http/ngx_http_core_module.html#listen) 設定でサーバー側の TCP keepalive を設定することが可能です。

```
so_keepalive=on|off|[keepidle]:[keepintvl]:[keepcnt]
```

```
listen 443 http2 so_keepalive=on;

listen 443 http2 so_keepalive=7200:75:9;
```

でわでわ〜

あー、そういえば **netstat** の `-o` / `--timers` や **ss** の `-o` / `--options`, `-e` / `--extended` で keepalive の timer を確認できるんですね。
