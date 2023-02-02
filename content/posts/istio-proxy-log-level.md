---
title: 'istio-proxy の log level を変更する'
date: Tue, 07 Jun 2022 16:34:29 +0900
draft: false
tags: ['Istio', 'Kubernetes']
---

Istio でよくわからない通信の問題が発生した際、Envoy の access log だけでは何が起きているのかわからない場合があります。そんなとき、当該 Pod の LogLevel を debug に変更することで得られる情報が増えることがあります。問題が再現しないとダメですが。

LogLevel は Pod の `sidecar.istio.io/logLevel` という annotation で指定可能です。

```yaml
metadata:
  annotations:
    "sidecar.istio.io/logLevel": debug
```

選択肢は次の通り  
trace, debug, info, warning, error, critical, off

Probe のアクセスが多くてノイズになる場合は `readiness.status.sidecar.istio.io/periodSeconds` という annotation で間隔を延ばすこともできます。

```yaml
metadata:
  annotations:
    "sidecar.istio.io/logLevel": debug
    "readiness.status.sidecar.istio.io/periodSeconds": "60"
```

参考情報

* [https://access.redhat.com/solutions/6303361](https://access.redhat.com/solutions/6303361)
