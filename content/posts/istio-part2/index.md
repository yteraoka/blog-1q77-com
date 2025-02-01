---
title: 'Istio 導入への道 - サービス間通信編'
date: 2020-03-07T12:34:16+00:00
draft: false
tags: ['Istio']
author: "@yteraoka"
image: cover.png
categories:
  - IT
---

[前回](/2020/03/istio-part1/)の続きです。

Istio でのサービス間通信
---------------

まあ、ただサービス間で通信するだけなら Istio は不要なわけだけれども、まずはここから。

### httpbin をサービスとして deploy

[httpbin.org](http://httpbin.org/) のコンテナは Request Header をそのまま返してくれたりして便利なのでこれをサービスとして deploy します。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin-deployment
  labels:
    app: httpbin
spec:
  replicas: 2
  selector:
    matchLabels:
      app: httpbin
  template:
    metadata:
      labels:
        app: httpbin
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
apiVersion: v1
kind: Service
metadata:
  name: httpbin-service
spec:
  selector:
    app: httpbin
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
```

不要なんだけど、全部同じ名前にしちゃうとどれとどれが連動しているのかわかりにくくなるので `-service` とか `-deployment` とかを名前に入れています。これを `httpbin.yaml` として保存します。

これに Istio の sidecar を inject するのが `istioctl kube-inject` です。次のように実行すれば inject 済みの manifest が出力されます。

```bash
istioctl kube-inject -f httpbin.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: httpbin
  name: httpbin-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: httpbin
  strategy: {}
  template:
    metadata:
      annotations:
        sidecar.istio.io/interceptionMode: REDIRECT
        sidecar.istio.io/status: '{"version":"1cdb312e0b39910b7401fa37c42113f6436e281598036cb126f9692adebf1545","initContainers":["istio-init"],"containers":["istio-proxy"],"volumes":["istio-envoy","podinfo","istiod-ca-cert"],"imagePullSecrets":null}'
        traffic.sidecar.istio.io/excludeInboundPorts: "15020"
        traffic.sidecar.istio.io/includeInboundPorts: "80"
        traffic.sidecar.istio.io/includeOutboundIPRanges: '*'
      creationTimestamp: null
      labels:
        app: httpbin
        security.istio.io/tlsMode: istio
    spec:
      containers:
      - image: kennethreitz/httpbin:latest
        imagePullPolicy: IfNotPresent
        livenessProbe:
          httpGet:
            path: /status/200
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 5
        name: httpbin
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /status/200
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
        resources: {}
      - args:
        - proxy
        - sidecar
        - --domain
        - $(POD_NAMESPACE).svc.cluster.local
        - --configPath
        - /etc/istio/proxy
        - --binaryPath
        - /usr/local/bin/envoy
        - --serviceCluster
        - httpbin.$(POD_NAMESPACE)
        - --drainDuration
        - 45s
        - --parentShutdownDuration
        - 1m0s
        - --discoveryAddress
        - istiod.istio-system.svc:15012
        - --zipkinAddress
        - zipkin.istio-system:9411
        - --proxyLogLevel=warning
        - --proxyComponentLogLevel=misc:error
        - --connectTimeout
        - 10s
        - --proxyAdminPort
        - "15000"
        - --concurrency
        - "2"
        - --controlPlaneAuthPolicy
        - NONE
        - --dnsRefreshRate
        - 300s
        - --statusPort
        - "15020"
        - --trust-domain=cluster.local
        - --controlPlaneBootstrap=false
        env:
        - name: JWT_POLICY
          value: first-party-jwt
        - name: PILOT_CERT_PROVIDER
          value: istiod
        - name: CA_ADDR
          value: istio-pilot.istio-system.svc:15012
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: INSTANCE_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        - name: SERVICE_ACCOUNT
          valueFrom:
            fieldRef:
              fieldPath: spec.serviceAccountName
        - name: HOST_IP
          valueFrom:
            fieldRef:
              fieldPath: status.hostIP
        - name: ISTIO_META_POD_PORTS
          value: |-
            [
                {"containerPort":80}
            ]
        - name: ISTIO_META_CLUSTER_ID
          value: Kubernetes
        - name: ISTIO_META_POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: ISTIO_META_CONFIG_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: ISTIO_META_INTERCEPTION_MODE
          value: REDIRECT
        - name: ISTIO_META_WORKLOAD_NAME
          value: httpbin-deployment
        - name: ISTIO_META_OWNER
          value: kubernetes://apis/apps/v1/namespaces/default/deployments/httpbin-deployment
        - name: ISTIO_META_MESH_ID
          value: cluster.local
        image: docker.io/istio/proxyv2:1.5.0
        imagePullPolicy: IfNotPresent
        name: istio-proxy
        ports:
        - containerPort: 15090
          name: http-envoy-prom
          protocol: TCP
        readinessProbe:
          failureThreshold: 30
          httpGet:
            path: /healthz/ready
            port: 15020
          initialDelaySeconds: 1
          periodSeconds: 2
        resources:
          limits:
            cpu: "2"
            memory: 1Gi
          requests:
            cpu: 100m
            memory: 128Mi
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          privileged: false
          readOnlyRootFilesystem: true
          runAsGroup: 1337
          runAsNonRoot: true
          runAsUser: 1337
        volumeMounts:
        - mountPath: /var/run/secrets/istio
          name: istiod-ca-cert
        - mountPath: /etc/istio/proxy
          name: istio-envoy
        - mountPath: /etc/istio/pod
          name: podinfo
      initContainers:
      - command:
        - istio-iptables
        - -p
        - "15001"
        - -z
        - "15006"
        - -u
        - "1337"
        - -m
        - REDIRECT
        - -i
        - '*'
        - -x
        - ""
        - -b
        - '*'
        - -d
        - 15090,15020
        image: docker.io/istio/proxyv2:1.5.0
        imagePullPolicy: IfNotPresent
        name: istio-init
        resources:
          limits:
            cpu: 100m
            memory: 50Mi
          requests:
            cpu: 10m
            memory: 10Mi
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            add:
            - NET_ADMIN
            - NET_RAW
            drop:
            - ALL
          privileged: false
          readOnlyRootFilesystem: false
          runAsGroup: 0
          runAsNonRoot: false
          runAsUser: 0
      securityContext:
        fsGroup: 1337
      volumes:
      - emptyDir:
          medium: Memory
        name: istio-envoy
      - downwardAPI:
          items:
          - fieldRef:
              fieldPath: metadata.labels
            path: labels
          - fieldRef:
              fieldPath: metadata.annotations
            path: annotations
        name: podinfo
      - configMap:
          name: istio-ca-root-cert
        name: istiod-ca-cert
status: {}
---
apiVersion: v1
kind: Service
metadata:
  name: httpbin-service
spec:
  selector:
    app: httpbin
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
```

よって、これを pipe で kubectl apply に食わせることで deploy できます。`kubectl apply -f <(istioctl kube-inject -f ...)` でも良いし、もちろんファイルに一旦書き出しても大丈夫。

```bash
istioctl kube-inject -f httpbin.yaml | kubectl apply -f -
```

default namespace に deploy しました。

```
$ istioctl kube-inject -f httpbin.yaml | kubectl apply -f -
deployment.apps/httpbin-deployment created
service/httpbin-service created

$ kubectl get pods,deployments,services
NAME                                     READY   STATUS    RESTARTS   AGE
pod/httpbin-deployment-9bfd96975-px5lv   2/2     Running   0          88s
pod/httpbin-deployment-9bfd96975-v6mgg   2/2     Running   0          88s

NAME                                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.extensions/httpbin-deployment   2/2     2            2           88s

NAME                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/httpbin-service   ClusterIP   10.109.118.31   80/TCP    88s
service/kubernetes        ClusterIP   10.96.0.1       443/TCP   4h24m 
```

### 自動で inject されるようにする

毎回 Deployment を作る度に kube-inject をするのは面倒なので自動化することができる。自動 inject 対象としたい namespace に対して `istio-injection=enabled` という label をつけるだけで良い。

```bash
kubectl label namespace default istio-injection=enabled
```

```
$ kubectl get ns default -o yaml
apiVersion: v1
kind: Namespace
metadata:
  creationTimestamp: "2020-03-07T06:44:22Z"
  labels:
    istio-injection: enabled
  name: default
  resourceVersion: "12273"
  selfLink: /api/v1/namespaces/default
  uid: 1c02a69b-5ab5-433a-90be-6c6e3b785867
spec:
  finalizers:
  - kubernetes
status:
  phase: Active
```

先ほど deploy した httpbin に対してクラスタ内からアクセスするための ubuntu コンテナを Deployment として deploy します。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ubuntu-deployment
  labels:
    app: ubuntu
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ubuntu
  template:
    metadata:
      labels:
        app: ubuntu
    spec:
      containers:
      - name: ubuntu
        image: ubuntu:latest
        imagePullPolicy: IfNotPresent
        command:
        - sleep
        - infinity
```

この manifest を ubuntu.yaml として保存し、今度は `istioctl kube-inject` を使わずにそのまま `kubectl apply` します。それでも自動で inject されるはずです。

```
$ kubectl apply -f ubuntu.yaml
deployment.apps/ubuntu-deployment created
```

Deployment の spec には ubuntu コンテナしか書いてなかったのにコンテナの数が2になっています。

```
$ kubectl get pods -l app=ubuntu
NAME                                READY   STATUS    RESTARTS   AGE
ubuntu-deployment-cc86cc647-vsvbh   2/2     Running   0          21s
```

istio-proxy というコンテナが追加されています。長いので名前だけ表示。

```
$ kubectl get pods -l app=ubuntu -o json | jq '.items[].spec.containers[].name'
"ubuntu"
"istio-proxy"
```

### curl でアクセスしてみる

ubuntu Pod から httpbin Service にアクセスしてみます。

```
$ kubectl exec -it ubuntu-deployment-cc86cc647-vsvbh -c ubuntu -- bash
root@ubuntu-deployment-cc86cc647-vsvbh:/#
```

curl が入っていないのでインストールする。

```
root@ubuntu-deployment-cc86cc647-vsvbh# apt-get update && apt-get install -y curl
```

httpbin-service にアクセスしてみる。

```
root@ubuntu-deployment-cc86cc647-vsvbh:/# curl -sv http://httpbin-service/headers
*   Trying 10.109.118.31...
* TCP_NODELAY set
* Connected to httpbin-service (10.109.118.31) port 80 (#0)
> GET /headers HTTP/1.1
> Host: httpbin-service
> User-Agent: curl/7.58.0
> Accept: */*
> 
< HTTP/1.1 200 OK
< server: envoy
< date: Sat, 07 Mar 2020 11:33:28 GMT
< content-type: application/json
< content-length: 521
< access-control-allow-origin: *
< access-control-allow-credentials: true
< x-envoy-upstream-service-time: 26
< 
{
  "headers": {
    "Accept": "*/*", 
    "Content-Length": "0", 
    "Host": "httpbin-service", 
    "User-Agent": "curl/7.58.0", 
    "X-B3-Parentspanid": "361390f32cd55bdc", 
    "X-B3-Sampled": "0", 
    "X-B3-Spanid": "f95fbc3875ab93e5", 
    "X-B3-Traceid": "3a3e0cd03f1ded4e361390f32cd55bdc", 
    "X-Forwarded-Client-Cert": "By=spiffe://cluster.local/ns/default/sa/default;Hash=b87885c2542d1279071454ae1ce34cea21b7a265095bb23297ff44542009a304;Subject=\"\";URI=spiffe://cluster.local/ns/default/sa/default"
  }
}
* Connection #0 to host httpbin-service left intact
```

できました。Response Header に `server: envoy` や `x-envoy-upstream-service-time: 26` が入っています。また、`X-` プレフィックスのついた curl では送っていないヘッダーが httpbin 側に届いているようです。Envoy が間に入っているようです。`X-Forwarded-Client-Cent` も送られているのでクライアント証明書も送られたっぽいですね。これは Istio 1.5 からデフォルトになったのだろうか。1.4.6 の時は追加の設定が必要だったのだが。

```
$ kubectl get -n istio-system cm istio -o yaml | grep -v '{' | grep enableAutoMtls:              
    enableAutoMtls: true
```

`true` になってる。[前回の記事](/2020/03/istio-part1/)に戻って default プロファイルの値を確認してみよう。

```
$ istioctl manifest generate --set profile=default | grep enableAutoMtls
    enableAutoMtls: false
```

あれ？どこで変わったんだ？ 🤔 後で確認してみよう。

```yaml
    # If true, automatically configure client side mTLS settings to match the corresponding service's
    # server side mTLS authentication policy, when destination rule for that service does not specify
    # TLS settings.
    enableAutoMtls: true
```

っていう値。

### Envoy のログを確認してみる

前回の istio のインストール時に Envoy のログを有効にしておいたので istio-proxy の出力を確認してみます。

まずは送信元の ubuntu 側。 grep を pipe に繋げると buffering されて全然 jq まで渡ってこないので `--line-buffered` をつけています。

```bash
kubectl logs -l app=ubuntu -c istio-proxy -f --tail 0 | grep --line-buffered '^{' | jq . 
```

```json
{
  "authority": "httpbin-service",
  "bytes_received": "0",
  "bytes_sent": "521",
  "downstream_local_address": "10.109.118.31:80",
  "downstream_remote_address": "172.17.0.9:52178",
  "duration": "2",
  "istio_policy_status": "-",
  "method": "GET",
  "path": "/headers",
  "protocol": "HTTP/1.1",
  "request_id": "a93e2afa-cc27-4bb7-897c-5282c754d382",
  "requested_server_name": "-",
  "response_code": "200",
  "response_flags": "-",
  "route_name": "default",
  "start_time": "2020-03-07T12:00:58.425Z",
  "upstream_cluster": "outbound|80||httpbin-service.default.svc.cluster.local",
  "upstream_host": "172.17.0.8:80",
  "upstream_local_address": "172.17.0.9:43422",
  "upstream_service_time": "2",
  "upstream_transport_failure_reason": "-",
  "user_agent": "curl/7.58.0",
  "x_forwarded_for": "-"
}
```

172.17.0.9 は ubuntu Pod の IP アドレス。10.109.118.31 は httpbin-service Serivce の IP アドレス。172.17.0.8 は httpbin Pod の IP アドレス。

istio-proxy が 172.17.0.9:43422 --> 172.17.0.8:80 でリクエストを投げて、10.109.118.31:80 から 172.17.0.9:52178 に返したことにしてるってことなのか？？

次に httpbin 側のログ

```bash
kubectl logs -l app=httpbin -c istio-proxy -f --tail 0 \
  | grep --line-buffered '^{' \
  | grep --line-buffered -v kube-probe \
  | jq .
```

```json
{
  "authority": "httpbin-service",
  "bytes_received": "0",
  "bytes_sent": "521",
  "downstream_local_address": "172.17.0.8:80",
  "downstream_remote_address": "172.17.0.9:43422",
  "duration": "1",
  "istio_policy_status": "-",
  "method": "GET",
  "path": "/headers",
  "protocol": "HTTP/1.1",
  "request_id": "a93e2afa-cc27-4bb7-897c-5282c754d382",
  "requested_server_name": "outbound_.80_._.httpbin-service.default.svc.cluster.local",
  "response_code": "200",
  "response_flags": "-",
  "route_name": "default",
  "start_time": "2020-03-07T12:00:58.425Z",
  "upstream_cluster": "inbound|80|http|httpbin-service.default.svc.cluster.local",
  "upstream_host": "127.0.0.1:80",
  "upstream_local_address": "127.0.0.1:55232",
  "upstream_service_time": "1",
  "upstream_transport_failure_reason": "-",
  "user_agent": "curl/7.58.0",
  "x_forwarded_for": "-"
}
```

172.17.0.9:43422 (ubuntu:istio-proxy) --> 172.17.0.8:80 (httpbin:istio-proxy) 127.0.0.1:55232 --> 127.0.0.1:80 (httpbin:httpbin)

各 Pod と Serivce の IP アドレスは次の通り。

```
$ kubectl get pods -o wide
NAME                                 READY   STATUS    RESTARTS   AGE   IP           NODE   NOMINATED NODE   READINESS GATES
httpbin-deployment-9bfd96975-px5lv   2/2     Running   0          60m   172.17.0.8   m01    httpbin-deployment-9bfd96975-v6mgg   2/2     Running   0          60m   172.17.0.7   m01    ubuntu-deployment-cc86cc647-vsvbh    2/2     Running   0          45m   172.17.0.9   m01    $ kubectl get svc 
NAME              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
httpbin-service   ClusterIP   10.109.118.31   80/TCP    60m
kubernetes        ClusterIP   10.96.0.1       443/TCP   5h22m 
```

[続く](/2020/03/istio-part3/)

* * *

## Istio 導入への道シリーズ

* [Istio 導入への道 (1) – インストール編](/2020/03/istio-part1/)
* Istio 導入への道 (2) – サービス間通信編
* [Istio 導入への道 (3) – VirtualService 編](/2020/03/istio-part3/)
* [Istio 導入への道 (4) – Fault Injection 編](/2020/03/istio-part4/)
* [Istio 導入への道 (5) – OutlierDetection と Retry 編](/2020/03/istio-part5/)
* [Istio 導入への道 (6) – Ingress Gatway 編](/2020/03/istio-part6/)
* [Istio 導入への道 (7) – 外部へのアクセス / ServiceEntry 編](/2020/03/istio-part7/)
* [Istio 導入への道 (8) – 外部へのアクセスでも Fault Injection 編](/2020/03/istio-part8/)
* [Istio 導入への道 (9) – gRPC でも Fault Injection 編](/2020/03/istio-part9/)
* [Istio 導入への道 (10) – 図解](/2020/03/istio-part10/)
* [Istio 導入への道 (11) – Ingress Gateway で TLS Termination 編](/2020/03/istio-part11/)
