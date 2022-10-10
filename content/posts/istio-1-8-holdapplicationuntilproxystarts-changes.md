---
title: 'Istio 1.8 で holdApplicationUntilProxyStarts 設定に変更がありました'
date: Mon, 07 Dec 2020 13:45:16 +0000
draft: false
tags: ['Istio', 'Istio', 'advent calendar 2020']
---

[Advent Calendar 2020 全部オレシリーズ](https://qiita.com/advent-calendar/2020/yteraoka) 7日目です。もう完走は諦めました。

8月にリリースされた Istio 1.7 で追加され、「[メインコンテナの起動前に istio-proxy の起動を完了させる](/2020/08/delaying-application-start-until-sidecar-is-ready/)」で紹介した機能ですが、1.8 で設定方法に変更が入っていました。

これまで通りに Istio のインストールを行おうとしたら早くも **deprecated** だと警告が出ました。

```
! values.global.proxy.holdApplicationUntilProxyStarts is deprecated; use ProxyConfig holdApplicationUntilProxyStarts instead
```

Istio 1.7 では次のように `values.global.proxy.holdApplicationUntilProxyStarts` に設定していたのですがもう推奨されない。

```yaml
apiVersion: install.istio.io/v1alpha2
kind: IstioOperator
spec:
  values:
    global:
      proxy:
        holdApplicationUntilProxyStarts: true
```

Istio 1.8 では Pod 単位でこれを有効・無効化できるようになったみたいです。[Change Notes](https://istio.io/latest/news/releases/1.8.x/announcing-1.8/change-notes/) にも次のように書かれています。

> **Added** `holdApplicationUntilProxyStarts` field to `ProxyConfig`, allowing it to be configured at the pod level. Should not be used in conjunction with the deprecated `values.global.proxy.holdApplicationUntilProxyStarts` value. ([Issue #27696](https://github.com/istio/istio/issues/27696))

ProxyConfig ってなんだよ！っていろいろ探したのですがこれは source code を追う必要がありそう。これだろうってのは分かりましたけど、証拠は掴んでいない。

Istio 1.8 ではどう設定するかですが、Pod 単位で上書きできるので `meshConfig.defaultConfig.holdApplicationUntilProxyStarts` でデフォルトを指定します。

```yaml
apiVersion: install.istio.io/v1alpha2
kind: IstioOperator
spec:
  meshConfig:
    defaultConfig:
      holdApplicationUntilProxyStarts: true
```

Pod で指定する場合は次のように annotation に設定します。

```yaml
annotations:
  proxy.istio.io/config: '{ "holdApplicationUntilProxyStarts": false }'
```

これらの設定は istio-proxy container の env に次のように入っています。

```yaml
env:
- name: PROXY_CONFIG
  value: |
    {"proxyMetadata":{"DNS_AGENT":""},"holdApplicationUntilProxyStarts":false}
```

おそらくこれが ProxyConfig の元になるやつですね。

**istio-system** の `istio-sidecar-injector` という ConfigMap の template という値に次のような感じで使われているので 1.7 の設定でもまだ使えます。

```go-text-template
{{- $holdProxy := or .ProxyConfig.HoldApplicationUntilProxyStarts.GetValue .Values.global.proxy.holdApplicationUntilProxyStarts }}
```
