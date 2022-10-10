---
title: 'ArgoCD と Istio Ingress Gateway'
date: Sat, 21 Mar 2020 16:55:00 +0000
draft: false
tags: ['ArgoCD', 'Istio']
---

[ArgoCD](https://argoproj.github.io/argo-cd/) という Kubernetes 用の CD ツールがあります。

> Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes.

これを Istio Ingress Gateway と共に使う方法をまとめます。それだけでそこそこの量になったので。

ArgoCD の deploy
---------------

argocd という namespace を作って、そこに Manifest を apply するだけです。

```
$ kubectl create namespace argocd
```

```
$ kubectl apply -n argocd -f [https://raw.githubusercontent.com/argoproj/argo-cd/v1.4.2/manifests/install.yaml](https://raw.githubusercontent.com/argoproj/argo-cd/v1.4.2/manifests/install.yaml)
```

これだけで起動します。次のように port-forward すれば https://localhost:8443/ でアクセスできます。

```
$ kubectl -n argocd port-forward svc/argocd-server 8443:443
```

HA 構成の場合は [manifests/ha/install.yaml](https://raw.githubusercontent.com/argoproj/argo-cd/v1.4.2/manifests/ha/install.yaml) を使うようです。

```
$ diff -u \
    <(curl -s https://raw.githubusercontent.com/argoproj/argo-cd/v1.4.2/manifests/install.yaml) \
    <(curl -s https://raw.githubusercontent.com/argoproj/argo-cd/v1.4.2/manifests/ha/install.yaml)
```

HA の方は Redis sentinel で Redis が冗長構成になるようです。

ArgoCD 用 Istio Ingress の設定
--------------------------

ArgoCD は cli 用の gRPC とブラウザ向けの HTTP を同じサーバー、同じポートで処理しており、そこが Ingress 設定におけるポイントです。

### TLS Passthrough

argocd-server はデフォルトで TLS 対応しているため、これをそのまま活かす方法です。

Gateway で port 443 を `tls.mode: PASSTHROUGH` とします。

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: argocd-gw
  namespace: argocd
spec:
  selector:
    istio: ingressgateway
  servers:
  - hosts:
    - argocd.example.com
    port:
      name: http
      number: 80
      protocol: HTTP
  - hosts:
    - argocd.example.com
    port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: PASSTHROUGH
```

VirtualService は argocd-gw (Gateway) と紐付け、argocd.example.com 宛て (https では SNI が必須) を argocd-server (Service) に転送します。

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: argocd-vsvc
  namespace: argocd
spec:
  gateways:
  - argocd-gw
  hosts:
  - argocd.example.com
  http:
  - name: argocd-http
    route:
    - destination:
        host: argocd-server
  tls:
  - name: argocd-https
    match:
    - port: 443
      sniHosts:
        - argocd.example.com
    route:
    - destination:
        host: argocd-server
```

argocd の `argocd-secret` Secret に入っている証明書 (tls.crt と tls.key) を更新する必要があります。

argocd cli からもアクセス可能です。

```
$ argocd --server argocd.example.com:443 app list
```

### TLS Termination (方法1)

Ingress で TLS を Termination した場合の設定方法です。argocd-server (Pod) へのアクセスは TLS を使わないため、argocd-server Deployment の設定を変更して argocd-server の起動オプションに `--insecure` を追加する必要があります。

```
$ kubectl -n argocd edit deployment argocd-server
```

**command** に `--insecure` を追加します。これを追加しないと argocd-server が https でのアクセスを求めて redirect loop となります。

```
$ kubectl -n argocd patch deployment argocd-server -p '
{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "argocd-server",
            "command": ["argocd-server","--staticassets","/shared/app","--insecure"]
          }
        ]
      }
    }
  }
}'
```

```yaml
  template:
    spec:
      containers:
      - command:
        - argocd-server
        - --staticassets
        - /shared/app
        - --insecure
```

Gateway で argocd.example.com を port 80 と port 443 で受け入れます。443 は tls.mode を SIMPLE とします。TLS の証明書と秘密鍵が必要となりますが、 istio-system namespace に argocd-certificate という名前の Secret が事前に作成されている前提です（ここの詳しい話は[以前の投稿](/2020/03/istio-part11/)を参照）。argocd-server が `--insecure` の影響で https への redirect を行わなくなっているため、Gateway で port 80 のところに `tls.httpsRedirect: true` を入れてあります。これで 301 Redirect を返してくれます。

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: argocd-gw
  namespace: argocd
spec:
  selector:
    istio: ingressgateway
  servers:
  - hosts:
    - argocd.example.com
    port:
      name: http
      number: 80
      protocol: HTTP
    tls:
      httpsRedirect: true
  - hosts:
    - argocd.example.com
    port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: argocd-certificate
```

VirtualService で argocd.example.com 宛てを argocd-server (Service) に送ります。

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: argocd-vsvc
  namespace: argocd
spec:
  gateways:
  - argocd-gw
  hosts:
  - argocd.example.com
  http:
  - name: http
    route:
    - destination:
        host: argocd-server
```

この方法では Ingress の Envoy と ArgoCD Pod の間を gRPC として処理しないため、argocd cli からアクセスする場合に `--grpc-web` オプションの指定が必要になります。

```
$ argocd --server argocd.example.com:443 --grpc-web app list
```

`--grpc-web` オプションをつけないと次のようなエラーとなります。

```
FATA[0000] rpc error: code = Internal desc = transport: received the unexpected content-type "text/plain; charset=utf-8"
```

### TLS Termination (方法2)

先の方法（方法1）では gRPC が使えなくなってしまいましたが、User-Agent で判断して argocd コマンドからの場合は gRPC でアクセスできるようにします。

方法1と同じく argocd-server に `--insecure` の追加が必要です。

```
$ kubectl -n argocd patch deployment argocd-server -p '
{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "argocd-server",
            "command": ["argocd-server","--staticassets","/shared/app","--insecure"]
          }
        ]
      }
    }
  }
}'
```

さらに、argocd の manifest で作成されている argocd-server Service も編集します。port 443 の **name** を **grpc** に変更します。名前が重要。

```
$ kubectl -n argocd edit svc argocd-server
```

```yaml
spec:
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: 8080
  - **name: grpc**
    port: 443
    protocol: TCP
    targetPort: 8080
```

その上で、Gateway と VirtualServer を作成する

Gateway は方法1と同じ

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: argocd-gw
  namespace: argocd
spec:
  selector:
    istio: ingressgateway
  servers:
  - hosts:
    - argocd.example.com
    port:
      name: http
      number: 80
      protocol: HTTP
    tls:
      httpsRedirect: true
  - hosts:
    - argocd.example.com
    port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: argocd-certificate
```

VirtualService では User-Agent が argocd-client で始まる場合は grpc に名前を変更した port 443 に、それ意外は port 80 へ。

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: argocd-vsvc
  namespace: argocd
spec:
  gateways:
  - argocd-gw
  hosts:
  - argocd.example.com
  http:
  - name: grpc
    match:
    - headers:
        user-agent:
          prefix: argocd-client
    route:
    - destination:
        host: argocd-server
        port:
          number: 443
  - name: http
    route:
    - destination:
        host: argocd-server
        port:
          number: 80
```

これでブラウザでも argocd cli からでも `--grpc-web` オプションなしでアクセス可能です。
