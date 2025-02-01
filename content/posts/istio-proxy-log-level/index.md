---
title: 'istio-proxy の log level を変更する'
date: 2022-06-07T16:34:29+09:00
draft: false
tags: ['Istio', 'Kubernetes']
image: cover.png
author: "@yteraoka"
categories:
  - IT
---

## 課題

Istio でよくわからない通信の問題が発生した際、Envoy の access log だけでは何が起きているのかわからない場合があります。そんなとき、当該 Pod の LogLevel を debug に変更することで得られる情報が増えることがあります。問題が再現しないとダメですが。

## LogLevel の変更

LogLevel は Pod の `sidecar.istio.io/logLevel` という annotation で指定可能です。

```yaml
metadata:
  annotations:
    "sidecar.istio.io/logLevel": debug
```

### LogLevel の選択肢

選択肢は次の通り  
trace, debug, info, warning, error, critical, off

### probe のログを多すぎて頻度を下げたい

Probe のアクセスが多くてノイズになる場合は `readiness.status.sidecar.istio.io/periodSeconds` という annotation で間隔を延ばすこともできます。

```yaml
metadata:
  annotations:
    "sidecar.istio.io/logLevel": debug
    "readiness.status.sidecar.istio.io/periodSeconds": "60"
```

## 参考情報

* [https://access.redhat.com/solutions/6303361](https://access.redhat.com/solutions/6303361)
