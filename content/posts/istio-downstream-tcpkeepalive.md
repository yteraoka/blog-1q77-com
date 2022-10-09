---
title: 'Istio で Downstream への TCP keepalive を送る方法'
date: Mon, 14 Dec 2020 11:48:15 +0000
draft: false
tags: ['Istio', 'Istio', 'advent calendar 2020']
---

[Advent Calendar 2020 全部オレシリーズ](https://qiita.com/advent-calendar/2020/yteraoka) 14日目です。誕生日記念号です。おめでとうございます。ありがとうございます。

先日も gRPC と NLB での idle timeout の問題について触れましたが、今回は Istio の Ingress Gateway で NLB の idle timeout に対応する方法です。

[Go言語ではクライアント側もサーバー側もデフォルトで15秒間隔の TCP keepalive が有効になる](/2020/12/tcp-keepalive-in-golang/)ということも書きましたが、Istio を導入した環境では、サーバーの接続相手は localhost の Envoy (istio-proxy) となるため、TCP keepalive もその間で閉じてしまってクライアントには届きません。クライアントと TCP 接続するのは Istio Ingress Gateway なのです。

また、クライアント視点ではクライアントから keepalive を送っておけば問題なさそうに見えますが、サーバー側からも送っておかないと、黙っていなくなられるともう相手がいないコネクションをずっと維持することになってしまい、ファイルディスクリプタが溢れたり、無駄なメモリを使ってしまいます。

クライアントと直接接続している Istio Ingress Gateway が TCP keepalive を送ってくれれば良いわけですが、Istio のドキュメントをみても TCP keepalive の設定項目があるのは [DestinationRule](https://istio.io/latest/docs/reference/config/networking/destination-rule/#ConnectionPoolSettings-TCPSettings-TcpKeepalive) だけです。

それで、ググっていたら見つかりました。

https://github.com/envoyproxy/envoy/issues/3634

Enovy の [issue #3634](https://github.com/envoyproxy/envoy/issues/3634) で「downstream の TCP keepalive を設定したいんだけど」というのがあり、それは [socket\_options](https://www.envoyproxy.io/docs/envoy/v1.16.0/api-v3/config/listener/v3/listener.proto#envoy-v3-api-field-config-listener-v3-listener-socket-options) でできるよということでした。さらに [Gardener](https://gardener.cloud/) という Kubernetes-as-a-service を構築するプロジェクトでそれを EnvoyProxy で実装したという [PullRequest](https://github.com/gardener/gardener/pull/3104) へのリンクもありました。ありがたや、ありがたや。

https://github.com/gardener/gardener/pull/3104

ということで次のような EnvoyFilter を適用すれば Istio Ingress Gateway で downstream (クライアント向け) の TCP keepalive を設定することができます。

`match` のところを見るとわかりますが、この書き方の場合、listener の port ごとに `configPatches` に並べる必要があります。

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  labels:
    istio.io/rev: default
  name: istio-ingressgateway
  namespace: istio-system
spec:
  configPatches:
  - applyTo: LISTENER
    match:
      context: GATEWAY
      listener:
        name: 0.0.0.0_8443
        portNumber: 8443
    patch:
      operation: MERGE
      value:
        socket_options:
        # /usr/include/asm-generic/socket.h
        # SOL_SOCKET = 1
        # SO_KEEPALIVE = 9
        - level: 1
          name: 9
          int_value: 1 # keepalive を有効にする
          state: STATE_LISTENING
        # /usr/include/linux/tcp.h
        # IPPROTO_TCP = 6
        # TCP_KEEPIDLE = 4
        - level: 6
          name: 4
          int_value: 15 # 15秒間の無通信が発生したら keepalive を送り始める
          state: STATE_LISTENING
        # IPPROTO_TCP = 6
        # TCP_KEEPINTVL = 5
        - level: 6
          name: 5
          int_value: 15 # 15秒間隔で keepalive を送る
          state: STATE_LISTENING
        # IPPROTO_TCP = 6
        # TCP_KEEPCNT = 6
        - level: 6
          name: 6
          int_value: 3 # 3回応答がなかったら close する (FIN を送る)
          state: STATE_LISTENING
```

この設定を使うと、最後の通信から15秒後から15秒間隔で keepalive を送信します。3回連続で応答がなかったら RST を送って強制切断します。TCP\_KEEPINTVL の間レスポンスを待つという感じで TCP\_KEEPIDLE の15秒待った後、15秒を3回で60秒後に RST が送られます。3回目を送った直後ではありません。
