---
title: 'RancherのKubernetesにサービスをデプロイしてみる'
date: Tue, 02 May 2017 12:44:12 +0000
draft: false
tags: ['Caddy', 'Kubernetes', 'Rancher', 'HAProxy', 'sacloud']
---

「[さくらのクラウドRancherOSでKubernetes環境を構築](/2017/05/build-kubernetes-using-rancheros-on-sakura-cloud/)」の続きです。さくらのクラウドで Rancher + RancherOS を使って構築した Kubernetes 環境にサービスをデプロイしてみます。Kubernetes への deploy 自体は minikube でやったことがある（[Kubernetes Secrets を使って minikube に netbox を deploy してみる](/2017/02/deploy-netbox-on-minikube/)）ので Rancher を使った場合のネットワーク構成とかを調査していきたい。

### Caddy で Rancher の HTTPS 化

Kubernetes の前に、前回は Rancher サーバーに直接アクセスしていましたが、HTTPS 化のために [Caddy](https://caddyserver.com/) を入れてみました。勝手に Let's Encrypt っから証明書を取得して設定してくれるので便利です。

Caddy については先日「[Caddy という高機能 HTTPS サーバー](https://blog.1q77.com/2017/04/caddy/)」を書きました。

適当な `Dockerfile` を書いて Docker Hub に push して使いました。実行時に Caddyfile をテンプレートから生成したかったので [Entrykit](https://github.com/progrium/entrykit) を使いました。（[Entrykit の使い方](https://blog.1q77.com/2016/09/how-to-use-entrykit/)）

```dockerfile
FROM alpine
EXPOSE 80 443
ENV CADDYPATH /etc/ssl/caddy
STOPSIGNAL SIGQUIT
COPY ./caddy /usr/bin/caddy
COPY ./entrykit /usr/bin/entrykit
COPY ./Caddyfile.tmpl /etc/Caddyfile.tmpl
RUN mkdir -p /usr/share/caddy/html; mkdir -p /etc/ssl/caddy; chmod 755 /usr/bin/caddy /usr/bin/entrykit; /usr/bin/entrykit --symlink; apk --update add ca-certificates; rm -fr /var/cache/apk
ENTRYPOINT ["/usr/bin/render", "/etc/Caddyfile", \
            "--", \
            "/usr/bin/caddy", \
              "-log=stdout", "-agree=true", \
              "-conf=/etc/Caddyfile", "-root=/usr/share/caddy/html"]

```

普通の Reverse Proxy で良いのだろうと、こんな出来上がりになるようにしてみたところ、Rancher Agent からのアクセスは WebSocket が通る必要がありました。

```nginx
rancher.teraoka.me {
    proxy / 172.17.0.2:8080 {
        header_upstream Host {host}
        header_upstream X-Forwarded-Proto {scheme}
    }
}
```

そこで `-e RANCHER_USE_WEBSOCKET=true` とした場合に1行 websocket と追加されるようにしました。

```nginx
rancher.teraoka.me {
    proxy / 172.17.0.2:8080 {
        header_upstream Host {host}
        header_upstream X-Forwarded-Proto {scheme}
        websocket
    }
}
```

これで無事ブラウザからも Rancher Agent からのアクセスもできるようになりました。

### 無駄骨・・・

わざわざ別サーバーを間に入れなくても Rancher サーバーは 8080/tcp で HTTP にも HTTPS にも両方対応しているのでした！！Caddy サーバーをセットアップした後に気づきました・・・ 😢

### Kubectl で Kubernetes にアクセス

Rancher 上部の「`KUBERNETES`」から「`CLI`」を選択すると次の画面になるのでここでブラウザから kubectl コマンドを実行することもできますが、「`Generate Config`」ボタンをクリックして生成される設定を `~/.kube/config` にコピペすればローカル PC から kubectl コマンドでアクセスできるようになります。

{{< figure src="rancher-kubernetes-cli.png" caption="Rancher Kubernetes CLI" >}}

ブラウザ内のコンソールから `kubectl version` を実行した出力

```
# Run kubectl commands inside here
# e.g. kubectl get rc

> kubectl version
Client Version: version.Info{Major:"1", Minor:"5", GitVersion:"v1.5.4", GitCommit:"7243c69eb523aa4377bce883e7c0dd76b84709a1", GitTreeState:"clean", BuildDate:"2017-03-07T23:53:09Z", GoVersion:"go1.7.4", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"5+", GitVersion:"v1.5.4-rancher1", GitCommit:"6ed2b64b2e1df9637661077d877a0483c58a6ae5", GitTreeState:"clean", BuildDate:"2017-03-17T16:58:04Z", GoVersion:"go1.7.4", Compiler:"gc", Platform:"linux/amd64"}
```

ローカル PC から試した出力（クライアントのバージョンが 1.6.0）

```
$ kubectl version
Client Version: version.Info{Major:"1", Minor:"6", GitVersion:"v1.6.0", GitCommit:"fff5156092b56e6bd60fff75aad4dc9de6b6ef37", GitTreeState:"clean", BuildDate:"2017-03-28T16:36:33Z", GoVersion:"go1.7.5", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"5+", GitVersion:"v1.5.4-rancher1", GitCommit:"6ed2b64b2e1df9637661077d877a0483c58a6ae5", GitTreeState:"clean", BuildDate:"2017-03-17T16:58:04Z", GoVersion:"go1.7.4", Compiler:"gc", Platform:"linux/amd64"}
```

`kubectl` は

```
$ source <(kubectl completion bash)
```

とすれば補完が効いて便利になる[ようだ](https://kubernetes.io/docs/user-guide/kubectl-cheatsheet/)。`zsh` なら `bash` のところを `zsh` すればよし。

### Guestbook Example アプリを Kubernetes にデプロイしてみる

[https://github.com/kubernetes/kubernetes/tree/master/examples/guestbook](https://github.com/kubernetes/kubernetes/tree/master/examples/guestbook) にある Guestbook アプリをデプロイしてみる（Kubernetes の紹介で時々見かけるやつですね）。 [guestbook-all-in-one.yaml](https://github.com/kubernetes/kubernetes/blob/master/examples/guestbook/all-in-one/guestbook-all-in-one.yaml) を使うと一発でできちゃうんですが一箇所だけ修正します。 コメントアウトされている `type: LoadBalancer` をアンコメントします。

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend
  labels:
    app: guestbook
    tier: frontend
spec:
  # if your cluster supports it, uncomment the following to automatically create
  # an external load-balanced IP for the frontend service.
  type: LoadBalancer
  ports:
    # the port that this service should serve on
  - port: 80
  selector:
    app: guestbook
    tier: frontend
```

```
$ kubectl create -f guestbook-all-in-one.yaml --record
service "redis-master" created
deployment "redis-master" created
service "redis-slave" created
deployment "redis-slave" created
service "frontend" created
deployment "frontend" created
```

Kubernetes の Dashboard から Deployments を確認すると frontend という Apache + mod\_php のアプリ Container (Pod) が3つと redis のマスターが1つ、 redis のレプリカが2つ起動しているのが確認できます。

{{< figure src="kubernetes-guestbook-deployments.png" caption="Kubernetes Dashboard Deployments - guestbook" >}}

Services を確認するとそれぞれの Cluster IP が確認できます。

{{< figure src="kubernetes-guestbook-services.png" caption="Kubernetes Dashboard Services - guestbook" >}}

`External Endpoints` に表示されているIPアドレス、ポート番号にブラウザからアクセスすると Guestbook アプリにアクセスできます。次のような表示になります。

{{< figure src="guestbook-app.png" caption="guestbook-app" >}}

### 名前解決

guestbook.php の中身は次のようになっており redis のサーバー名は `GET_HOSTS_FROM` という環境変数が `env` の場合は環境変数 `REDIS_MASTER_SERVICE_HOST`, `REDIS_SLAVE_SERVICE_HOST` から取得し、そうでない場合は `redis-master`, `redis-slave` という名前で DNS によって解決しています。`guestbook-all-in-one.yaml` では `GET_HOSTS_FROM` は `dns` になっていますから DNS ですね。[rancher-dns](https://github.com/rancher/rancher-dns) ってのが動いてるっぽいけど `resolv.conf` にある `10.43.0.10` というアドレスがどこにどう定義されているのか要調査。

```php
<?php

error_reporting(E_ALL);
ini_set('display_errors', 1);

require 'Predis/Autoloader.php';

Predis\Autoloader::register();

if (isset($_GET['cmd']) === true) {
  $host = 'redis-master';
  if (getenv('GET_HOSTS_FROM') == 'env') {
    $host = getenv('REDIS_MASTER_SERVICE_HOST');
  }
  header('Content-Type: application/json');
  if ($_GET['cmd'] == 'set') {
    $client = new Predis\Client([
      'scheme' => 'tcp',
      'host'   => $host,
      'port'   => 6379,
    ]);

    $client->set($_GET['key'], $_GET['value']);
    print('{"message": "Updated"}');
  } else {
    $host = 'redis-slave';
    if (getenv('GET_HOSTS_FROM') == 'env') {
      $host = getenv('REDIS_SLAVE_SERVICE_HOST');
    }
    $client = new Predis\Client([
      'scheme' => 'tcp',
      'host'   => $host,
      'port'   => 6379,
    ]);

    $value = $client->get($_GET['key']);
    print('{"data": "' . $value . '"}');
  }
} else {
  phpinfo();
} ?>
```

### LoadBalancer

`guestbook-all-in-one.yaml` の `type: LoadBalancer` 行をアンコメントしましたが、これによって何ができたかというと「`KUBERNETES`」の「`Infrastructure Stacks`」を確認すると「`kubernetes loadbalancers`」に次のような表示が確認できます。

[![rancher kubernetes loadbalancers](http://13.230.26.187/wp-content/uploads/2017/05/rancher-kubernetes-loadbalancer-300x64.png)](http://158.101.138.193/wp-content/uploads/2017/05/rancher-kubernetes-loadbalancer.png)

この中で `lb-a9a2059bd2efb11e7a82402a939d3449` を見てみると次のような情報も確認できます。「`Ports`」ではどのホストのIPアドレスで外からのアクセスを受け付けるようになっているかが確認できます。今回の例では k8s-01 のIPアドレスになっています。

[![Rancher Kubernetes LB Service (port)](http://13.230.26.187/wp-content/uploads/2017/05/rancher-kubernetes-loadbalancer-ports-300x140.png)](http://158.101.138.193/wp-content/uploads/2017/05/rancher-kubernetes-loadbalancer-ports.png)

`Balancer Rules` タブではどのホストのどのポート (container) に転送するかがわかります。

[![Rancher Kubernetes LB Service (rules)](http://13.230.26.187/wp-content/uploads/2017/05/rancher-kubernetes-loadbalancer-rules-300x152.png)](http://158.101.138.193/wp-content/uploads/2017/05/rancher-kubernetes-loadbalancer-rules.png)

この Load Balancer は HAProxy コンテナで実装されています。haproxy.cfg を確認してみると次のようになっていました。proxy 先は Global IP Address なのですね。ホストがインターネットに晒されている場合は iptables や手間でのどこかで閉じていないとここに直接アクセスできてしまいますね。Service の Cluster IP に転送するのかと思っていたが違っていたようだ。Cluster IP は Kubernetes 内でアクセスするためのアドレスだから外から転送するには NodePort を使わざるを得ないということか。

```haproxy
global
    chroot /var/lib/haproxy
    daemon
    group haproxy
    maxconn 4096
    maxpipes 1024
    ssl-default-bind-ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:ECDHE-RSA-DES-CBC3-SHA:ECDHE-ECDSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA
    ssl-default-bind-options no-sslv3 no-tlsv10
    ssl-default-server-ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:ECDHE-RSA-DES-CBC3-SHA:ECDHE-ECDSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA
    tune.ssl.default-dh-param 2048
    user haproxy

defaults
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http
    maxconn 4096
    mode tcp
    option forwardfor
    option http-server-close
    option redispatch
    retries 3
    timeout client 50000
    timeout connect 5000
    timeout server 50000

resolvers rancher
 nameserver dnsmasq 169.254.169.250:53

listen default
bind *:42

frontend 80
bind *:80
mode tcp
default_backend 80_

backend 80_
acl forwarded_proto hdr_cnt(X-Forwarded-Proto) eq 0
acl forwarded_port hdr_cnt(X-Forwarded-Port) eq 0
    http-request add-header X-Forwarded-Port %[dst_port] if forwarded_port
    http-request add-header X-Forwarded-Proto https if { ssl_fc } forwarded_proto
mode tcp
server 9c51f1b00fd9e1eb2211cde0ed46d9456d0213f5 153.120.129.113:31877
server aa73f7199039e58a2c5c6081e56edf6d27e06c31 153.120.82.8:31877
server cf4c62546250ba397c98196c8ce9c08ceef88342 133.242.49.48:31877
```

この LB は1台のホストでしか稼働していないのでその1台が止まってしまうとこまります。でも `Service` ページの左側にある「`Scale`」欄の「`+ / -`」で増減できます。3に増やすことで k8s-01, k8s-02, k8s-03 のどのサーバーでも受けられるようにできます。

LB 1台の状態で当該ホストを強制シャットダウンしたら別の当該ホストで稼働していた他のコンテナ同様に別のホストでえ起動してきました。Rancher の Proxy 経由でアクセスする Kubernetes の dashboard はなぜかなかなか切り替わってくれなかったけど、kubectl でアクセスする方はすぐに切り替わってました。

続き「[RancherのKubernetesにサービスをデプロイしてみる(2)](/2017/05/deploy-services-on-k8s-with-rancher-2/)」
