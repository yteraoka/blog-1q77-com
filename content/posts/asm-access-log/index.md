---
title: "Anthos Service Mesh の Outbound Access Log を出力する"
description: |
  Google の Anthos Service Mesh はデフォルトでアクセスログが Inbound しか出力されないが、Outbound も出力する方法を紹介
date: 2022-10-22T00:33:40+09:00
draft: false
tags: ['Istio', 'GCP', 'Anthos']
image: cover.png
author: "@yteraoka"
categories:
  - IT
---

Anthos Service Mesh のアクセスログはデフォルトでは Service への Inbound しか出力されません。
エラーが発生した場合は Outbound のログも出力されます。
出力先は Cloud Logging で HTTP の情報は Load Balancer などと同様に httpRequest という Object にセットされています。

## Outbound のアクセスログを常に出力する方法

asmcli の `--custom_overlay` で指定する YAML で次の様に `outboundAccessLogging` を `FULL` にすることで Outbound のログも出力されるようになります。

```yaml
spec:
  values:
    telemetry:
      v2:
        stackdriver:
          outboundAccessLogging: FULL
```

## Inbound と Outbound でログの resource.type が異なる

Inbound は `k8s_container` (コンテナログ) だが、Outbound は `k8s_pod` (Pod のログ) となっているので注意。


## STDOUT 経由で出力する方法

GKE 以外の環境で実行する時のように次のようにして標準出力に JSON で書き出すことも可能だが、Cloud Logging に送る場合は上記の方法の方が他のログとの統一感があって便利。

```yaml
spec:
  meshConfig:
    accessLogEncoding: JSON
    accessLogFile: /dev/stdout
```
