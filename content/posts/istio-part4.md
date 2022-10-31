---
title: 'Istio 導入への道 - Fault Injection 編'
date: Sun, 08 Mar 2020 02:30:30 +0000
draft: false
tags: ['Istio']
---

[Istio シリーズ](/tags/istio/)です。

今回は [Fault Injection](https://istio.io/docs/reference/config/networking/virtual-service/#HTTPFaultInjection) です。前回の VirtualService に設定を入れることでわざと 503 とか 500 エラーを返したり、delay を入れたりすることができます。

500 Internal Server Error を返す
-----------------------------

現在の設定を確認。QueryString に v=1 があれば v1 に、それ意外は v2 に送られます。

```
$ kubectl get vs httpbin-virtual-service -o yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  annotations:
...
(省略)
...
spec:
  hosts:
  - httpbin-service
  http:
  - match:
    - name: v1
      queryParams:
        v:
          exact: "1"
    route:
    - destination:
        host: httpbin-service
        subset: v1
  - route:
    - destination:
        host: httpbin-service
        subset: v2
```

`route` のレベルに `fault` を入れます。v1 のところに入れてみます。([HTTPFaultInjection.Abort](https://istio.io/docs/reference/config/networking/virtual-service/#HTTPFaultInjection-Abort))

```
$ kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: httpbin-virtual-service
spec:
  hosts:
  - httpbin-service
  http:
  - match:
    - name: v1
      queryParams:
        v:
          exact: "1"
    fault:
      abort:
        httpStatus: 500
        percentage:
          value: 50
    route:
    - destination:
        host: httpbin-service
        subset: v1
  - route:
    - destination:
        host: httpbin-service
        subset: v2
EOF
```

v1 の場合に、50% の割合で 500 Internal Server Error を返すようにしました。

```
root@ubuntu-deployment-cc86cc647-vsvbh:/# curl -sv http://httpbin-service/headers\?v=1
*   Trying 10.109.118.31...
* TCP_NODELAY set
* Connected to httpbin-service (10.109.118.31) port 80 (#0)
> GET /headers?v=1 HTTP/1.1
> Host: httpbin-service
> User-Agent: curl/7.58.0
> Accept: */*
> 
< HTTP/1.1 500 Internal Server Error
< content-length: 18
< content-type: text/plain
< date: Sun, 08 Mar 2020 01:53:15 GMT
< server: envoy
< 
* Connection #0 to host httpbin-service left intact
fault filter abort
```

curl を実行した Pod 側で istio-proxy のログを確認してみると `response_flags` に `FI` (Fault Injection) と入っています。また、宛先の Pod 側ではログが出ていないため、リクエストは送られていないようです。まあそうでしょう。curl 側のログも upstream の項目が空です。

```json
{
  "authority": "httpbin-service",
  "bytes_received": "0",
  "bytes_sent": "18",
  "downstream_local_address": "10.109.118.31:80",
  "downstream_remote_address": "172.17.0.9:60170",
  "duration": "5",
  "istio_policy_status": "-",
  "method": "GET",
  "path": "/headers?v=1",
  "protocol": "HTTP/1.1",
  "request_id": "76435924-cdea-4fdb-ae52-bc5db43946fc",
  "requested_server_name": "-",
  "response_code": "500",
  "response_flags": "FI",
  "route_name": "-",
  "start_time": "2020-03-08T01:53:15.360Z",
  "upstream_cluster": "-",
  "upstream_host": "-",
  "upstream_local_address": "-",
  "upstream_service_time": "-",
  "upstream_transport_failure_reason": "-",
  "user_agent": "curl/7.58.0",
  "x_forwarded_for": "-"
}
```

percentage で 50 と指定しているため全てが 500 Error になるわけではなく、リクエストの半分です。percentage の型は double で小数で 1% 未満も指定可能です。もちろんこの設定では v2 側へのアクセス時には 500 Error は返されません。本当に Upstream 側で返されれば別でしょうが。

Delay を挿入する
-----------

次に v2 側に delay を入れてみます。([HTTPFaultInjection.Delay](https://istio.io/docs/reference/config/networking/virtual-service/#HTTPFaultInjection-Delay))

```
$ kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: httpbin-virtual-service
spec:
  hosts:
  - httpbin-service
  http:
  - match:
    - name: v1
      queryParams:
        v:
          exact: "1"
    fault:
      abort:
        httpStatus: 500
        percentage:
          value: 50
    route:
    - destination:
        host: httpbin-service
        subset: v1
  - route:
    - destination:
        host: httpbin-service
        subset: v2
    fault:
      delay:
        fixedDelay: 5s
        percentage:
          value: 50
EOF
```

これで v2 へリクエストを送る際に 50% の割合で5秒の delay が挿入されます。ログを確認してみます。

curl を実行している側の Pod の istio-proxy のログです。`"response_flags": "DI"` となっており、Delay が挿入されていることがわかります。`"start_time": "2020-03-08T02:11:04.369Z"` を宛先側のログと比較してみます。

```json
{
  "authority": "httpbin-service",
  "bytes_received": "0",
  "bytes_sent": "521",
  "downstream_local_address": "10.109.118.31:80",
  "downstream_remote_address": "172.17.0.9:47376",
  "duration": "5004",
  "istio_policy_status": "-",
  "method": "GET",
  "path": "/headers",
  "protocol": "HTTP/1.1",
  "request_id": "71da7efc-29a0-4e03-b23b-bfbf1638c273",
  "requested_server_name": "-",
  "response_code": "200",
  "response_flags": "DI",
  "route_name": "-",
  "start_time": "2020-03-08T02:11:04.369Z",
  "upstream_cluster": "outbound|80|v2|httpbin-service.default.svc.cluster.local",
  "upstream_host": "172.17.0.8:80",
  "upstream_local_address": "172.17.0.9:54576",
  "upstream_service_time": "2",
  "upstream_transport_failure_reason": "-",
  "user_agent": "curl/7.58.0",
  "x_forwarded_for": "-"
}
```

宛先側の Pod の istio-proxy のログです。`"start_time": "2020-03-08T02:11:09.371Z"` と開始が5秒遅れていることが確認できます。送信元側で待ってから送っているようです。

```json
{
  "authority": "httpbin-service",
  "bytes_received": "0",
  "bytes_sent": "521",
  "downstream_local_address": "172.17.0.8:80",
  "downstream_remote_address": "172.17.0.9:54576",
  "duration": "2",
  "istio_policy_status": "-",
  "method": "GET",
  "path": "/headers",
  "protocol": "HTTP/1.1",
  "request_id": "71da7efc-29a0-4e03-b23b-bfbf1638c273",
  "requested_server_name": "outbound_.80_.v2_.httpbin-service.default.svc.cluster.local",
  "response_code": "200",
  "response_flags": "-",
  "route_name": "default",
  "start_time": "2020-03-08T02:11:09.371Z",
  "upstream_cluster": "inbound|80|http|httpbin-service.default.svc.cluster.local",
  "upstream_host": "127.0.0.1:80",
  "upstream_local_address": "127.0.0.1:50500",
  "upstream_service_time": "1",
  "upstream_transport_failure_reason": "-",
  "user_agent": "curl/7.58.0",
  "x_forwarded_for": "-"
}
```

[次](/2020/03/istio-part5/)は OutlierDetection / 異常値検出 かな。

* * *

Istio 導入への道シリーズ

* [Istio 導入への道 (1) – インストール編](/2020/03/istio-part1/)
* [Istio 導入への道 (2) – サービス間通信編](/2020/03/istio-part2/)
* [Istio 導入への道 (3) – VirtualService 編](/2020/03/istio-part3/)
* Istio 導入への道 (4) – Fault Injection 編
* [Istio 導入への道 (5) – OutlierDetection と Retry 編](/2020/03/istio-part5/)
* [Istio 導入への道 (6) – Ingress Gatway 編](/2020/03/istio-part6/)
* [Istio 導入への道 (7) – 外部へのアクセス / ServiceEntry 編](/2020/03/istio-part7/)
* [Istio 導入への道 (8) – 外部へのアクセスでも Fault Injection 編](/2020/03/istio-part8/)
* [Istio 導入への道 (9) – gRPC でも Fault Injection 編](/2020/03/istio-part9/)
* [Istio 導入への道 (10) – 図解](/2020/03/istio-part10/)
* [Istio 導入への道 (11) – Ingress Gateway で TLS Termination 編](/2020/03/istio-part11/)
