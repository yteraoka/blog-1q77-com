---
title: 'Rancher 2.0 beta を触ってみる - その2'
date: Tue, 17 Apr 2018 15:18:41 +0000
draft: false
tags: ['DigitalOcean', 'Kubernetes', 'Rancher']
---

[前回](/2018/04/rancher-2-0-beta2-part1/)の続きです。
beta2 から beta3 に更新されて Amazon EKS も管理できるようになっていました。

今回は Rancher の Web UI からポチポチやってコンテナをデプロイしてみます。

DigitalOcean に3台の node で Kubernetes 環境を作った状態から始めます。

Workloads ページから Deploy ボタンをクリックします

{{< figure src="rancher-k8s-default-namespace.png" >}}

nginx コンテナをデプロイします。必須項目だけ埋めます。
Name: nginx Docker Image: nginx:1.12 Namespace: myapp1 (`Default` を使いたかったけど選択肢に出てこない) Port Mapping は Internal cluster IP で Container port を 80 とします

{{< figure src="rancher-deploy-workload-myapp1-nginx.png" >}}

最初は namespace が active になるのにちょっと時間がかかりました

{{< figure src="rancher-workloads.png" >}}

scale: 1 の右にある「-」、「+」ボタンでコンテナの数を増減させられます

{{< figure src="rancher-nginx-workload.png" >}}

ポチポチとクリックしてコンテナ数が3になりました

{{< figure src="rancher-nginx-workload2.png" >}}

3つのコンテナのサービスができたところで Load Balancer を設定して外部からアクセスできるようにします。「Add Ingress」ボタンで作成画面に入ります。

{{< figure src="rancher-load-balancing.png" >}}

今回はサービス1個なので「Set this rule as default backend」にチェックを入れて node の port 80 を全部先程作成した nginx のサービスに送ります。Host ヘッダーや Path で振り分け可能です。

{{< figure src="rancher-add-ingress1.png" >}}

コンテナの右にある三点アイコンから「View Logs」を選択すると次のキャプチャの様にログを確認できます。「Execute Shell」を選択すれば docker exec / kubectl exec でコンテナ内に入れます

{{< figure src="rancher-view-logs.png" >}}

こんな感じでログが流れていくのが確認できます。前回 embeded elasticsearch を有効化しましたが今回はまだ有効にしていません。

{{< figure src="rancher-container-log.png" >}}

Workload 単位の表示で三点アイコンをクリックすると次のようなメニューが表示されます。「Edit」からコンテナの更新ができます。今回はやらないけど Sidecar の追加も簡単にできそうです

{{< figure src="rancher-workload-menu.png" >}}

nginx を nginx:1.13.12-alpine に更新してみます、Docker Image を指定してアップグレードします

{{< figure src="rancher-nginx-upgrade.png" >}}

アップグレード中のバージョンが混ざった状態をキャプチャし忘れたけど更新されました

{{< figure src="rancher-nginx-upgraded.png" >}}

本日はここまで。次は複数コンテナとかYAMLでインポートとか heml でセットアップしてみよう。
