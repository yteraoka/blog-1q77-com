---
title: 'Istio 導入への道 - OutlierDetection と Retry 編'
date: Sun, 08 Mar 2020 13:11:21 +0000
draft: false
tags: ['Istio']
---

[Istio シリーズ](/tags/istio/)です。

そういえば Ingress Gateway になかなか辿りつかないな。

OutlierDetection 設定
-------------------

OutlierDetection は [DestinationRule](https://istio.io/docs/reference/config/networking/destination-rule/#OutlierDetection) に設定するものでドキュメントもそこにあります。

一旦 VirtualService での転送先を v2 だけにします。

```yaml
$ kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: httpbin-virtual-service
spec:
  hosts:
  - httpbin-service
  http:
  - route:
    - destination:
        host: httpbin-service
        subset: v1
      weight: 0
    - destination:
        host: httpbin-service
        subset: v2
      weight: 100
EOF
```

OutlierDetection で Target を Evict するには転送先にいくつかの Pod が必要なので replica 数を増やします。

```bash
kubectl scale --replicas=5 deployment/httpbin-deployment-v2
```

次に、DestinationRule に OutlierDetection を設定します。

```yaml
$ kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: httpbin-destination-rule
spec:
  host: httpbin-service
  trafficPolicy:
    outlierDetection:
      consecutiveErrors: 3
      interval: 10s
      baseEjectionTime: 1m
      maxEjectionPercent: 100
      minHealthPercent: 1
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
EOF
```

しかし、これはどうやって確認すれば良いのだろうか？ envoy の 15000/stats へアクセスしてみるのかな？後でわかります。

httpbin.org は `/status/500` とか `/status/503` にアクセスすれば任意の status code を返させることができます。`/status/503` にアクセスしてみると curl を実行する側の Pod の istio-proxy のログには1つしか出ませんが、転送先は3つの Pod にアクセスがありました。500 や 502, 504 ではどれも転送先でも1つしかログは出ませんでしたし、response\_flags は空でした。retry しても 503 の場合は response\_flag が URX になっています。response\_flag の意味は [Envoy のドキュメント](https://www.envoyproxy.io/docs/envoy/v1.13.0/configuration/observability/access_log#config-access-log-format-response-flags)にあります。`URX` の意味は "The request was rejected because the upstream retry limit (HTTP) or maximum connect attempts (TCP) was reached." **"response\_flags": "UF,URX"** と、カンマ区切りで複数入っていることもありました。

```json
{
  "authority": "httpbin-service",
  "bytes_received": "0",
  "bytes_sent": "0",
  "downstream_local_address": "10.109.118.31:80",
  "downstream_remote_address": "172.17.0.9:54610",
  "duration": "79",
  "istio_policy_status": "-",
  "method": "GET",
  "path": "/status/503",
  "protocol": "HTTP/1.1",
  "request_id": "682de904-a1f8-45ec-bc7e-d755a47a130d",
  "requested_server_name": "-",
  "response_code": "503",
  "response_flags": "URX",
  "route_name": "-",
  "start_time": "2020-03-08T06:51:32.094Z",
  "upstream_cluster": "outbound|80|v2|httpbin-service.default.svc.cluster.local",
  "upstream_host": "172.17.0.13:80",
  "upstream_local_address": "172.17.0.9:58194",
  "upstream_service_time": "78",
  "upstream_transport_failure_reason": "-",
  "user_agent": "curl/7.58.0",
  "x_forwarded_for": "-"
}
```

転送先のログ

```json
{
  "authority": "httpbin-service",
  "bytes_received": "0",
  "bytes_sent": "0",
  "downstream_local_address": "172.17.0.8:80",
  "downstream_remote_address": "172.17.0.9:36276",
  "duration": "1",
  "istio_policy_status": "-",
  "method": "GET",
  "path": "/status/503",
  "protocol": "HTTP/1.1",
  "request_id": "682de904-a1f8-45ec-bc7e-d755a47a130d",
  "requested_server_name": "outbound_.80_.v2_.httpbin-service.default.svc.cluster.local",
  "response_code": "503",
  "response_flags": "-",
  "route_name": "default",
  "start_time": "2020-03-08T06:51:32.094Z",
  "upstream_cluster": "inbound|80|http|httpbin-service.default.svc.cluster.local",
  "upstream_host": "127.0.0.1:80",
  "upstream_local_address": "127.0.0.1:57664",
  "upstream_service_time": "1",
  "upstream_transport_failure_reason": "-",
  "user_agent": "curl/7.58.0",
  "x_forwarded_for": "-"
}

{
  "authority": "httpbin-service",
  "bytes_received": "0",
  "bytes_sent": "0",
  "downstream_local_address": "172.17.0.10:80",
  "downstream_remote_address": "172.17.0.9:44944",
  "duration": "2",
  "istio_policy_status": "-",
  "method": "GET",
  "path": "/status/503",
  "protocol": "HTTP/1.1",
  "request_id": "682de904-a1f8-45ec-bc7e-d755a47a130d",
  "requested_server_name": "outbound_.80_.v2_.httpbin-service.default.svc.cluster.local",
  "response_code": "503",
  "response_flags": "-",
  "route_name": "default",
  "start_time": "2020-03-08T06:51:32.117Z",
  "upstream_cluster": "inbound|80|http|httpbin-service.default.svc.cluster.local",
  "upstream_host": "127.0.0.1:80",
  "upstream_local_address": "127.0.0.1:57666",
  "upstream_service_time": "1",
  "upstream_transport_failure_reason": "-",
  "user_agent": "curl/7.58.0",
  "x_forwarded_for": "-"
}

{
  "authority": "httpbin-service",
  "bytes_received": "0",
  "bytes_sent": "0",
  "downstream_local_address": "172.17.0.13:80",
  "downstream_remote_address": "172.17.0.9:58194",
  "duration": "2",
  "istio_policy_status": "-",
  "method": "GET",
  "path": "/status/503",
  "protocol": "HTTP/1.1",
  "request_id": "682de904-a1f8-45ec-bc7e-d755a47a130d",
  "requested_server_name": "outbound_.80_.v2_.httpbin-service.default.svc.cluster.local",
  "response_code": "503",
  "response_flags": "-",
  "route_name": "default",
  "start_time": "2020-03-08T06:51:32.170Z",
  "upstream_cluster": "inbound|80|http|httpbin-service.default.svc.cluster.local",
  "upstream_host": "127.0.0.1:80",
  "upstream_local_address": "127.0.0.1:57668",
  "upstream_service_time": "1",
  "upstream_transport_failure_reason": "-",
  "user_agent": "curl/7.58.0",
  "x_forwarded_for": "-"
}
```

Retry について
----------

Retry の回数などは VirtualService の [http.retries.attempts](https://istio.io/docs/reference/config/networking/virtual-service/#HTTPRetry) などで設定することができます。Outlier の話から外れちゃうけどここで retries をいじってみます。

```yaml
$ kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: httpbin-virtual-service
spec:
  hosts:
  - httpbin-service
  http:
  - route:
    - destination:
        host: httpbin-service
        subset: v1
      weight: 0
    - destination:
        host: httpbin-service
        subset: v2
      weight: 100
    retries:
      attempts: 10
EOF
```

curl を実行する Pod で **http://localhost:15000/config\_dump** を確認してみると `"num_retries": 10` になりました。`"retry_on": "connect-failure,refused-stream,unavailable,cancelled,resource-exhausted,retriable-status-codes"` ということなので、 **x-envoy-retriable-status-codes** ヘッダーで指定すれば 503 以外でも retry してくれそうです。

```json
        "routes": [
         {
          "match": {
           "prefix": "/"
          },
          "route": {
           "cluster": "outbound|80|v2|httpbin-service.default.svc.cluster.local",
           "timeout": "0s",
           "retry_policy": {
            "retry_on": "connect-failure,refused-stream,unavailable,cancelled,resource-exhausted,retriable-status-codes"
,
            "num_retries": 10,
            "retry_host_predicate": [
             {
              "name": "envoy.retry_host_predicates.previous_hosts"
             }
            ],
            "host_selection_retry_max_attempts": "5",
            "retriable_status_codes": [
             503
            ]
           },
           "max_grpc_timeout": "0s"
          },
          "metadata": {
           "filter_metadata": {
            "istio": {
             "config": "/apis/networking.istio.io/v1alpha3/namespaces/default/virtual-service/httpbin-virtual-service"
            }
           }
          },
          "decorator": {
           "operation": "httpbin-service.default.svc.cluster.local:80/*"
          }
         }
        ]
```

`"num_retries": 10` になったことで、合計のアクセス回数が11回になりました。デフォルトは2だったということですね。

次に 502 でも retry されるかどうか **x-envoy-retriable-status-codes** ヘッダーを試しましたが、、期待の動作にならなりませんでした... 🤔

OutlierDetection を状態を確認しながらテスト
------------------------------

話を OutlierDetection に戻します。`istioctl proxy-config` コマンドで OUTLIER CHECK の状態が確認できることがわかりました。

```
$ istioctl proxy-config endpoint ubuntu-deployment-cc86cc647-vsvbh | egrep '^ENDPOINT|v2\|httpbin'
ENDPOINT                        STATUS      OUTLIER CHECK     CLUSTER
172.17.0.10:80                  HEALTHY     OK                outbound|80|v2|httpbin-service.default.svc.cluster.local
172.17.0.11:80                  HEALTHY     OK                outbound|80|v2|httpbin-service.default.svc.cluster.local
172.17.0.12:80                  HEALTHY     OK                outbound|80|v2|httpbin-service.default.svc.cluster.local
172.17.0.13:80                  HEALTHY     OK                outbound|80|v2|httpbin-service.default.svc.cluster.local
172.17.0.8:80                   HEALTHY     OK                outbound|80|v2|httpbin-service.default.svc.cluster.local
```

次のようにして状態を確認しながら `/status/503` にアクセスをしてみます。

```
while : ; do
  date
  istioctl proxy-config endpoint ubuntu-deployment-cc86cc647-vsvbh \
    | egrep '^ENDPOINT|v2\|httpbin'
  sleep 3
done
```

```
Sun Mar  8 17:49:37 JST 2020
ENDPOINT                        STATUS      OUTLIER CHECK     CLUSTER
172.17.0.10:80                  HEALTHY     OK                outbound|80|v2|httpbin-service.default.svc.cluster.local
172.17.0.11:80                  HEALTHY     OK                outbound|80|v2|httpbin-service.default.svc.cluster.local
172.17.0.12:80                  HEALTHY     OK                outbound|80|v2|httpbin-service.default.svc.cluster.local
172.17.0.13:80                  HEALTHY     OK                outbound|80|v2|httpbin-service.default.svc.cluster.local
172.17.0.8:80                   HEALTHY     OK                outbound|80|v2|httpbin-service.default.svc.cluster.local
Sun Mar  8 17:49:40 JST 2020
ENDPOINT                        STATUS      OUTLIER CHECK     CLUSTER
172.17.0.10:80                  HEALTHY     OK                outbound|80|v2|httpbin-service.default.svc.cluster.local
172.17.0.11:80                  HEALTHY     FAILED            outbound|80|v2|httpbin-service.default.svc.cluster.local
172.17.0.12:80                  HEALTHY     OK                outbound|80|v2|httpbin-service.default.svc.cluster.local
172.17.0.13:80                  HEALTHY     OK                outbound|80|v2|httpbin-service.default.svc.cluster.local
172.17.0.8:80                   HEALTHY     OK                outbound|80|v2|httpbin-service.default.svc.cluster.local
Sun Mar  8 17:49:43 JST 2020
ENDPOINT                        STATUS      OUTLIER CHECK     CLUSTER
172.17.0.10:80                  HEALTHY     FAILED            outbound|80|v2|httpbin-service.default.svc.cluster.local
172.17.0.11:80                  HEALTHY     FAILED            outbound|80|v2|httpbin-service.default.svc.cluster.local
172.17.0.12:80                  HEALTHY     FAILED            outbound|80|v2|httpbin-service.default.svc.cluster.local
172.17.0.13:80                  HEALTHY     FAILED            outbound|80|v2|httpbin-service.default.svc.cluster.local
172.17.0.8:80                   HEALTHY     FAILED            outbound|80|v2|httpbin-service.default.svc.cluster.local
```

全部 FAILED になった状態でもアクセスできました。一部だけ FAILED の時は OK の Endpoint にだけ送られました。

FAILED となって外されている期間は baseEjectionTime かける eject された回数時間になるようです。

[続く。。](/2020/03/istio-part6/)

* * *

Istio 導入への道シリーズ

* [Istio 導入への道 (1) – インストール編](/2020/03/istio-part1/)
* [Istio 導入への道 (2) – サービス間通信編](/2020/03/istio-part2/)
* [Istio 導入への道 (3) – VirtualService 編](/2020/03/istio-part3/)
* [Istio 導入への道 (4) – Fault Injection 編](/2020/03/istio-part4/)
* Istio 導入への道 (5) – OutlierDetection と Retry 編
* [Istio 導入への道 (6) – Ingress Gatway 編](/2020/03/istio-part6/)
* [Istio 導入への道 (7) – 外部へのアクセス / ServiceEntry 編](/2020/03/istio-part7/)
* [Istio 導入への道 (8) – 外部へのアクセスでも Fault Injection 編](/2020/03/istio-part8/)
* [Istio 導入への道 (9) – gRPC でも Fault Injection 編](/2020/03/istio-part9/)
* [Istio 導入への道 (10) – 図解](/2020/03/istio-part10/)
* [Istio 導入への道 (11) – Ingress Gateway で TLS Termination 編](/2020/03/istio-part11/)
