---
title: 'Istio 導入への道 - Ingress Gatway 編'
date: Sun, 08 Mar 2020 14:15:13 +0000
draft: false
tags: ['Istio']
---

[Istio シリーズ](/category/kubernetes/istio/)です。

いよいよ Ingress Gateway を試します。Istio でクラスタ外からのリクエストをサービスに流すためにはこれが必要です。

Ingress Gateway の確認
-------------------

Istio のインストール時に istio-system namespace に istio-ingressgateway という Deployment がデプロイされています。

```
$ kubectl get deployment -n istio-system
NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
istio-ingressgateway   1/1     1            1           29h
istiod                 1/1     1            1           29h
prometheus             1/1     1            1           29h
```

`istio=ingressgateway` という label がついていて、[Gateway](https://istio.io/docs/reference/config/networking/gateway/) で通常これが指定されます。

```
$ kubectl get deployment -n istio-system istio-ingressgateway -o json | jq .metadata.labels
{
  "app": "istio-ingressgateway",
  "istio": "ingressgateway",
  "operator.istio.io/component": "IngressGateways",
  "operator.istio.io/managed": "Reconcile",
  "operator.istio.io/version": "1.5.0",
  "release": "istio"
}
```

また、istio-ingressgateway という Service も存在します。これが外部からのリクエストの受け口です。デフォルトで沢山の port が登録されてます（なぜなのかはまだ良く知らないけど Grafana, Prometheus, Kiali などにアクセスするためかな？）。また、デフォルトで type: LoadBalancer となっているため Minikube でも EXTERNAL-IP でアクセスできるように1回目の[インストール編](/2020/03/istio-part1/)で `minikube tunnel` を実行していたのでした。やっと出番がきました。

```
$ kubectl get svc -n istio-system -l app=istio-ingressgateway     
NAME                   TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)                                                                                                                      AGE
istio-ingressgateway   LoadBalancer   10.108.149.40   10.108.149.40   15020:30271/TCP,80:30723/TCP,443:32691/TCP,15029:30831/TCP,15030:30169/TCP,15031:32095/TCP,15032:30604/TCP,15443:30854/TCP   29h
```

何も設定しない状態では中のサービス名を指定してもアクセスできません。

```
$ curl --resolve httpbin-service:80:10.108.149.40 -sv http://httpbin-service/
* Added httpbin-service:80:10.108.149.40 to DNS cache
* Hostname httpbin-service was found in DNS cache
*   Trying 10.108.149.40...
* TCP_NODELAY set
* Connected to httpbin-service (10.108.149.40) port 80 (#0)
> GET / HTTP/1.1
> Host: httpbin-service
> User-Agent: curl/7.64.1
> Accept: */*
> 
< HTTP/1.1 404 Not Found
< date: Sun, 08 Mar 2020 13:28:28 GMT
< server: istio-envoy
< content-length: 0
< 
* Connection #0 to host httpbin-service left intact
* Closing connection 0
```

istio-ingressgateway のログ

```
{
  "authority": "httpbin-service",
  "bytes_received": "0",
  "bytes_sent": "0",
  "downstream_local_address": "172.17.0.6:80",
  "downstream_remote_address": "192.168.64.1:52499",
  "duration": "0",
  "istio_policy_status": "-",
  "method": "GET",
  "path": "/",
  "protocol": "HTTP/1.1",
  "request_id": "edfbfa06-60ba-4500-b80a-069d68967877",
  "requested_server_name": "-",
  "response_code": "404",
  "response_flags": "-",
  "route_name": "default",
  "start_time": "2020-03-08T13:28:28.477Z",
  "upstream_cluster": "-",
  "upstream_host": "-",
  "upstream_local_address": "-",
  "upstream_service_time": "-",
  "upstream_transport_failure_reason": "-",
  "user_agent": "curl/7.64.1",
  "x_forwarded_for": "192.168.64.1"
}
```

404 が返されるのは blackhole 設定によるものです。

```
$ istioctl -n istio-system proxy-config route istio-ingressgateway-757f454bff-57l8j --name http.80 -o json
[
    {
        "name": "http.80",
        "virtualHosts": [
            {
                "name": "blackhole:80",
                "domains": [
                    "*"
                ],
                "routes": [
                    {
                        "name": "default",
                        "match": {
                            "prefix": "/"
                        },
                        "directResponse": {
                            "status": 404
                        }
                    }
                ]
            }
        ],
        "validateClusters": false
    }
]
```

Gateway の登録
-----------

次のようにして Gateway を登録します。**servers** 内の **hosts** は Host Header を見てどれを対象とするかの定義です。ここでは httpbin.local という DNS 登録がされているということにします。この **hosts** には FQDN を指定する必要があります。

```
$ kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: httpbin-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "httpbin.local"
EOF
```

これだけではまだ httpbin.local なんてどこに流せば良いのか定義されていないためたどり着けません。

VirtualService と Gateway の紐付け
-----------------------------

それではたどり着けるようにするためにどうすれば良いかというと、[VirtualService](https://istio.io/docs/reference/config/networking/virtual-service/) と紐づけるのです。VirtualService はすでにこれまでに設定していますが、まだ使っていない gateways という項目がありました。

gateway を設定していない状態ではこんな感じです。

```
$ kubectl get vs
NAME                      GATEWAYS   HOSTS               AGE
httpbin-virtual-service              [httpbin-service]   22h
```

ここで gateways を追加します。他の設定は前回のままで、ここでは特に意味はない。

```
$ kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: httpbin-virtual-service
spec:
spec:
  hosts:
  - httpbin-service
  **gateways:**
  **- httpbin-gateway**
  **- mesh**
  http:
  - retries:
      attempts: 10
    route:
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

未定義の場合は暗黙的に mesh が設定されいます。定義するとクラスタ内でのサービス間通信にも使う場合は mesh も明示する必要があります。

```
$ kubectl get vs                         
NAME                      GATEWAYS                 HOSTS               AGE
httpbin-virtual-service   [httpbin-gateway mesh]   [httpbin-service]   22h
```

gateways が表示されるようになりました。httpbin-gateway と紐づけられました。これで外部からアクセス出来るぞ。

と思いきや...

```
$ curl --resolve httpbin.local:80:10.108.149.40 -sI http://httpbin.local/ip
HTTP/1.1 404 Not Found
date: Sun, 08 Mar 2020 13:55:57 GMT
server: istio-envoy
transfer-encoding: chunked
```

なぜか？

VirtualService にも hosts という定義があるのを忘れていました。ここにマッチするトラフィックが対象となるのです。httpbin.local なんてホストは知らないのです。

Gateway 側の hosts に httpbin-service.default.svc.cluster.local を登録してやればこの名前でアクセスは出来るけれども、外から変こんな名前でアクセスさせることはないでしょう。

で、VirtualService を再度更新します。

```
$ kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: httpbin-virtual-service
spec:
spec:
  hosts:
  - httpbin-service
  - **httpbin.local**
  gateways:
  - httpbin-gateway
  - mesh
  http:
  - retries:
      attempts: 10
    route:
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

やっとアクセスできました 🎉

```
❯ curl --resolve httpbin.local:80:10.108.149.40 -sv http://httpbin.local/headers
* Added httpbin.local:80:10.108.149.40 to DNS cache
* Hostname httpbin.local was found in DNS cache
*   Trying 10.108.149.40...
* TCP_NODELAY set
* Connected to httpbin.local (10.108.149.40) port 80 (#0)
> GET /headers HTTP/1.1
> Host: httpbin.local
> User-Agent: curl/7.64.1
> Accept: */*
> 
< HTTP/1.1 200 OK
< server: istio-envoy
< date: Sun, 08 Mar 2020 14:05:34 GMT
< content-type: application/json
< content-length: 586
< access-control-allow-origin: *
< access-control-allow-credentials: true
< x-envoy-upstream-service-time: 10
< 
{
  "headers": {
    "Accept": "*/*", 
    "Content-Length": "0", 
    "Host": "httpbin.local", 
    "User-Agent": "curl/7.64.1", 
    "X-B3-Parentspanid": "980378ff536f223a", 
    "X-B3-Sampled": "0", 
    "X-B3-Spanid": "9b9d2d304765951f", 
    "X-B3-Traceid": "5253e2d7d92631ca980378ff536f223a", 
    "X-Envoy-Internal": "true", 
    "X-Forwarded-Client-Cert": "By=spiffe://cluster.local/ns/default/sa/default;Hash=347ea3e62512fc49669288a4f10b74ecaba25d194f3bf57f55e14985077d780b;Subject=\"\";URI=spiffe://cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account"
  }
}
* Connection #0 to host httpbin.local left intact
* Closing connection 0
```

ingress gateway のログです

```
{
  "authority": "httpbin.local",
  "bytes_received": "0",
  "bytes_sent": "586",
  "downstream_local_address": "172.17.0.6:80",
  "downstream_remote_address": "192.168.64.1:54868",
  "duration": "10",
  "istio_policy_status": "-",
  "method": "GET",
  "path": "/headers",
  "protocol": "HTTP/1.1",
  "request_id": "d1c07002-8a22-4d89-97c8-862603926368",
  "requested_server_name": "-",
  "response_code": "200",
  "response_flags": "-",
  "route_name": "-",
  "start_time": "2020-03-08T14:05:34.372Z",
  "upstream_cluster": "outbound|80|v2|httpbin-service.default.svc.cluster.local",
  "upstream_host": "172.17.0.8:80",
  "upstream_local_address": "172.17.0.6:40834",
  "upstream_service_time": "10",
  "upstream_transport_failure_reason": "-",
  "user_agent": "curl/7.64.1",
  "x_forwarded_for": "192.168.64.1"
}
```

### istioctl コマンドで確認

```
$ istioctl proxy-config listener $(kubectl get pods -n istio-system -l istio=ingressgateway -o=jsonpath='{.items[0].metadata.name}') -n istio-system
ADDRESS     PORT      TYPE
0.0.0.0     80        HTTP
0.0.0.0     15090     HTTP
```

```
$ istioctl proxy-config route $(kubectl get pods -n istio-system -l istio=ingressgateway -o=jsonpath='{.items[0].metadata.name}') -n istio-system -o json | jq .
[
  {
    "name": "http.80",
    "virtualHosts": [
      {
        "name": "httpbin.local:80",
        "domains": [
          "httpbin.local",
          "httpbin.local:80"
        ],
        "routes": [
          {
            "match": {
              "prefix": "/"
            },
            "route": {
              "cluster": "outbound|80|v2|httpbin-service.default.svc.cluster.local",
              "timeout": "0s",
              "retryPolicy": {
                "retryOn": "connect-failure,refused-stream,unavailable,cancelled,resource-exhausted,retriable-status-codes",
                "numRetries": 10,
                "retryHostPredicate": [
                  {
                    "name": "envoy.retry_host_predicates.previous_hosts"
                  }
                ],
                "hostSelectionRetryMaxAttempts": "5",
                "retriableStatusCodes": [
                  503
                ]
              },
              "maxGrpcTimeout": "0s"
            },
            "metadata": {
              "filterMetadata": {
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
      }
    ],
    "validateClusters": false
  },
  {
    "virtualHosts": [
      {
        "name": "backend",
        "domains": [
          "*"
        ],
        "routes": [
          {
            "match": {
              "prefix": "/stats/prometheus"
            },
            "route": {
              "cluster": "prometheus_stats"
            }
          }
        ]
      }
    ]
  }
]
```

インデントのスペース4つはちょっと横にのびるので jq をかましてみた。

今回は Host ヘッダーで紐付けましたが、http 以外では port 番号で紐付けたりします。それはまた別途。

[続く](/2020/03/istio-part7/)

* * *

Istio 導入への道シリーズ

* [Istio 導入への道 (1) – インストール編](/2020/03/istio-part1/)
* [Istio 導入への道 (2) – サービス間通信編](/2020/03/istio-part2/)
* [Istio 導入への道 (3) – VirtualService 編](/2020/03/istio-part3/)
* [Istio 導入への道 (4) – Fault Injection 編](/2020/03/istio-part4/)
* [Istio 導入への道 (5) – OutlierDetection と Retry 編](/2020/03/istio-part5/)
* Istio 導入への道 (6) – Ingress Gatway 編
* [Istio 導入への道 (7) – 外部へのアクセス / ServiceEntry 編](/2020/03/istio-part7/)
* [Istio 導入への道 (8) – 外部へのアクセスでも Fault Injection 編](/2020/03/istio-part8/)
* [Istio 導入への道 (9) – gRPC でも Fault Injection 編](/2020/03/istio-part9/)
* [Istio 導入への道 (10) – 図解](/2020/03/istio-part10/)
* [Istio 導入への道 (11) – Ingress Gateway で TLS Termination 編](/2020/03/istio-part11/)
