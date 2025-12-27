---
title: 'Nginx Ingress Controller と oauth2-proxy で SSO'
date: Wed, 09 Dec 2020 00:21:27 +0900
draft: false
tags: ['Kubernetes', 'Advent Calendar 2020', 'nginx']
---

[Advent Calendar 2020 全部オレシリーズ](https://qiita.com/advent-calendar/2020/yteraoka) 8日目です。もう完走は諦めました。(再掲)

[Nginx Ingress Controller](https://kubernetes.github.io/ingress-nginx/) と [oauth2-proxy](https://github.com/oauth2-proxy/oauth2-proxy) を組み合わせて簡単に SSO を導入するためのメモです。複数のサービスがあって、Nginx Ingress Controller を使ってて、どれも同じ SSO 設定で良いという場合に便利です。nginx の [auth\_request](http://nginx.org/en/docs/http/ngx_http_auth_request_module.html) 設定を Nginx Ingress Controller がいい感じにやってくれます。

Nginx Ingress Controller のインストール
--------------------------------

[ドキュメント](https://kubernetes.github.io/ingress-nginx/deploy/)を見てお好みの方法でインストールしてください。

私は helm でインストールしました。

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install my-release ingress-nginx/ingress-nginx

```

oauth2-proxy のインストール
--------------------

[Helm Chart](https://github.com/helm/charts/tree/master/stable/oauth2-proxy) はあるにはあるけど、もうアーカイブ状態なんですよね。でも使えます。ここでも使っています。

[Keycloak](https://www.keycloak.org/) で SSO する場合の例です、次の YAML を `customize.yaml` として保存して helm に `-f` で渡します。Keycloak のセットアップや Client ID の発行は別途行ってください。Keycloak 以外にも[沢山の Provier に対応しています](https://oauth2-proxy.github.io/oauth2-proxy/docs/configuration/oauth_provider)。便利です。

```yaml
config:
  clientID: example-client
  clientSecret: 71d0785e-3aeb-4e9c-8790-7dc34699afc1
  cookieSecret: bmljaHVjb0xvaHJpZTVnYWhyYWU0ZXY0cmFoMGRvbzZvb0RhaGNoZWVzYXJlNGFT
extraArgs:
  provider: keycloak
  login-url: https://keycloak.example.com/auth/realms/example/protocol/openid-connect/auth
  redeem-url: https://keycloak.example.com/auth/realms/example/protocol/openid-connect/token
  validate-url: https://keycloak.example.com/auth/realms/example/protocol/openid-connect/userinfo
  scope: profile
ingress:
  enabled: true
  path: /oauth2
  hosts:
    - alertmanager.example.com
    - kiali.example.com
    - prometheus.example.com
  annotations:
    kubernetes.io/ingress.class: nginx
```

```bash
helm repo add stable https://charts.helm.sh/stable
helm repo update
helm install stable/oauth2-proxy -f customize.yaml
```

これで次のような Ingress が作成されています。この後出てきますが、各サービスでもそれぞれの Ingress を定義しますが、`/oauth2` についてはそれとは別に定義する必要があるというのがここでの重要なポイントです。私はこれになかなか気付けずに時間がかかりました。

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: nginx
    meta.helm.sh/release-name: oauth2-proxy
    meta.helm.sh/release-namespace: ingress-nginx
  labels:
    app: oauth2-proxy
    app.kubernetes.io/managed-by: Helm
    chart: oauth2-proxy-3.2.3
    heritage: Helm
    release: oauth2-proxy
  name: oauth2-proxy
  namespace: ingress-nginx
spec:
  rules:
  - host: alertmanager.example.com
    http:
      paths:
      - backend:
          serviceName: oauth2-proxy
          servicePort: 80
        path: /oauth2
        pathType: ImplementationSpecific
  - host: kiali.example.com
    http:
      paths:
      - backend:
          serviceName: oauth2-proxy
          servicePort: 80
        path: /oauth2
        pathType: ImplementationSpecific
  - host: prometheus.example.com
    http:
      paths:
      - backend:
          serviceName: oauth2-proxy
          servicePort: 80
        path: /oauth2
        pathType: ImplementationSpecific
```

各サービスの Ingress 設定
-----------------

oauth2-proxy の設定に alertmanager.example.com, kiali.example.com, prometheus.example.com というのを入れてみました。

どれでも同じですが、alertmanager.example.com について設定するとしましょう。おそらく [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) という helm chart で入れるでしょうから直接 Ingress の manifest を書くことはないでしょうが。

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: nginx
    meta.helm.sh/release-name: kube-prometheus-stack
    meta.helm.sh/release-namespace: prometheus
    nginx.ingress.kubernetes.io/auth-signin: https://$host/oauth2/start?rd=$escaped\_request\_uri
    nginx.ingress.kubernetes.io/auth-url: http://oauth2-proxy.ingress-nginx.svc.cluster.local/oauth2/auth
  name: kube-prometheus-stack-alertmanager
  namespace: prometheus
spec:
  rules:
  - host: alertmanager.example.com
    http:
      paths:
      - backend:
          serviceName: kube-prometheus-stack-alertmanager
          servicePort: 9093
        path: /
        pathType: ImplementationSpecific

```

ここで大事なのは `nginx.ingress.kubernetes.io/auth-signin` と `nginx.ingress.kubernetes.io/auth-url` という annotation です。

[auth\_request](http://nginx.org/en/docs/http/ngx_http_auth_request_module.html) は nginx が受けたリクエストのヘッダーを一部いじるものの、ほぼそのまま oauth2-proxy に proxy します。そして proxy 先で cookie の値やらドメイン名、URIなどからログイン済みかどうか、アクセスが許可されているのかどうかを判断して、レスポンスを返します。それを受け取った nginx が本来の upstream に proxy したり認証ページへリダイレクトしたりします。

で、`nginx.ingress.kubernetes.io/auth-url` に指定するのが認証のための proxy 先です。nginx からアクセスできれば良いため Kubernetes クラスタ内通信で良いので .svc.cluster.local のドメインで指定しています。

一方、`nginx.ingress.kubernetes.io/auth-signin` はログインされていない場合のリダイレクト先として使われるため `$host` を使って受け付けた Host ヘッダー (VirtualHost) のドメインが入るようにしてあります。

`/oauth2/` 配下へのアクセスまで auth\_request の対象としてしまうとループしてしまうため、そうならないようにするのが先に少し触れた 同じドメインだけど Ingress が2ヵ所で設定されている理由です。ついつい次のように書いてしまいそうになりますが、これではループしてしまうのです。

```yaml
spec:
  rules:
  - host: alertmanager.example.com
    http:
      paths:
      - backend:
          serviceName: kube-prometheus-stack-alertmanager
          servicePort: 9093
        path: /
      - backend:
          serviceName: oauth2-proxy
          servicePort: 80
        path: /oauth2
```

同じドメインを複数 Ingress に分けて定義しても Nginx Ingress Controller は同一ドメインは同じ VirtualHost にまとめてくれます。

Nginx Ingress Controller が生成する nginx.conf を見ると何をやっているのかがわかります。

ちなみに、oauth2-proxy はその名の通り、それ単体でも認証付きの proxy として動作します。
