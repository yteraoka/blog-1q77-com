---
title: 'Istio 導入への道 - gRPC でも Fault Injection 編'
date: Sat, 14 Mar 2020 16:47:43 +0000
draft: false
tags: ['Istio', 'Istio']
---

[Istio シリーズ](/category/kubernetes/istio/) 第9回です。

[Istio by Example](https://istiobyexample.dev/) に [gRPC](https://istiobyexample.dev/grpc/) というのがあった。 gRPC に delay が挿入されている。できるんだねそれも。

ということで試してみます。gRPC については全然分かってないのだけれど。。。

テスト用の gRPC サーバーとクライアントは [github.com/yteraoka/grpc-helloworld](https://github.com/yteraoka/grpc-helloworld) に用意しました。Docker Image も [yteraoka/grpc-helloworld:latest](https://hub.docker.com/repository/docker/yteraoka/grpc-helloworld) にあります。

非 TLS の場合
---------

Deployment と Service を作る Manifest です。サーバーに `-tls` オプションをつけずに実行して、Service の port name は **grpc** にしてあります。

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grpc-helloworld-deployment
  labels:
    app: grpc-helloworld
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grpc-helloworld
  template:
    metadata:
      labels:
        app: grpc-helloworld
    spec:
      containers:
      - name: helloworld
        image: yteraoka/grpc-helloworld:latest
        imagePullPolicy: IfNotPresent
        command:
        - "/server"
        ports:
        - containerPort: 10000
        readinessProbe:
          exec:
            command:
            - "/client"
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          exec:
            command:
            - "/client"
          initialDelaySeconds: 15
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: grpc-helloworld-service
spec:
  selector:
    app: grpc-helloworld
  type: ClusterIP
  ports:
  - name: **grpc**
    protocol: TCP
    port: 10000

```

クライアントに使う Pod 用の Deployment はこちら。ここから作られる Pod 内から **/client** コマンドを実行します。

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grpc-client-deployment
  labels:
    app: grpc-client
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grpc-client
  template:
    metadata:
      labels:
        app: grpc-client
    spec:
      containers:
      - name: grpc-client
        image: yteraoka/grpc-helloworld:latest
        imagePullPolicy: IfNotPresent
        command:
        - sleep
        - infinity

```

クライアントからの接続テストは次のようにします。grpc-go って接続に成功するまでずっとリトライするんですね。間隔が開いていくんで Retry with Exponential Backoff and jitter ってやつかな。

```
$ /client -server\_addr grpc-helloworld-service.default.svc.cluster.local:10000 -timeout 10 

```

### VirtualService 無しの状態でのアクセス

Envoy は protocol を理解していますね。

```
{
  "authority": "grpc-helloworld-service.default.svc.cluster.local:10000",
  "bytes\_received": "12",
  "bytes\_sent": "18",
  "downstream\_local\_address": "10.98.145.150:10000",
  "downstream\_remote\_address": "172.17.0.16:38298",
  "duration": "1",
  "istio\_policy\_status": "-",
  **"method": "POST"**,
  **"path": "/helloworld.Greeter/SayHello"**,
  **"protocol": "HTTP/2"**,
  "request\_id": "132f13ce-9503-4b4e-aaa9-ea9caf34d9a0",
  "requested\_server\_name": "-",
  "response\_code": "200",
  "response\_flags": "-",
  "route\_name": "default",
  "start\_time": "2020-03-14T15:36:25.619Z",
  "upstream\_cluster": "outbound|10000||grpc-helloworld-service.default.svc.cluster.local",
  "upstream\_host": "172.17.0.17:10000",
  "upstream\_local\_address": "172.17.0.16:56496",
  "upstream\_service\_time": "1",
  "upstream\_transport\_failure\_reason": "-",
  "user\_agent": "grpc-go/1.28.0",
  "x\_forwarded\_for": "-"
}

```

### VirtualService で Delay を挿入する

Fault Injection のために VirtualService を作成します。

VirtualService の Manifest。常に 3 秒の delay を入れます。

```
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: grpc-helloworld-virtual-service
spec:
  hosts:
  - grpc-helloworld-service
  http:
  - **fault:**
      **delay:**
        **percentage:**
          **value: 100.0**
        **fixedDelay: 3s**
    route:
    - destination:
        host: grpc-helloworld-service

```

delay を挿入した場合のログです。

```
{
  "authority": "grpc-helloworld-service.default.svc.cluster.local:10000",
  "bytes\_received": "12",
  "bytes\_sent": "18",
  "downstream\_local\_address": "10.98.145.150:10000",
  "downstream\_remote\_address": "172.17.0.16:51828",
  **"duration": "3004"**,
  "istio\_policy\_status": "-",
  "method": "POST",
  "path": "/helloworld.Greeter/SayHello",
  "protocol": "HTTP/2",
  "request\_id": "5340f5d7-f6a8-45e5-897f-ceeb3526dfd5",
  "requested\_server\_name": "-",
  "response\_code": "200",
  **"response\_flags": "DI"**,
  "route\_name": "-",
  "start\_time": "2020-03-14T12:31:59.995Z",
  "upstream\_cluster": "outbound|10000||grpc-helloworld-service.default.svc.cluster.local",
  "upstream\_host": "172.17.0.17:10000",
  "upstream\_local\_address": "172.17.0.16:41198",
  "upstream\_service\_time": "2",
  "upstream\_transport\_failure\_reason": "-",
  "user\_agent": "grpc-go/1.28.0",
  "x\_forwarded\_for": "-"
}

```

TLS 有効な場合
---------

次に TLS を有効にした gRPC サーバーとの通信で試します。サーバーとヘルスチェック用のコマンドに **\-tls** オプションをつけます。Service は port name を **tls** にします。TLS を有効にしているのに port name を grpc にしてしまうと通信できません。

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grpc-helloworld-deployment
  labels:
    app: grpc-helloworld
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grpc-helloworld
  template:
    metadata:
      labels:
        app: grpc-helloworld
    spec:
      containers:
      - name: helloworld
        image: yteraoka/grpc-helloworld:latest
        imagePullPolicy: IfNotPresent
        command:
        - "/server"
        - "**\-tls**"
        ports:
        - containerPort: 10000
        readinessProbe:
          exec:
            command:
            - "/client"
            - "**\-tls**"
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          exec:
            command:
            - "/client"
            - "**\-tls**"
          initialDelaySeconds: 15
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: grpc-helloworld-service
spec:
  selector:
    app: grpc-helloworld
  type: ClusterIP
  ports:
  - name: **tls**
    protocol: TCP
    port: 10000

```

アクセスした場合のログ。TLS の中は見れません。よって delay を入れることもできません。

```
{
  "authority": "-",
  "bytes\_received": "688",
  "bytes\_sent": "1359",
  "downstream\_local\_address": "10.98.145.150:10000",
  "downstream\_remote\_address": "172.17.0.16:46948",
  "duration": "11",
  "istio\_policy\_status": "-",
  "method": "-",
  "path": "-",
  "protocol": "-",
  "request\_id": "-",
  "requested\_server\_name": "-",
  "response\_code": "0",
  "response\_flags": "-",
  "route\_name": "-",
  "start\_time": "2020-03-14T15:43:52.547Z",
  "upstream\_cluster": "outbound|10000||grpc-helloworld-service.default.svc.cluster.local",
  "upstream\_host": "172.17.0.7:10000",
  "upstream\_local\_address": "172.17.0.16:55454",
  "upstream\_service\_time": "-",
  "upstream\_transport\_failure\_reason": "-",
  "user\_agent": "-",
  "x\_forwarded\_for": "-"
}

```

まとめ
---

考えてみれば「そりゃそうだよな」なんだけど TLS が有効では Fault Injection できませんでした。mesh 内の通信は非TLSでも良さそうですが、gRPC (HTTP2) で非TLSっていうのがどの程度一般的なのかが良くわからない。Envoy で gRPC の TLS 終端と負荷分散っていうのをちょいちょい見かけるので結構使われているのかな？

Istio 使うなら mTLS もあるし、通信の暗号化という意味では問題なさそう。TLS 無しであればリクエスト単位でアクセスが分散されるのでこちらの方が良いですね。

Chaos Engineering 系ツールで delay 入れられたりするんだけどあれは API サーバーのレスポンスが遅い的な再現には使いづらいんですよね。

* * *

Istio 導入への道シリーズ

*   [Istio 導入への道 (1) – インストール編](/2020/03/istio-part1/)
*   [Istio 導入への道 (2) – サービス間通信編](/2020/03/istio-part2/)
*   [Istio 導入への道 (3) – VirtualService 編](/2020/03/istio-part3/)
*   [Istio 導入への道 (4) – Fault Injection 編](/2020/03/istio-part4/)
*   [Istio 導入への道 (5) – OutlierDetection と Retry 編](/2020/03/istio-part5/)
*   [Istio 導入への道 (6) – Ingress Gatway 編](/2020/03/istio-part6/)
*   [Istio 導入への道 (7) – 外部へのアクセス / ServiceEntry 編](/2020/03/istio-part7/)
*   [Istio 導入への道 (8) – 外部へのアクセスでも Fault Injection 編](/2020/03/istio-part8/)
*   Istio 導入への道 (9) – gRPC でも Fault Injection 編
*   [Istio 導入への道 (10) – 図解](/2020/03/istio-part10/)
*   [Istio 導入への道 (11) – Ingress Gateway で TLS Termination 編](/2020/03/istio-part11/)