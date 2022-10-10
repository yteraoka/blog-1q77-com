---
title: 'Istio 導入への道 - 外部へのアクセス / ServiceEntry 編'
date: Tue, 10 Mar 2020 16:22:57 +0000
draft: false
tags: ['Istio']
---

[Istio シリーズ](/category/kubernetes/istio/)です。

今回はクラスタ内から外部のサービスへのアクセスについてです。[ServiceEntry](https://istio.io/docs/reference/config/networking/service-entry/) ってやつが登場です。（これを書く中でだいぶ自分の理解の誤りが訂正されました、良かった良かった）

クラスタ内から外部へのアクセスモードについて
----------------------

Istio のデフォルト設定では istio-system namespace の **istio** という ConfigMap で次のように [outboundTrafficPolicy](https://istio.io/docs/reference/config/istio.mesh.v1alpha1/#MeshConfig-OutboundTrafficPolicy-Mode) の **mode** が `ALLOW_ANY` となっており、中から外は自由に通信できます。

```
$ kubectl get cm -n istio-system istio -o yaml | grep "^    outboundTrafficPolicy:" -A 1
    outboundTrafficPolicy:
      mode: ALLOW\_ANY

```

これを `REGISTRY_ONLY` に変更すると登録された宛先にしかアクセスできなくなります。

次の様にして変更することができます。[インストール時](/2020/03/istio-part1/)に指定しておくには `--set values.global.outboundTrafficPolicy.mode=REGISTRY_ONLY` とします。

```
$ kubectl get configmap istio -n istio-system -o yaml \\
    | sed 's/mode: ALLOW\_ANY/mode: REGISTRY\_ONLY/g' \\
    | kubectl replace -n istio-system -f -

```

変更されました。

```
$ kubectl get cm -n istio-system istio -o yaml | grep "^    outboundTrafficPolicy:" -A 1
    outboundTrafficPolicy:
      mode: **REGISTRY\_ONLY**

```

戻す場合はこれで。

```
$ kubectl get configmap istio -n istio-system -o yaml \\
    | sed 's/mode: REGISTRY\_ONLY/mode: ALLOW\_ANY/g' \\
    | kubectl replace -n istio-system -f -

```

HTTP の外部サービスを登録する
-----------------

REGISTRY\_ONLY になったら未登録の外部サービス（アドレス）にはアクセス出来ません。

502 Bad Gateway となりました。

```
root@ubuntu-deployment-54bbd6f4ff-q9sdj:/# curl -sv http://httpbin.org/ip
\*   Trying 52.202.2.199...
\* TCP\_NODELAY set
\* Connected to httpbin.org (52.202.2.199) port 80 (#0)
> GET /ip HTTP/1.1
> Host: httpbin.org
> User-Agent: curl/7.58.0
> Accept: \*/\*
> 
< **HTTP/1.1 502 Bad Gateway**
< date: Mon, 09 Mar 2020 16:11:01 GMT
< server: envoy
< content-length: 0
< 
\* Connection #0 to host httpbin.org left intact

```

アプリを Kubernetes でコンテナとして動かしていても、データベースなどはクラウドのマネージドサービスを使うことが多いと思います。クラスタ外にアクセス出来ないということはそういったサービスへもアクセス出来ないことを意味します。それでは困るので [ServiceEntry](https://istio.io/docs/reference/config/networking/service-entry/) というもので宛先を登録します。

登録は簡単です。次の様にします。hosts に許可したい宛先 FQDN を指定します。

```
$ kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: external-svc
spec:
  hosts:
  - httpbin.org
  location: MESH\_EXTERNAL
  ports:
  - number: 80
    name: http
    protocol: HTTP
  resolution: DNS
EOF

```

アクセスできるようになりました。

```
root@ubuntu-deployment-54bbd6f4ff-q9sdj:/# curl -sv http://httpbin.org/headers
\*   Trying 3.232.168.170...
\* TCP\_NODELAY set
\* Connected to httpbin.org (3.232.168.170) port 80 (#0)
> GET /headers HTTP/1.1
> Host: httpbin.org
> User-Agent: curl/7.58.0
> Accept: \*/\*
> 
< **HTTP/1.1 200 OK**
< date: Mon, 09 Mar 2020 16:18:21 GMT
< content-type: application/json
< content-length: 1186
< server: envoy
< access-control-allow-origin: \*
< access-control-allow-credentials: true
< x-envoy-upstream-service-time: 347
< 
{
  "headers": {
    "Accept": "\*/\*", 
    "Content-Length": "0", 
    "Host": "httpbin.org", 
    "User-Agent": "curl/7.58.0", 
    "X-Amzn-Trace-Id": "Root=1-5e666c4d-f5fff240a5be87147f2cc6a4", 
    "X-B3-Sampled": "0", 
    "X-B3-Spanid": "db1df3e34fb690a9", 
    "X-B3-Traceid": "e12ef759daff1ddcdb1df3e34fb690a9", 
    "X-Envoy-Decorator-Operation": "httpbin.org:80/\*", 
    "X-Envoy-Peer-Metadata": "ChwKDElOU1RBTkNFX0lQUxIMGgoxNzIuMTcuMC44CsYBCgZMQUJFTFMSuwEquAEKDwoDYXBwEggaBnVidW50dQohChFwb2QtdGVtcGxhdGUtaGFzaBIMGgo1NGJiZDZmNGZmCiQKGXNlY3VyaXR5LmlzdGlvLmlvL3Rsc01vZGUSBxoFaXN0aW8KKwofc2VydmljZS5pc3Rpby5pby9jYW5vbmljYWwtbmFtZRIIGgZ1YnVudHUKLwojc2VydmljZS5pc3Rpby5pby9jYW5vbmljYWwtcmV2aXNpb24SCBoGbGF0ZXN0ChoKB01FU0hfSUQSDxoNY2x1c3Rlci5sb2NhbAosCgROQU1FEiQaInVidW50dS1kZXBsb3ltZW50LTU0YmJkNmY0ZmYtcTlzZGoKFgoJTkFNRVNQQUNFEgkaB2RlZmF1bHQKVQoFT1dORVISTBpKa3ViZXJuZXRlczovL2FwaXMvYXBwcy92MS9uYW1lc3BhY2VzL2RlZmF1bHQvZGVwbG95bWVudHMvdWJ1bnR1LWRlcGxveW1lbnQKHAoPU0VSVklDRV9BQ0NPVU5UEgkaB2RlZmF1bHQKJAoNV09SS0xPQURfTkFNRRITGhF1YnVudHUtZGVwbG95bWVudA==", 
    "X-Envoy-Peer-Metadata-Id": "sidecar~172.17.0.8~ubuntu-deployment-54bbd6f4ff-q9sdj.default~default.svc.cluster.local"
  }
}
\* Connection #0 to host httpbin.org left intact

```

しかし、なんだか余計なデータを header に詰めて送ってますね。**X-Envoy-Peer-Metadata** には送信元 Pod の metadata が Base64 encode されて入っています。何に使うのだろう？

istioctl コマンドで ENDPOINT に登録されていることがわかります。

```
$ istioctl proxy-config endpoint ubuntu-deployment-54bbd6f4ff-q9sdj | egrep 'ENDPOINT|httpbin.org'
ENDPOINT                        STATUS      OUTLIER CHECK     CLUSTER
3.232.168.170:80                HEALTHY     OK                outbound|80||httpbin.org
52.202.2.199:80                 HEALTHY     OK                outbound|80||httpbin.org

```

**resolution: DNS** と指定しているため、この宛先のIPアドレスは DNS から取得した値となっており、エラーが増えたり、接続できなかったら状態が変わるのでしょう。Envoy は自分で名前解決して接続するようです。curl の --resolve で全然関係の無い IP アドレスを指定していても Envoy は Host ヘッダーのサーバーへ自分で名前解決を行って接続するようです。

HTTP や HTTPS の場合は Host ヘッダーや SNI に接続先ホスト情報がありますが、他の protocol ではそうはいきませんから、接続先 IP アドレスが ServiceEntry の addresses にマッチしているかどうかがチェックされます。 **resolution: STATIC** の場合は endpoints に指定した IP アドレスに接続を試みます。

**resolution: NONE** とした場合は元の接続先 IP アドレスがそのまま使われます。つまり、curl で --resolve で指定した場合、Envoy もそこに接続します。

HTTPS の外部サービスを登録する
------------------

次に HTTPS でも接続できるようにします。www.google.com でテストしてみます。port 443 を追加するだけですね。**resolution** が **DNS** や **NONE** であれば先の HTTP のやつとまとめてしまうことが可能です。

```
$ kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: external-svc
spec:
  hosts:
  - httpbin.org
  - **www.google.com**
  location: MESH\_EXTERNAL
  ports:
  - number: 80
    name: http
    protocol: HTTP
  **\- number: 443**
    **name: tls**
    **protocol: TLS**
  resolution: DNS
EOF

```

`name: tls`, `protocol: TLS` は `name: https`, `protol: HTTPS` でも機能します。が、明確な違いがわかりません。GitHub に issue ([ServiceEntry protocol HTTPS vs TLS documentation + Virtual Services requirements #19188](https://github.com/istio/istio/issues/19188)) を見つけました。全く同感ですね。 **name** の方は[ルール](https://istio.io/docs/ops/configuration/traffic-management/protocol-selection/)があるっぽいけど https と tls の違いはわからない。http2 もあるのか...

`resolution: DNS` よりも `resolution: NONE` の方が良さそうですね。

[次回](/2020/03/istio-part8/)は「[外部サービスでも Fault Injection したいぞ](/2020/03/istio-part8/)」です。

* * *

Istio 導入への道シリーズ

*   [Istio 導入への道 (1) – インストール編](/2020/03/istio-part1/)
*   [Istio 導入への道 (2) – サービス間通信編](/2020/03/istio-part2/)
*   [Istio 導入への道 (3) – VirtualService 編](/2020/03/istio-part3/)
*   [Istio 導入への道 (4) – Fault Injection 編](/2020/03/istio-part4/)
*   [Istio 導入への道 (5) – OutlierDetection と Retry 編](/2020/03/istio-part5/)
*   [Istio 導入への道 (6) – Ingress Gatway 編](/2020/03/istio-part6/)
*   Istio 導入への道 (7) – 外部へのアクセス / ServiceEntry 編
*   [Istio 導入への道 (8) – 外部へのアクセスでも Fault Injection 編](/2020/03/istio-part8/)
*   [Istio 導入への道 (9) – gRPC でも Fault Injection 編](/2020/03/istio-part9/)
*   [Istio 導入への道 (10) – 図解](/2020/03/istio-part10/)
*   [Istio 導入への道 (11) – Ingress Gateway で TLS Termination 編](/2020/03/istio-part11/)
