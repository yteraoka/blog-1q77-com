---
title: 'Istio 導入への道 - インストール編'
date: Sat, 07 Mar 2020 08:24:45 +0000
draft: false
tags: ['Istio', 'Istio']
---

Istio 導入に向けて一歩一歩やっていき。リリースされたばかりの 1.5 を使ってみようと思います。

Minikube の起動
------------

まずは Kubernetes クラスタの作成。いつものように minikube です。[こちらのページ](https://istio.io/docs/setup/platform-setup/)によると Istio 1.5 は Kubernetes 1.14, 1.15, 1.16 でテストされているそうです。1.17 はまだ早いみたいです。特に理由はないですがここではひとまず 1.15 を使うことにしました。

```
$ minikube start --kubernetes-version=v1.15.10 --cpus=4 --memory=8gb
```

後で `type: LoadBalancer` の **Service** が作られるので別ターミナルで [minikube tunnel](https://minikube.sigs.k8s.io/docs/tasks/loadbalancer/#using-minikube-tunnel) を実行しておきます。

```
$ minikube tunnel
```

Istio のインストール
-------------

### istioctl のダウンロード

まずはダウンロードです。最新版をダウンロードする場合は ISTIO\_VERSION の指定は不要かと思いますが一応。

```
$ curl -L https://istio.io/downloadIstio | ISTIO\_VERSION=1.5.0 sh -
```

これでカレントディレクトリに istio-1.5.0 というディレクトリができているはずです。(github の releases から環境に合わせた tar.gz をダウンロードして展開してくれるだけ)

istio-1.5.0/bin にある istioctl コマンドを使います。PATH に入れるか PATH の通ってるところに置いてしまいましょう。

### profile の確認

istioctl は複数の preset profile を持っています。

```
$ istioctl profile list               
Istio configuration profiles:
    default
    demo
    empty
    minimal
    remote
    separate
```

それぞれがどんな構成を作るのかは `istioctl profile dump PROFILE-NAME` で確認できます。`istioctl profile diff PROFILE-NAME1 PROFILE-NAME2` で profile 間の差分も表示してくれます。kubectl で適用する manifest は `istioctl manifest generate` で生成できるため、この出力を比較することもできます。

した manifest を diff で確認した方がわかりやすいです。

```
$ diff -u <(istioctl manifest generate --set profile=default) \
          <(istioctl manifest generate --set profile=minimal)
```

profile dump で確認できる変数を `--set` で上書きすることで細かいカスタマイズも可能でその影響も manifest generage で確認することができます。([オプション設定一覧](https://istio.io/docs/reference/config/installation-options/))

Envoy proxy でアクセスログを出力するには `values.global.proxy.accessLogFile=/dev/stdout` とします。また、そのフォーマット（エンコーディング？）を JSON にするには `values.global.proxy.accessLogEncoding=JSON` とします。この manifest の差分が次のようにして確認できます。

```
$ diff -u <(istioctl manifest generate \
                        --set profile=default \
                        --set values.global.proxy.accessLogEncoding=JSON \
                        --set values.global.proxy.accessLogFile=/dev/stdout) \
          <(istioctl manifest generate --set profile=default)
```

```diff
--- /dev/fd/11	2020-03-07 16:29:46.000000000 +0900
+++ /dev/fd/12	2020-03-07 16:29:46.000000000 +0900
@@ -7199,11 +7199,11 @@
     enableTracing: true
 
     # Set accessLogFile to empty string to disable access log.
-    accessLogFile: "/dev/stdout"
+    accessLogFile: ""
 
     accessLogFormat: ""
 
-    accessLogEncoding: 'JSON'
+    accessLogEncoding: 'TEXT'
 
     enableEnvoyAccessLogService: false
     # reportBatchMaxEntries is the number of requests that are batched before telemetry data is sent to the mixer server
@@ -7569,8 +7569,8 @@
         "priorityClassName": "",
         "prometheusNamespace": "istio-system",
         "proxy": {
-          "accessLogEncoding": "JSON",
-          "accessLogFile": "/dev/stdout",
+          "accessLogEncoding": "TEXT",
+          "accessLogFile": "",
           "accessLogFormat": "",
           "autoInject": "enabled",
           "clusterDomain": "cluster.local",
```

Egress Gateway を有効にしたい場合は `gateways.components.egressGateway.enabled=true` を指定します。

### インストール

```
$ istioctl manifest apply \
      --set profile=default \
      --set values.global.proxy.accessLogEncoding=JSON \
      --set values.global.proxy.accessLogFile=/dev/stdout
```

```
Detected that your cluster does not support third party JWT authentication. Falling back to less secure first party JWT. See https://istio.io/docs/ops/best-practices/security/#configure-third-party-service-account-tokens for details.
- Applying manifest for component Base...
✔ Finished applying manifest for component Base.
- Applying manifest for component Pilot...
✔ Finished applying manifest for component Pilot.
  Waiting for resources to become ready...
  Waiting for resources to become ready...
  Waiting for resources to become ready...
  Waiting for resources to become ready...
  Waiting for resources to become ready...
  Waiting for resources to become ready...
  Waiting for resources to become ready...
  Waiting for resources to become ready...
  Waiting for resources to become ready...
  Waiting for resources to become ready...
  Waiting for resources to become ready...
- Applying manifest for component IngressGateways...
- Applying manifest for component AddonComponents...
✔ Finished applying manifest for component IngressGateways.
✔ Finished applying manifest for component AddonComponents.


✔ Installation complete
```

後で変更したり削除する時のために generate で manifest を作成して kubectl apply した方が良いのかな。

**追記**:  

[Configure third party service account tokens](https://istio.io/docs/ops/best-practices/security/#configure-third-party-service-account-tokens) について。  
istio-proxy が認証に使える token には First Party Token と Third Party Token の2つがあり、First Party は無期限で使えて、全ての Pod にマウントされているため、有効期限の管理される Third Party Token が使えればその方が好ましい。クラウドプロバイダーの提供する Kubernetes の多くでは Third Party Token をサポートしているが、ローカルの開発用クラスタではそうではないことが多いらしい。`istioctl manifest apply` はこれを自動で調べて使える方を使ってくれるが、`istioctl manifest generate` で別途 apply する場合は `--set values.global.jwtPolicy=third-party-jwt` か `--set values.global.jwtPolicy=first-party-jwt` を明示する必要があります。

[続く](/2020/03/istio-part2/)

* * *

Istio 導入への道シリーズ

* Istio 導入への道 (1) – インストール編
* [Istio 導入への道 (2) – サービス間通信編](/2020/03/istio-part2/)
* [Istio 導入への道 (3) – VirtualService 編](/2020/03/istio-part3/)
* [Istio 導入への道 (4) – Fault Injection 編](/2020/03/istio-part4/)
* [Istio 導入への道 (5) – OutlierDetection と Retry 編](/2020/03/istio-part5/)
* [Istio 導入への道 (6) – Ingress Gatway 編](/2020/03/istio-part6/)
* [Istio 導入への道 (7) – 外部へのアクセス / ServiceEntry 編](/2020/03/istio-part7/)
* [Istio 導入への道 (8) – 外部へのアクセスでも Fault Injection 編](/2020/03/istio-part8/)
* [Istio 導入への道 (9) – gRPC でも Fault Injection 編](/2020/03/istio-part9/)
* [Istio 導入への道 (10) – 図解](/2020/03/istio-part10/)
* [Istio 導入への道 (11) – Ingress Gateway で TLS Termination 編](/2020/03/istio-part11/)
