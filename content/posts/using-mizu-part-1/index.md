---
title: 'Mizu で kubernetes 内の通信を覗く (part 1)'
date: Sun, 05 Jun 2022 01:04:52 +0900
draft: false
tags: ['Kubernetes']
---

[Mizu - API Traffic viewer for Kubernetes](https://getmizu.io/) というものの存在を知ったので試してみます。  

サイトには次のように書いてあります。気になります。

> **Mizu** offers a real-time view of all HTTP requests, REST and gRPC API calls, as well as Kafka, AMQP (activeMQ / RabbitMQ), and Redis.

HTTP も gRPC も Redis や Kafka とかも通信内容を parse して見やすく表示してくれるそうな。

使い方を見ても `mizu tap` と実行するだけになっていて、マジで？？ という感じなので実際にやってみます。

例えば、Intel Mac なら次のようにして mizu バイナリをダウンロードして実行するだけ。インストール対象の Kubernetes にアクセスできるように KUBECONFIG などは設定されている前提です。kubectl でアクセスできるようになっていれば大丈夫。

```bash
curl -Lo mizu https://github.com/up9inc/mizu/releases/latest/download/mizu_darwin_amd64 \
&& chmod 755 mizu
./mizu tap -A
```

これで localhost:8899 がブラウザで開かれてサイトにあるような画面が表示されます。`-A` は `--all-namespaces` なので対象が多くなるため外して実行しました。KUBECONFIG の current-context の　namespace が対象となります。

通信を覗く対象として [micoroservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo) をデプロイしておきました。

こんなショッピングサイトのやつです。  
{{< figure src="online-boutique.png" alt="online boutique" >}}

HTTP 通信の例です。header や body が見えています。このキャプチャにはないですが、 response も見えます。  
{{< figure src="mizu-http.png" alt="HTTP 通信のキャプチャ" >}}

gRPC 通信の例です。proto ファイルがないので message の表示は field 名が連番っぽいものになっていますが、値は見れます。  
{{< figure src="mizu-grpc.png" alt="gRPC 通信のキャプチャ" >}}

左に表示されている一覧の上部でフィルタリングができます。protocol (http とか grpc とか redis とか) や送信元や送信先などで、 `and` や `or` `(` `)` なども使えます。

右上にある **Service Map** というボタンをクリックすると、次のような表示がされます。Distributed Tracing で見るようなやつですね。

{{< figure src="mizu-service-map.png" alt="Service Map" >}}

ただし、frontend から線が出ていないのもおかしいし、redis が登場しないのもおかしい。また、frontend に対して loadgenerator からアクセスが行われているはずなのにそれも表示されない。謎

それはそうと、mizu コマンドは mizu tap で何をおこなっているのか、ですが、mizu という名前の namespace を作成し、 ServiceAccount と ClusterRole (設定によっては Role) を作成し、紐づける。それから mizu-api-server という Pod と Service を作成する。その後に mizu-tapper-daemon-set という DaemonSet がデプロイされます。

この DaemonSet が　packet をキャプチャして mizu-api-server に送り、手元の mizu コマンドで起動されるサーバーが Kubernetes API Server 経由で mizu-api-server にアクセスをしている。

```
$ k get all -n mizu
NAME                               READY   STATUS    RESTARTS   AGE
pod/mizu-api-server                2/2     Running   0          25m
pod/mizu-tapper-daemon-set-6bvbr   1/1     Running   0          25m
pod/mizu-tapper-daemon-set-8h454   1/1     Running   0          25m
pod/mizu-tapper-daemon-set-v8vnj   1/1     Running   0          25m

NAME                      TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/mizu-api-server   ClusterIP   172.16.6.149   <none>        80/TCP    25m

NAME                                    DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
daemonset.apps/mizu-tapper-daemon-set   3         3         3       3            3           <none>          25m

```

mizu コマンドを Ctrl-C で停止すると、これらのリソースの削除も行ってくれます。

ということで、クラスタに対する必要な権限があり、キャプチャ可能な Pod を deploy 可能な環境であれば mizu コマンドをダウンロードして実行するだけで通信内容が見えるのです。使えたら便利なこともあるかな、程度。tcpdump が不要になったりはしない。

さて、先ほどの Service Map ですが、何かがおかしいです。 frontend へのアクセスは通信内容も確認できているので大きな緑の丸がありますが、frontend からの通信が見えていません。また、redis へのアクセスも見えていません。  
これとは別に [kubernetes/examples](https://github.com/kubernetes/examples) にある guestbook-go で試した時は redis サーバーとの通信内容も見えていました。

こんな Service Map が表示されて欲しかった。  
{{< figure src="architecture-diagram.png" alt="期待していた Service Map" >}}

Istio で mTLS が有効になっていても問題ないよということなので次回試して見ます。
