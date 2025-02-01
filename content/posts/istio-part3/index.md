---
title: 'Istio 導入への道 - VirtualService 編'
date: 2020-03-07T16:24:12+00:00
draft: false
tags: ['Istio']
author: "@yteraoka"
image: cover.png
categories:
  - IT
---

[Istio シリーズ](/tags/istio/)です。

今回は [VirtualService](https://istio.io/docs/reference/config/networking/virtual-service/) です。これを利用することで、コネクションプーリングの設定をしたり、レートリミットを入れたり、振り分け方法を指定したり、同じホスト名でアクセスしても条件によって振り分けを行えたり、指定の HTTP レスポンス (400 とか 500 Internal Server Error とか) を返したり、delay を入れたりすることができるようになります。また、後でやる Ingress Gateway からアクセスできるようになったりします。

複数 Version の Deployment を用意する
-----------------------------

Version 違いを出し分けたりするテストを行うため、一旦今の httpbin-deployment を削除します。

```bash
kubectl delete deployment httpbin-deployment
```

本当はレスポンスが異なる Pod を用意すればわかりやすいのですが、ログでアクセスを確認するってことで、v1 と v2 と version label だけが異なる Deployment を2つ deploy します。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin-deployment-v1
  labels:
    app: httpbin
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
      version: v1
  template:
    metadata:
      labels:
        app: httpbin
        version: v1
    spec:
      containers:
      - name: httpbin
        image: kennethreitz/httpbin:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /status/200
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /status/200
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 5
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin-deployment-v2
  labels:
    app: httpbin
    version: v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
      version: v2
  template:
    metadata:
      labels:
        app: httpbin
        version: v2
    spec:
      containers:
      - name: httpbin
        image: kennethreitz/httpbin:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /status/200
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /status/200
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 5
```

httpbin-service として作成ずみの Service は selector が `app: httpbin` だけであるため、v1 も v2 も両方とも対象となり、この状態でも v1, v2 両方にリクエストが振り分けられる状況ですが、振り分け方法を細かく制限したり Fault injection を行えるようにするため VirtualService を定義します。

v1 も v2 も一つの Service に含まれている様子。Endpoints に両方入っています。

```
$ kubectl get pods -o wide -l app=httpbin
NAME                                     READY   STATUS    RESTARTS   AGE   IP           NODE   NOMINATED NODE   READINESS GATES
httpbin-deployment-v1-7d95bdc6f6-5f69g   2/2     Running   0          13m   172.17.0.7   m01    <none>           <none>
httpbin-deployment-v2-ccd49cc9c-lgvjs    2/2     Running   0          12m   172.17.0.8   m01    <none>           <none>

$ kubectl describe svc httpbin-service
Name:              httpbin-service
Namespace:         default
Labels:            <none>
Annotations:       kubectl.kubernetes.io/last-applied-configuration:
                     {"apiVersion":"v1","kind":"Service","metadata":{"annotations":{},"name":"httpbin-service","namespace":"default"},"spec":{"ports":\[{"name":...
Selector:          app=httpbin
Type:              ClusterIP
IP:                10.109.118.31
Port:              http  80/TCP
TargetPort:        80/TCP
Endpoints:         172.17.0.7:80,172.17.0.8:80
Session Affinity:  None
Events:            <none>
```

DestinationRule の作成
-------------------

v1, v2 それぞれにアクセスするための [DestinationRule](https://istio.io/docs/reference/config/networking/destination-rule/) を作成します。

```yaml
#
# httpbin-service という Service 宛 traffic で
# VirtualService により、subset: v1 と指定された場合は
# version label が v1 の Endpoint へ転送し、
# subnet: v2 の場合は label が v2 の Endpoint へ転送する
#
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: httpbin-destination-rule
spec:
  host: httpbin-service
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
```

VirtualService
--------------

上で作った DestinationRule を使って VirtualServive を設定します。

### 重みづけで振り分ける

一番単純な例

```yaml
#
# httpbin-service 宛ての http リクエストを httpbin-service の v1 か v2 に半々の割合で転送する
#
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
      weight: 50
    - destination:
        host: httpbin-service
        subset: v2
      weight: 50
```

wegith を 100:0 に変更して試すと全部片方にしかリクエストが送られないことが確認できる。

### HTTP Header を使って振り分ける

[HTTPMatchRequest](https://istio.io/docs/reference/config/networking/virtual-service/#HTTPMatchRequest) を使うことで HTTP の Request の内容によって振り分けを行うことができる。

```yaml
#
# queryString に v=1 があれば v1 へ、v=2 があれば v2 へ転送する
#
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
    route:
    - destination:
        host: httpbin-service
        subset: v1
  - match:
    - name: v2
      queryParams:
        v:
          exact: "2"
    route:
    - destination:
        host: httpbin-service
        subset: v2
```

この例の様に \`match\` に \`name\` を設定しておけば、送信側の istio-proxy のログの \`route\_name\` に subset 名が入っている。

```json
{
  "authority": "httpbin-service",
  "bytes_received": "0",
  "bytes_sent": "521",
  "downstream_local_address": "10.109.118.31:80",
  "downstream_remote_address": "172.17.0.9:50168",
  "duration": "3",
  "istio_policy_status": "-",
  "method": "GET",
  "path": "/headers?v=1",
  "protocol": "HTTP/1.1",
  "request_id": "c463717a-a722-47c6-8ec1-ea8f90b9ea58",
  "requested_server_name": "-",
  "response_code": "200",
  "response_flags": "-",
  "route_name": ".v1",
  "start_time": "2020-03-07T16:06:58.480Z",
  "upstream_cluster": "outbound|80|v1|httpbin-service.default.svc.cluster.local",
  "upstream_host": "172.17.0.7:80",
  "upstream_local_address": "172.17.0.9:60574",
  "upstream_service_time": "2",
  "upstream_transport_failure_reason": "-",
  "user_agent": "curl/7.58.0",
  "x_forwarded_for": "-"
}
{
  "authority": "httpbin-service",
  "bytes_received": "0",
  "bytes_sent": "521",
  "downstream_local_address": "10.109.118.31:80",
  "downstream_remote_address": "172.17.0.9:50224",
  "duration": "3",
  "istio_policy_status": "-",
  "method": "GET",
  "path": "/headers?v=2",
  "protocol": "HTTP/1.1",
  "request_id": "b5091908-4806-465a-b755-59141e3acd25",
  "requested_server_name": "-",
  "response_code": "200",
  "response_flags": "-",
  "route_name": ".v2",
  "start_time": "2020-03-07T16:07:02.565Z",
  "upstream_cluster": "outbound|80|v2|httpbin-service.default.svc.cluster.local",
  "upstream_host": "172.17.0.8:80",
  "upstream_local_address": "172.17.0.9:54576",
  "upstream_service_time": "3",
  "upstream_transport_failure_reason": "-",
  "user_agent": "curl/7.58.0",
  "x_forwarded_for": "-"
}
{
  "authority": "httpbin-service",
  "bytes_received": "0",
  "bytes_sent": "0",
  "downstream_local_address": "10.109.118.31:80",
  "downstream_remote_address": "172.17.0.9:50604",
  "duration": "0",
  "istio_policy_status": "-",
  "method": "GET",
  "path": "/headers?v=3",
  "protocol": "HTTP/1.1",
  "request_id": "24312033-fbf6-48d9-936a-bb23e3381d7f",
  "requested_server_name": "-",
  "response_code": "404",
  "response_flags": "NR",
  "route_name": "-",
  "start_time": "2020-03-07T16:07:28.632Z",
  "upstream_cluster": "-",
  "upstream_host": "-",
  "upstream_local_address": "-",
  "upstream_service_time": "-",
  "upstream_transport_failure_reason": "-",
  "user_agent": "curl/7.58.0",
  "x_forwarded_for": "-"
}
```

3つ目のログは v=3 で、その定義はしていなかったため 404 が返されている。次の様に \`match\` をつけないで \`route\` を最後に書いておけばマッチしなかったものが全てそこに送られる。

```yaml
#
# queryString に v=1 があれば v1 へ、そうでなければ v2 へ転送する
#
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
    route:
    - destination:
        host: httpbin-service
        subset: v1
  - route:
    - destination:
        host: httpbin-service
        subset: v2
```

注意点として、VirtualService の振り分けは最初にマッチしたところで宛先が決まってしまう点。条件の厳しいものから順に書いておく必要がある。

[次回](/2020/03/istio-part4/)は Fault Injection にしよう。

* * *

## Istio 導入への道シリーズ

* [Istio 導入への道 (1) – インストール編](/2020/03/istio-part1/)
* [Istio 導入への道 (2) – サービス間通信編](/2020/03/istio-part2/)
* Istio 導入への道 (3) – VirtualService 編
* [Istio 導入への道 (4) – Fault Injection 編](/2020/03/istio-part4/)
* [Istio 導入への道 (5) – OutlierDetection と Retry 編](/2020/03/istio-part5/)
* [Istio 導入への道 (6) – Ingress Gatway 編](/2020/03/istio-part6/)
* [Istio 導入への道 (7) – 外部へのアクセス / ServiceEntry 編](/2020/03/istio-part7/)
* [Istio 導入への道 (8) – 外部へのアクセスでも Fault Injection 編](/2020/03/istio-part8/)
* [Istio 導入への道 (9) – gRPC でも Fault Injection 編](/2020/03/istio-part9/)
* [Istio 導入への道 (10) – 図解](/2020/03/istio-part10/)
* [Istio 導入への道 (11) – Ingress Gateway で TLS Termination 編](/2020/03/istio-part11/)
