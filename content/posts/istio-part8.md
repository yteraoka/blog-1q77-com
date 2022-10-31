---
title: 'Istio 導入への道 - 外部へのアクセスでも Fault Injection 編'
date: Wed, 11 Mar 2020 16:37:14 +0000
draft: false
tags: ['Istio']
---

[Istio シリーズ](/tags/istio/)です。

[前回](/2020/03/istio-part7/)の予告通り今回は「**外部サービスでも Fault Injection したいぞ**」編です。

「[Fault Injection 編](/2020/03/istio-part4/)」でその便利さを取り上げましたが、外部の API を使用している時にもそこに Inject したいですよね？依存している外部サービスでエラーが発生したらどうなるのかとか、レスポンスが遅かった場合どうなるかとか、それを Istio の設定で調整することが可能になります。

前回設定した ServiceEntry の確認
-----------------------

前回は最終的に次の設定を行いました。これで httpbin.org と www.google.com 宛ては通信が許可されました。(outboundTrafficPolicy は REGISTRY\_ONLY でした)

```
$ kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: external-svc
spec:
  hosts:
  - httpbin.org
  - www.google.com
  location: MESH\_EXTERNAL
  ports:
  - number: 80
    name: http
    protocol: HTTP
  - number: 443
    name: tls
    protocol: TLS
  resolution: DNS
EOF

```

しかし、これでは直接各サイトに出ていくだけです。[Fault Injection](https://istio.io/docs/reference/config/networking/virtual-service/#HTTPFaultInjection) は [VirtualService](https://istio.io/docs/reference/config/networking/virtual-service/) の機能でした。「[VirtualService 編](/2020/03/istio-part3/)」を読み返しましょう。VirtualService にはそのサービスの転送先として [DestinationRule](https://istio.io/docs/reference/config/networking/destination-rule/) しました。

VirtualService の作成
------------------

### httpbin.org

httpbin.org 用の VirtualService を作成します。httpbin.org は HTTPS には対応していないため port 80 だけです。全リクエストに3秒の delay を入れ、30% のリクエストは 500 Internal Server Error を返すようにしてみます。DestinationRule は登録せずとも ServiceEntry があるため接続できます。ServiceEntry がない場合は `"response_flags":"NR,DI"` で Injection の後でエラーになります。これは outboundTrafficPolicy が ALLOW\_ANY でも同じです。ServiceEntry が必要です。

```
$ kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin-org
spec:
  hosts:
  - httpbin.org
  http:
  - match:
    - port: 80
    **fault:**
      **delay:**
        **fixedDelay: 3s**
        **percentage:**
          **value: 100**
      **abort:**
        **httpStatus: 500**
        **percentage:**
          **value: 30**
    route:
    - destination:
        host: httpbin.org
EOF

```

Delay だけが適用された時のログです。

```
{
  "authority": "httpbin.org",
  "bytes\_received": "0",
  "bytes\_sent": "34",
  "downstream\_local\_address": "35.170.216.115:80",
  "downstream\_remote\_address": "172.17.0.8:43426",
  "duration": "3366",
  "istio\_policy\_status": "-",
  "method": "GET",
  "path": "/ip",
  "protocol": "HTTP/1.1",
  "request\_id": "fa22dc61-1cc5-45c4-bc97-4f02d8a7c468",
  "requested\_server\_name": "-",
  **"response\_code": "200"**,
  **"response\_flags": "DI"**,
  "route\_name": "-",
  "start\_time": "2020-03-11T15:24:31.272Z",
  "upstream\_cluster": "outbound|80||httpbin.org",
  "upstream\_host": "34.230.193.231:80",
  "upstream\_local\_address": "172.17.0.8:54090",
  "upstream\_service\_time": "361",
  "upstream\_transport\_failure\_reason": "-",
  "user\_agent": "curl/7.58.0",
  "x\_forwarded\_for": "-"
}

```

こちらは Delay と Fault が両方適用された時のログです。

```
{
  "authority": "httpbin.org",
  "bytes\_received": "0",
  "bytes\_sent": "18",
  "downstream\_local\_address": "3.232.168.170:80",
  "downstream\_remote\_address": "172.17.0.8:50018",
  "duration": "3001",
  "istio\_policy\_status": "-",
  "method": "GET",
  "path": "/ip",
  "protocol": "HTTP/1.1",
  "request\_id": "98a3a4c5-4a0d-4325-a800-da7c3b6db3e3",
  "requested\_server\_name": "-",
  **"response\_code": "500"**,
  **"response\_flags": "DI,FI"**,
  "route\_name": "-",
  "start\_time": "2020-03-11T15:24:47.524Z",
  "upstream\_cluster": "-",
  "upstream\_host": "-",
  "upstream\_local\_address": "-",
  "upstream\_service\_time": "-",
  "upstream\_transport\_failure\_reason": "-",
  "user\_agent": "curl/7.58.0",
  "x\_forwarded\_for": "-"
}

```

### www.google.com

それでは次に www.google.com の VirtualService を作成します。こちらは https にも対応しています。で、ここがキモですが、そのままでは Envoy は https の中身には関与しませんでした。でも Fault Injection をするためにはそれではいけませんから、http で受けたリクエストを Envoy が proxy する際に https にして接続するようにします。そうすることで元のリクエストは http なので中身をいじることができます。さっきとの違いがわかるように今回は delay を1秒に、abort を 400 Bad Request にしてみます。

今回は destination に tls-origination という subset を指定してあります。これは下に続く DestinationRule で定義してあります。**tls.mode** を **SIMPLE** にして **sni** で www.google.com を指定しています。接続先が SNI 必須の場合はこの sni 指定が必要です。SIMPLE って何？って思いますが、他の選択肢は MUTUAL がクライアント証明書を必要とするやつです。あとは PASSTHROUGH とか。

httpbin.org の時と違って DestinationRule はありますが、こちらも ServiceEntry を消すとアクセスできなくなります。

```
$ kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: www-google-com
spec:
  hosts:
  - www.google.com
  http:
  - match:
    - port: 80
    **fault:**
      **delay:**
        **fixedDelay: 1s**
        **percentage:**
          **value: 100**
      **abort:**
        **httpStatus: 400**
        **percentage:**
          **value: 30**
    route:
    - destination:
        host: www.google.com
        **subset: tls-origination**
        port:
          number: 443
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: www-google-com
spec:
  host: www.google.com
  subsets:
  **\- name: tls-origination**
    **trafficPolicy:**
      **portLevelSettings:**
      **\- port:**
          **number: 443**
        **tls:**
          **mode: SIMPLE**
          **sni: www.google.com**
EOF

```

これで **http**://www.google.com/ にアクセスすれば Envoy が Injection したうえで https で www.google.com に proxy してくれます。

ログです。`"downstream_local_address": "216.58.197.196:80"` で curl は www.google.com の port 80 にアクセスしようとしたことがわかります。`"upstream_cluster": "outbound|443|tls-origination|www.google.com"` で Envoy 内の経路がわかります。DestinationRule の tls-origination が使われています。`"upstream_host": "216.58.197.196:443"` で proxy 先が port 443 (https) であることがわかります。

```
{
  "authority": "www.google.com",
  "bytes\_received": "0",
  "bytes\_sent": "13062",
  **"downstream\_local\_address": "216.58.197.196:80"**,
  "downstream\_remote\_address": "172.17.0.8:41130",
  "duration": "1189",
  "istio\_policy\_status": "-",
  "method": "GET",
  "path": "/",
  "protocol": "HTTP/1.1",
  "request\_id": "069baa9b-7d0a-4e84-9b4b-a11e34226fce",
  "requested\_server\_name": "-",
  "response\_code": "200",
  **"response\_flags": "DI"**,
  "route\_name": "-",
  "start\_time": "2020-03-11T15:38:11.379Z",
  **"upstream\_cluster": "outbound|443|tls-origination|www.google.com"**,
  **"upstream\_host": "216.58.197.196:443"**,
  "upstream\_local\_address": "172.17.0.8:43430",
  "upstream\_service\_time": "186",
  "upstream\_transport\_failure\_reason": "-",
  "user\_agent": "curl/7.58.0",
  "x\_forwarded\_for": "-"
}

```

次は Fault が Inject された時のログです。これは proxy せずに 400 を返しているため proxy 先の情報はありません。

```
{
  "authority": "www.google.com",
  "bytes\_received": "0",
  "bytes\_sent": "18",
  "downstream\_local\_address": "216.58.197.196:80",
  "downstream\_remote\_address": "172.17.0.8:41304",
  "duration": "1001",
  "istio\_policy\_status": "-",
  "method": "GET",
  "path": "/",
  "protocol": "HTTP/1.1",
  "request\_id": "78dabd1b-fe57-41fb-8eaf-44ccc6517e3b",
  "requested\_server\_name": "-",
  **"response\_code": "400"**,
  **"response\_flags": "DI,FI"**,
  "route\_name": "-",
  "start\_time": "2020-03-11T15:38:21.648Z",
  "upstream\_cluster": "-",
  "upstream\_host": "-",
  "upstream\_local\_address": "-",
  "upstream\_service\_time": "-",
  "upstream\_transport\_failure\_reason": "-",
  "user\_agent": "curl/7.58.0",
  "x\_forwarded\_for": "-"
}

```

www.google.com に https でアクセスしようとするとどうなるか
----------------------------------------

本来、https でアクセスするべきところに http でアクセスするようにしなければならないわけですが、https のままアクセスしようとするとどうなるでしょうか。

冒頭で前回までの設定を確認しましたが、そこで ServiceEntry に https の設定が残っているため、https の場合はその設定が有効でそのままアクセスできます。もちろん outboundTrafficPolicy が ALLOW\_ANY であればその ServiceEntry も不要ですね。

コンテナ化されたアプリケーションでは外部リソースの定義は ConfigMap などを使って容易に変更可能なはずですよね。Fault Injection 使っていきましょう。

まとめ
---

クラスタ外へのアクセスでも VirtualService を使うことができ、Fault Injection することができることを確認しました。https の termination だけじゃなくて orinination も Envoy に任せられることも確認できました。

[Accessing External Services](https://istio.io/docs/tasks/traffic-management/egress/egress-control/) とか [Egress TLS Origination](https://istio.io/docs/tasks/traffic-management/egress/egress-tls-origination/) に書いてあります。

は〜〜、まだまだいろいろあるなあ、先は長い。[続く](/2020/03/istio-part9/)

* * *

Istio 導入への道シリーズ

*   [Istio 導入への道 (1) – インストール編](/2020/03/istio-part1/)
*   [Istio 導入への道 (2) – サービス間通信編](/2020/03/istio-part2/)
*   [Istio 導入への道 (3) – VirtualService 編](/2020/03/istio-part3/)
*   [Istio 導入への道 (4) – Fault Injection 編](/2020/03/istio-part4/)
*   [Istio 導入への道 (5) – OutlierDetection と Retry 編](/2020/03/istio-part5/)
*   [Istio 導入への道 (6) – Ingress Gatway 編](/2020/03/istio-part6/)
*   [Istio 導入への道 (7) – 外部へのアクセス / ServiceEntry 編](/2020/03/istio-part7/)
*   Istio 導入への道 (8) – 外部へのアクセスでも Fault Injection 編
*   [Istio 導入への道 (9) – gRPC でも Fault Injection 編](/2020/03/istio-part9/)
*   [Istio 導入への道 (10) – 図解](/2020/03/istio-part10/)
*   [Istio 導入への道 (11) – Ingress Gateway で TLS Termination 編](/2020/03/istio-part11/)
