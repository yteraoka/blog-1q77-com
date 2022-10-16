---
title: 'istio sidecar の停止を connection がなくなるまで遅らせる'
date: Sun, 27 Feb 2022 00:52:27 +0900
draft: false
tags: ['Envoy', 'Istio', 'Kubernetes']
---

新機能 EXIT\_ON\_ZERO\_ACTIVE\_CONNECTIONS
---------------------------------------

以前、「[Istio 導入への道 – sidecar の調整編](/2020/03/istio-part12/)」という記事で、Istio の sidecar (istio-proxy) が、アプリの終了を待たずに停止してしまってアプリ側が通信できなくなるという問題に対して preStop hook に netstat などを使った wait 処理を入れるというのを紹介しましたが、あれは listen しているプロセスがいなくなるまで待つというもので、nginx などのように処理中のリクエストは完了を待つが、listen している socket は signal を受けるとすぐに close するというサーバーの場合には有効に働きませんでした。これに対して [2021年11月にリリースされた](https://istio.io/latest/news/releases/1.12.x/announcing-1.12/) **Istio 1.12** では **drain モード**に変更した後、アクティブなコネクションがなくなるまで待つという設定ができるようになっていました。(**drain モード**については後述)

[Istio 1.12 Change Notes](https://istio.io/latest/news/releases/1.12.x/announcing-1.12/change-notes/) に次のように書かれています。

> **Added** support for envoy to track active connections during drain and quit if active connections become zero instead of waiting for entire drain duration. This is disabled by default and can be enabled by setting `EXIT_ON_ZERO_ACTIVE_CONNECTIONS` to true. ([Issue #34855](https://github.com/istio/istio/issues/34855))

> Envoy の drain 中にアクティブなコネクションを追跡し、それがゼロになった場合、drain 期間の終了を待たずに envoy を終了させる機能を追加しました。この機能はデフォルトでは無効になっており、`EXIT_ON_ZERO_ACTIVE_CONNECTIONS` を true にすることで有効化できます。

envoy の drain とは？
-----------------

ここで、Istio における envoy の [drain](https://www.envoyproxy.io/docs/envoy/v1.20.1/intro/arch_overview/operations/draining.html) について説明しておきます。通常 drain と聞くと、もう新規の接続を受け付けなくなるんじゃないかと思ってしまいますが、Istio では Envoy の `/drain_listeners?inboundonly&graceful` という API を使用しており、graceful とうパラメータがついていることで Envoy は起動オプションの [`--drain-time-s`](https://www.envoyproxy.io/docs/envoy/v1.20.1/operations/cli#cmdoption-drain-time-s) で指定した期間 (Istio のデフォルトは 45 秒) は新規の接続も受け付ける状態を維持します。では、その間は drain の前と何が違うのかというと、HTTP1 の場合はレスポンスヘッダーに `Connection: close` を設定し keep-alive させないようにします。HTTP2 の場合も GOAWAY を送ってセッションを終わらせるようです(これは試せていない)。また、Istio では [`--drain-strategy`](https://www.envoyproxy.io/docs/envoy/v1.20.1/operations/cli#cmdoption-drain-strategy) を `immediate` と指定しているため、即座に全ての connection が　close に向かいます。

私もちゃんと調べる前は SIGTERM を受け取ってすぐに drain してしまったら意味ないじゃんって思ってましたが、新規接続も受け付けてくれるので Pod の削除開始から実際に新規リクエストが来なくなるまで待つという用途でも使えるんです。ただし、`--drain-time-s` の 45 秒と `terminationGracePeriodSeconds` (default 30 秒) には要注意。

さらに、drain 開始時には [Hot restart](https://www.envoyproxy.io/docs/envoy/v1.20.1/intro/arch_overview/operations/hot_restart#arch-overview-hot-restart) が行われ、閉じるべき接続を持った古いプロセスの方は `--parent-shutdown-time-s` で指定された時間が経過すると終了させられてしまいます。Istio ではこの値 (`parentShutdownDuration`) がデフォルトで 60 秒になっています。

EXIT\_ON\_ZERO\_ACTIVE\_CONNECTIONS が有効の場合の停止処理
-----------------------------------------------

具体的には istio agent (pilot-agent) に `minDrainDuration` と `exitOnZeroActiveConnections` という項目が追加されています。`exitOnZeroActiveConnections` が `ture` であれば drain 開始後に `minDrainDuration` の期間 (default 5秒) sleep した後に1秒おきにアクティブな connection が残っているかどうかを Envoy の stats endpoint (`http://localhost:15000/stats?usedonly&filter=downstream_cx_active$`) で確認し、0 になったら終了します。

EXIT\_ON\_ZERO\_ACTIVE\_CONNECTIONS が無効の場合の停止処理
-----------------------------------------------

無効の場合は drain 開始後に `terminationDrainDuration` (default 5秒) 待って終了します。 この場合、安全のために `terminationDrainDuration` を長くすると無駄に待つことになってしまうことがあるためあまり長くしたくないということになります。

設定してみる
------

Pod に対して設定するには次のような annotation を設定します。動作確認は Istio 1.12.1 で行いました。

```yaml
annotations:
  proxy.istio.io/config: |
    proxyMetadata:
      MINIMUM_DRAIN_DURATION: '5s'
      EXIT_ON_ZERO_ACTIVE_CONNECTIONS: 'true'
      proxyStatsMatcher:
        inclusionRegexps:
        - ".*downstream_cx_active"
```

`proxyStatusMatcher` は本来はここで設定しなくても `EXIT_ON_ZERO_ACTIVE_CONNECTIONS`　が有効な場合は istio がやってくれそうな[コード](https://github.com/istio/istio/pull/36089/files)になっているのですが、なぜか **downstream\_cx\_active** メトリクスが取得できずにずっとループ内で待たされ、 `terminationGracePeriodSeconds` で SIGKILL を受けるということになっていたのでここで指定することで対処しました。annotation での設定か istio が設定してくれるかに関わらず、**downstream\_cx\_active** メトリクスを取得可能にすると \`/stats/prometheus\` で返すメトリクスにも追加され、環境によっては prometheus のストレージへの影響が無視できないことになりそうなので scrpae 時に除外するなどの設定をした方が良さそうです。

Pod の停止時に次のようなログが出ていれば `EXIT_ON_ZERO_ACTIVE_CONNECTIONS` は有効になっています。

```
Agent draining proxy for 5s, then waiting for active connections to terminate...
```

その後 `There are no more active connections. terminating proxy...` というログが出ないまま終了されていたらそれは metrics が取得できずにずっと待たされているか、本当にコネクションがクローズされなくて `terminationGracePeriodSeconds` を迎えて SIGKILL で終了させられている可能性があります。

まとめ
---

ということで istio の sidecar が inject された Pod の終了について整理してみる。

*   istio-proxy (pilot-agent) は SIGTERM を受けるとすぐに Envoy の draining を開始させる
    *   graceful な drain を指定しているので新規の接続も受け入れる
    *   新規接続を受け入れる期間は Envoy の起動オプション `--drain-time-s` で指定されており (Istio では ProxyConfig.drainDuration で指定可能でデフォルトは 45 秒)、以降の待ち時間の間でもこれを超えると新規の接続は受け入れられなくなる
    *   drain 中の HTTP1 のレスポンスには Connection: close ヘッダーを設定したり、HTTP2 の GOAWAY で close したりしてくれる
*   `EXIT_ON_ZERO_ACTIVE_CONNECTIONS` が有効でない場合
    *   `terminationDrainDuration` で指定した期間 (デフォルトは 5 秒) 待って終了
*   `EXIT_ON_ZERO_ACTIVE_CONNECTIONS` が有効な場合
    *   `minDrainDuration` の期間 (デフォルトは 5 秒) 待つ
    *   1秒おきにアクティブな接続の数を確認して、0 になったら終了
    *   0 にならなければそのうち `terminationGracePeriodSeconds` で SIGKILL を受ける

ProxyConfig.parentShutdownDuration の値が envoy の `--parent-shutdown-time-s` で指定されており、drain されるコネクションを持っているプロセスは drain 開始からこの時間が経過すると終了させられる。デフォルトは 60 秒。

多くの時間設定があるので要注意 ([DefaultProxyConfig](https://github.com/istio/istio/blob/1.12.1/pkg/config/mesh/mesh.go#L44-L46))

*   `terminationGracePeriodSeconds` (default 30s)  
    Pod の delete 開始から各コンテナに SIGKILL が送られるまでの時間
*   `terminationDrainDuration` (default 5s)  
    EXIT\_ON\_ZERO\_ACTIVE\_CONNECTIONS が無効の場合に drain 状態で待つ時間
*   `minDrainDuration` (default 5s)  
    EXIT\_ON\_ZERO\_ACTIVE\_CONNECTIONS が有効の場合に少なくともこの期間は待つ時間
*   `drainDuration` (default 45s)  
    drain 開始から新規接続を受け入れなくなるまでの時間
*   `parentShutdownDuration` (default 60s)  
    drain 開始から drain 対象の envoy プロセスを終了させるまでの時間 ([Hot restart](https://www.envoyproxy.io/docs/envoy/v1.20.1/intro/arch_overview/operations/hot_restart#arch-overview-hot-restart))

Drain 中も新規接続は受け付けるということが確認できたので、`EXIT_ON_ZERO_ACTIVE_CONNECTIONS` を有効にせずとも `terminationDrainDuration` を長めにしておけば Kubernetes でおなじみの preStop の sleep に対応できそうです。

```yaml
annotations:
  proxy.istio.io/config: |
    terminationDrainDuration: 10s
```

思いがけず Envoy の draining についての理解が深まって良かったです。Connection: close ヘッダーの設定までやってくれてただなんて。

`proxyStatsMatcher` 設定を追加しなければならな方のは bug だったみたいで、報告したら早速修正の Pull Request を作ってもらえました。  
[fix passing exit on zero active connections to metadata #37573](https://github.com/istio/istio/pull/37573)
