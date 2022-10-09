---
title: 'Istio で Envoy の Global RateLimit を使う (1)'
date: 
draft: true
tags: ['Uncategorized']
---

複数インスタンスで使える RateLimit 機能が欲しい
-----------------------------

API サーバーでも普通の Web Service でも RateLimit を設置して、異常なアクセスをブロックしたい場合があります。このブログでも過去に nginx の ngx\_http\_limit\_req\_module について書きました。

* [ngx\_http\_limit\_req\_module でリクエストレートをコントロール](/2017/01/ngx_http_limit_req_module/)
* [Nginx で API Management](/2019/06/nginx-api-management/)

今回は Istio が導入されている環境という前提とします。Istio の connection pool に使えそうな設定は一応あります ([Istio の timeout, retry, circuit breaking, etc](https://medium.com/sreake-jp/istio-%E3%81%AE-timeout-retry-circuit-breaking-etc-c170285447e8)) が、これは同時アクセス数をインスタンス単位で制限できる程度のものであり、サイト全体で制限したいという要望を満たせるものではありません。

でも Envoy だったら何かしら機能があるんじゃないのか？ あるいはちょっとした機能追加でいけるんじゃないか？ と思って調べていたところ、[Global rate limiting](https://www.envoyproxy.io/docs/envoy/v1.16.1/intro/arch_overview/other_features/global_rate_limiting) というページを見つけました！！ これは、正しく求めていたもの!!

さらに調べていると Istio の次のバージョン (1.9) のサイトに [Enabling Rate Limits using Envoy](https://preliminary.istio.io/latest/docs/tasks/policy-enforcement/rate-limit/) というページを発見しました。Istio 1.8 までのサイトには存在しないページですが、調べてみると EnvoyFilter で設定するだけなので Istio 付属の Envoy が対応しているバージョンかどうかで Istio 1.6 とか 1.7 でも使えそうです。

ということで検証です。

Global Rate Limit の概要
---------------------

まずはこの機能の概要です。

ざっくり絵にするとこんな感じです。

{{< figure src="envoy-global-ratelimit.png" >}}

RateLimit サーバーに対して各 Envoy が gRPC で問い合わせることになります。gRPC なので [envoy/service/ratelimit/v3/rls.proto](https://github.com/envoyproxy/data-plane-api/blob/main/envoy/service/ratelimit/v3/rls.proto) の Request, Response でサーバーを実装すれば良いのですが、[github.com/envoyproxy/ratelimit](https://github.com/envoyproxy/ratelimit) という汎用的な RateLimit サーバーが存在します。上の図に Redis が入っているのはこのサーバーを意識しているからで、サーバーの実装は自由です。ちなみに毎秒の Rete Limit をかけたい場合はもう一つ Redis を別に用意するのが推奨されています。大量の Key が作成されますからね。

https://github.com/envoyproxy/ratelimit

[envoyproxy/ratelimit](https://github.com/envoyproxy/ratelimit) は現在も機能追加が続いており、2021年01月16日時点で tag は 1.4.0 が最新ですが、master とは結構差があります。Redis Sentinel や Redis Cluster への対応や Memcached への対応が追加されていたり、設定ファイルのリロードまわりが変わっていたりします。他にもログフォーマットを JSON にできたり。

今のところ等価のようですが、Envoy の API v2, v3 とで2つの rls.proto が存在し、将来的に v2 の方は削除されるようです。

詳細は ratelimit の repository を確認してください。

envoyproxy/ratelimit デプロイ
-------------------------

Kubernetes への deploy に使える Helm chart を書いてみました。

*   [statsd-exporter](https://hub.docker.com/r/prom/statsd-exporter) で Prometheus 用の metrics endpoint を sidecar で用意
*   Prometheus Operator 用の ServiceMonitor 対応
*   [kiwigrid/k8s-sidecar](https://hub.docker.com/r/kiwigrid/k8s-sidecar) で ConfigMap を見張って設定ファイル動的に更新可能 (これを使う場合は最新の ratelimit が必要。設定ファイル更新の監視方法の問題で v1.4.0 ではダメ)

[k8s-sidecar](https://github.com/kiwigrid/k8s-sidecar) は Grafana 用の Helm Chart で使われていたので入れてみたけど、この更新方法が production 向けであるかどうかは怪しい
