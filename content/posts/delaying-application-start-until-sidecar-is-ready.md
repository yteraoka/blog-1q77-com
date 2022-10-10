---
title: 'メインコンテナの起動前に istio-proxy の起動を完了させる'
date: Tue, 25 Aug 2020 14:24:46 +0000
draft: false
tags: ['Istio', 'Kubernetes']
---

2020年8月21日に Istio 1.7 がリリースされました。その [RELEASE NOTE](https://istio.io/latest/news/releases/1.7.x/announcing-1.7/) の [Production operability improvements](https://istio.io/latest/news/releases/1.7.x/announcing-1.7/#production-operability-improvements) 項に次の節を見つけました。

> You can [delay the application start until after the sidecar is started](https://medium.com/@marko.luksa/delaying-application-start-until-sidecar-is-ready-2ec2d21a7b74). This increases the reliability for deployments where the application needs to access resources via its proxy immediately upon its boot.

「**サイドカーの起動が完了するまでアプリケーションの開始を遅らせることが出来るよ**」とありますね、みんなが待ち望んでいたやつです。istoi-proxy (envoy) の起動が完了する前にアプリが起動しちゃって通信でコケるということにならないように envoy の status port にアクセスして起動を確認してからアプリのプロセスを起動するとか書かなくても良くなります。ステキ！

仕組みはリンク先で説明されています、**kubelet** は manifest の `containers` に書かれた順にシーケンシャルに起動させ、`postStart` があればそれを待つから、サイドカーをリストの先に定義して `postStart` でそのサイドカープロセスの起動が完了するのを待てば良いということのようです。

これを実現するための変更が [istio/istio #24737](https://github.com/istio/istio/pull/24737) で、Istio 1.7.0 に含まれています。

IstioOperator 用の manifest で次の設定を入れるか、`istioctl manifest generate --set values.global.proxy.holdApplicationUntilProxyStarts=true` などとすれば istio-proxy サイドカーが containers の先頭に挿入され、postStart hook が挿入されます。

```yaml
  values:
    global:
      proxy:
        holdApplicationUntilProxyStarts: true
```

istio-sidecar-injector という ConfigMap に次のような箇所があります。

```go-text-template
      {{- if .Values.global.proxy.lifecycle }}
        lifecycle:
          {{ toYaml .Values.global.proxy.lifecycle | indent 4 }}
      {{- else if .Values.global.proxy.holdApplicationUntilProxyStarts}}
        lifecycle:
          postStart:
            exec:
              command:
              - pilot-agent
              - wait
      {{- end }}
```

あれ？このコードだと lifecyle を[すでに指定してた](/2020/03/istio-part12/)ら `postStart` も自前で書く必要がありますね。Pod 停止時に先に istio-proxy が停止してしまうと通信できなくなってしまうため、istio-proxy の `preStop` には[すでになんらかの処理を入れてます](/2020/03/istio-part12/)よね？ ということはそこで `postStart` も設定する必要があります。

こういうことですね。

```yaml
  values:
    global:
      proxy:
        holdApplicationUntilProxyStarts: true
        lifecycle:
          preStop:
            exec:
              command:
                - "/bin/sh"
                - "-c"
                - "while [ $(netstat -plnt | grep tcp | egrep -v 'envoy|pilot-agent' | wc -l) -ne 0 ]; do sleep 1; done"
          postStart:
            exec:
              command:
                - pilot-agent
                - wait
```

検証してね！
