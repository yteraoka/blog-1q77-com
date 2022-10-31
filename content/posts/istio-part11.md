---
title: 'Istio 導入への道 – Ingress Gateway で TLS Termination 編'
date: Fri, 20 Mar 2020 15:02:51 +0000
draft: false
tags: ['Istio', 'Kubernetes']
---

[Istio シリーズ](/tags/istio/) 第11回です。

TLS Termination
---------------

外部からのアクセスを Istio Ingrress Gateway に TLS の Temination をさせたいことがありますね。今回はこれを試します。

TLS Termination の設定は [Gateway](https://istio.io/docs/reference/config/networking/gateway/) で行います。

Gateway のドキュメントには次のような設定をしろとあります。

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: my-tls-ingress
spec:
  selector:
    app: my-tls-ingress-gateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - "*"
    tls:
      mode: SIMPLE
      serverCertificate: /etc/certs/server.pem
      privateKey: /etc/certs/privatekey.pem
```

が、、、証明書や鍵のファイルパスが指定されています 🤔

ドメイン追加の度に新たな Secrets をマウントするの？まさか

ということでさらに調べてみると「[Secure Gateways (SDS)](https://istio.io/docs/tasks/traffic-management/ingress/secure-ingress-sds/)」というものが見つかりました。SDS とは Secret Discovery Service の略でした。

自己署名の証明書作成
----------

```
$ openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
    -keyout server.key -out server.crt \
    -subj "/CN=httpbin.example.com/"
```

などとすれば作れますが、最近はブラウザがうるさいので `*.local.1q77.com` の証明書を Let's Encrypt で取得しました。これは後で [cert-manager](https://cert-manager.io/docs/installation/kubernetes/) 管理にしよう。（後日、[cert-manager で証明書管理](/2020/03/cert-manager/)という記事を書きました。）

SDS を有効にする （のは不要っぽい）
--------------------

Istio インストール時に有効にしていない場合は SDS を有効にする必要があると書いてありますが、1.5.0 の istioctl に入ってる helm に `gateways.istio-ingressgateway.sds.enabled` は見当たらないので不要みたいです。`global.sds.enabled` っていうのはあるけどこれはまた別用途っぽい。

秘密鍵と証明書を Secrets として登録する
------------------------

Secrets の名前を `istio` や `prometheus` で始めてはダメらしい。また、中に `token` というフィールドを入れてもダメらしい。今回は httpbin サービスで使うのでドキュメントの例と同じく **httpbin-credential** という名前にしました。istio-system namespace 内の istio-ingressgateway Pod で使われるため istio-system namespace に作る必要があるみたい。

```
$ kubectl create -n istio-system secret generic httpbin-credential \
    --from-file=key=_.local.1q77.com.key \
    --from-file=cert=_.local.1q77.com.crt
```

Gateway を設定する
-------------

Istio Ingress Gateway に対して Gateway を設定する。これは Ingress で受け入れるトラフィックを指定する。port 80 の HTTP, port 443 の HTTPS で httpbin.local.1q77.com 宛て（Header や SNI）のトラフィックを受け入れます。TLS Termination も Gateway で設定します。tls.mode の SIMPLE が通常の TLS モードです。証明書は Secret の名前で指定しています。

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: httpbin-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      name: http
      number: 80
      protocol: HTTP
    hosts:
    - httpbin.local.1q77.com
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - httpbin.local.1q77.com
    tls:
      mode: SIMPLE
      credentialName: httpbin-credential
```

istio-ingressgateway の Envoy の設定には次のようなものが入っていました。Unix Domain Socket で gRPC 通信して証明書を取得してるんですね。`/var/run/ingress_gateway` は EmptyDir をマウントしてるようですが、initContainer も sidecar も無いのに何とどうやって通信してるのだろうか？と思ったら istio-ingressgateway では **pilot-agent** と **envoy** の2つのプロセスが起動してました。

```json
         "transport_socket": {
          "name": "envoy.transport_sockets.tls",
          "typed_config": {
           "@type": "type.googleapis.com/envoy.api.v2.auth.DownstreamTlsContext",
           "common_tls_context": {
            "alpn_protocols": [
             "h2",
             "http/1.1"
            ],
            "tls_certificate_sds_secret_configs": [
             {
              "name": "httpbin-credential",
              "sds_config": {
               "api_config_source": {
                "api_type": "GRPC",
                "grpc_services": [
                 {
                  "google_grpc": {
                   "target_uri": "unix:/var/run/ingress_gateway/sds",
                   "stat_prefix": "sdsstat"
                  }
                 }
                ]
               }
              }
             }
            ]
           },
           "require_client_certificate": false
          }
         }
```

SDS 経由で取得した証明書や鍵も config に入っている。秘密鍵は Envoy の config\_dump endpoint では隠されているようです。

```json
  {
   "@type": "type.googleapis.com/envoy.admin.v3.SecretsConfigDump",
   "dynamic_active_secrets": [
    {
     "name": "httpbin-credential",
     "version_info": "2020-03-20 13:41:23.834387716 +0000 UTC m=+500189.387794816",
     "last_updated": "2020-03-20T13:41:23.839Z",
     "secret": {
      "@type": "type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.Secret",
      "name": "httpbin-credential",
      "tls_certificate": {
       "certificate_chain": {
        "inline_bytes": "PEM がさらに base64 でエンコードされた値"
       },
       "private_key": {
        "inline_bytes": "W3JlZGFjdGVkXQ=="
       }
      }
     }
    },
```

VirtualService を設定する
--------------------

Gateway と Service を紐づけるのが VirtualService で Fault Injection や Path や Header による Routing を設定するのも VirtualService です。

httpbin-virtual-service という名前でこれまでも設定してありましたが、**hosts** に **httpbin.local.1q77.com** を追加しました。

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: httpbin-virtual-service
spec:
  gateways:
  - httpbin-gateway
  - mesh
  hosts:
  - httpbin-service
  - httpbin.local.1q77.com
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
```

**gateways** に **httpbin-gateway** が入っているので、上の Gateway 設定を紐づいています。これにより Gateway で受け入れた httpbin.local.1q77.com 宛てのリクエストは httpbin-service に送られます。destination が2つ設定されていることは今回の件では特に意味はありません。

ログを確認する
-------

Istio Ingress Gateway の Service が Listen してるところに curl でアクセスすれば httpbin サービスが結果を返すはずです。hosts なり DNS なりで設定すると良いでしょう。（ところで mac は hosts で同じ IP アドレスに沢山設定しすぎると5秒待たされたりする？？ちゃんと調べてないけどそんな感じだったのでもう Route53 にワイルドカードでプライベートアドレスを入れることにした）

### クラスタ外から curl でアクセス

`minikube tunnel` を使ってクラスタ外から `curl https://httpbin.local.1q77.com/ip` としてアクセスしています。

#### istio-ingressgateway Pod の Envoy のログ

port 443 で受けて TLS 終端の後に httpbin Pod の　port 80 に送っています。

```json
{
  "authority": "httpbin.local.1q77.com",
  "bytes_received": "0",
  "bytes_sent": "31",
  "downstream_local_address": "172.17.0.6:443",
  "downstream_remote_address": "192.168.64.1:51276",
  "duration": "3",
  "istio_policy_status": "-",
  "method": "GET",
  "path": "/ip",
  "protocol": "HTTP/2",
  "request_id": "26d8034e-df98-4d79-be70-9f3d20287623",
  "requested_server_name": "httpbin.local.1q77.com",
  "response_code": "200",
  "response_flags": "-",
  "route_name": "-",
  "start_time": "2020-03-20T13:12:11.904Z",
  "upstream_cluster": "outbound|80|v2|httpbin-service.default.svc.cluster.local",
  "upstream_host": "172.17.0.13:80",
  "upstream_local_address": "172.17.0.6:34718",
  "upstream_service_time": "3",
  "upstream_transport_failure_reason": "-",
  "user_agent": "curl/7.64.1",
  "x_forwarded_for": "192.168.64.1"
}
```

#### httpbin Pod の Envoy のログ

Sidecar Envoy が port 80 で受けて　127.0.0.1:80 に流しています。

```json
{
  "authority": "httpbin.local.1q77.com",
  "bytes_received": "0",
  "bytes_sent": "31",
  "downstream_local_address": "172.17.0.13:80",
  "downstream_remote_address": "192.168.64.1:0",
  "duration": "2",
  "istio_policy_status": "-",
  "method": "GET",
  "path": "/ip",
  "protocol": "HTTP/1.1",
  "request_id": "26d8034e-df98-4d79-be70-9f3d20287623",
  "requested_server_name": "outbound_.80_.v2_.httpbin-service.default.svc.cluster.local",
  "response_code": "200",
  "response_flags": "-",
  "route_name": "default",
  "start_time": "2020-03-20T13:12:11.904Z",
  "upstream_cluster": "inbound|80|http|httpbin-service.default.svc.cluster.local",
  "upstream_host": "127.0.0.1:80",
  "upstream_local_address": "127.0.0.1:50922",
  "upstream_service_time": "1",
  "upstream_transport_failure_reason": "-",
  "user_agent": "curl/7.64.1",
  "x_forwarded_for": "192.168.64.1"
}
```

### クラスタ内から curl でアクセス

クラスタ内で名前解決すると Istio Ingress Gateway Service の Cluster IP が返ってきました。

```
root@ubuntu-deployment-54bbd6f4ff-q9sdj:/# host httpbin.local.1q77.com
httpbin.local.1q77.com has address 10.108.149.40
```

```
$ kubectl get svc -n istio-system -l app=istio-ingressgateway
NAME                   TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)                                                                                                                      AGE
istio-ingressgateway   LoadBalancer   10.108.149.40   10.108.149.40   15020:30271/TCP,80:30723/TCP,443:32691/TCP,15029:30831/TCP,15030:30169/TCP,15031:32095/TCP,15032:30604/TCP,15443:30854/TCP   13d
```

よって、クライアントとしての ubuntu Pod から istio-ingressgateway Pod で TLS が終端され、httpbin Pod にリクエストが届いています。

#### クライアントとしての ubuntu Pod の Envoy のログ

https なのでリクエストの中身は見えていません。

```json
{
  "authority": "-",
  "bytes_received": "853",
  "bytes_sent": "3801",
  "downstream_local_address": "10.108.149.40:443",
  "downstream_remote_address": "172.17.0.8:45198",
  "duration": "34",
  "istio_policy_status": "-",
  "method": "-",
  "path": "-",
  "protocol": "-",
  "request_id": "-",
  "requested_server_name": "-",
  "response_code": "0",
  "response_flags": "-",
  "route_name": "-",
  "start_time": "2020-03-20T13:16:49.990Z",
  "upstream_cluster": "outbound|443||istio-ingressgateway.istio-system.svc.cluster.local",
  "upstream_host": "172.17.0.6:443",
  "upstream_local_address": "172.17.0.8:39294",
  "upstream_service_time": "-",
  "upstream_transport_failure_reason": "-",
  "user_agent": "-",
  "x_forwarded_for": "-"
}
```

#### istio-ingressgateway Pod の Envoy のログ

ここでは TLS が終端されているため、HTTP リクエストの中身がログに出ています。`downstream_local_address` と `upstream_host` から port 443 で受けて port 80 に流していることがわかります。

```json
{
  "authority": "httpbin.local.1q77.com",
  "bytes_received": "0",
  "bytes_sent": "29",
  "downstream_local_address": "172.17.0.6:443",
  "downstream_remote_address": "172.17.0.8:39294",
  "duration": "2",
  "istio_policy_status": "-",
  "method": "GET",
  "path": "/ip",
  "protocol": "HTTP/2",
  "request_id": "9f6c5280-554b-449a-b82f-f2df6a43d785",
  "requested_server_name": "httpbin.local.1q77.com",
  "response_code": "200",
  "response_flags": "-",
  "route_name": "-",
  "start_time": "2020-03-20T13:16:50.002Z",
  "upstream_cluster": "outbound|80|v2|httpbin-service.default.svc.cluster.local",
  "upstream_host": "172.17.0.13:80",
  "upstream_local_address": "172.17.0.6:34718",
  "upstream_service_time": "2",
  "upstream_transport_failure_reason": "-",
  "user_agent": "curl/7.58.0",
  "x_forwarded_for": "172.17.0.8"
}
```

#### httpbin Pod の Envoy のログ

```json
{
  "authority": "httpbin.local.1q77.com",
  "bytes_received": "0",
  "bytes_sent": "29",
  "downstream_local_address": "172.17.0.13:80",
  "downstream_remote_address": "172.17.0.8:0",
  "duration": "1",
  "istio_policy_status": "-",
  "method": "GET",
  "path": "/ip",
  "protocol": "HTTP/1.1",
  "request_id": "9f6c5280-554b-449a-b82f-f2df6a43d785",
  "requested_server_name": "outbound_.80_.v2_.httpbin-service.default.svc.cluster.local",
  "response_code": "200",
  "response_flags": "-",
  "route_name": "default",
  "start_time": "2020-03-20T13:16:50.003Z",
  "upstream_cluster": "inbound|80|http|httpbin-service.default.svc.cluster.local",
  "upstream_host": "127.0.0.1:80",
  "upstream_local_address": "127.0.0.1:59168",
  "upstream_service_time": "1",
  "upstream_transport_failure_reason": "-",
  "user_agent": "curl/7.58.0",
  "x_forwarded_for": "172.17.0.8"
}
```

* * *

Istio 導入への道シリーズ

* [Istio 導入への道 (1) – インストール編](/2020/03/istio-part1/)
* [Istio 導入への道 (2) – サービス間通信編](/2020/03/istio-part2/)
* [Istio 導入への道 (3) – VirtualService 編](/2020/03/istio-part3/)
* [Istio 導入への道 (4) – Fault Injection 編](/2020/03/istio-part4/)
* [Istio 導入への道 (5) – OutlierDetection と Retry 編](/2020/03/istio-part5/)
* [Istio 導入への道 (6) – Ingress Gatway 編](/2020/03/istio-part6/)
* [Istio 導入への道 (7) – 外部へのアクセス / ServiceEntry 編](/2020/03/istio-part7/)
* [Istio 導入への道 (8) – 外部へのアクセスでも Fault Injection 編](/2020/03/istio-part8/)
* [Istio 導入への道 (9) – gRPC でも Fault Injection 編](/2020/03/istio-part9/)
* [Istio 導入への道 (10) – 図解](/2020/03/istio-part10/)
* Istio 導入への道 (11) – Ingress Gateway で TLS Termination 編
