---
title: 'GKE Tutorials (2)'
date: Mon, 06 Jan 2020 16:04:18 +0000
draft: false
tags: ['GCP']
---

続 [Tutorials](https://cloud.google.com/kubernetes-engine/docs/tutorials/?hl=en) を順に試す。（[前回](/2020/01/gke-tutorials-part1/)）

Best Practices for Operating Containers
---------------------------------------

[Best Practices for Operating Containers](https://cloud.google.com/solutions/best-practices-for-operating-containers)

[前回](/2020/01/gke-tutorials-part1/)の最後のやつと同じようなベストプラクティス紹介です。今回は運用編。

### Use the native logging mechanisms of containers

重要度: 高

ログは重要であり、Docker や Kubernetes はこれの扱いに力を入れている。stdout, stderr に出して Docker や Kubernetes の提供する機能を使ってプラットフォームが提供するログ管理システムへ送るのが良い。フォーマットに JSON を使うと検索や集計が容易になる。ただし、アプリケーションによっては容易にログの出力先を変更できない場合がある（例えば Tomcat など）。この場合は[サイドカーパターン](https://kubernetes.io/docs/concepts/cluster-administration/logging/#sidecar-container-with-a-logging-agent)を利用すると良い。このパターンでは Pod 内の複数のコンテナで [emptyDir](https://kubernetes.io/docs/concepts/storage/volumes/#emptydir) ボリュームを共有し、アプリコンテナが書き出したログをログエージェントコンテナで読み出して集約先に送る。ログエージェントがファイルのローテーションに対応していなければこれについても考える必要がある。

### Ensure that your containers are stateless and immutable

重要度: 高

コンテナはステートレスでイミュータブルでなければならない。脆弱性があっても直接コンテナ内でパッチを当てるのではなく新しいイメージを作成して入れ替えることで対応する。

#### Statelessness

ステートレスとは状態（データ）が外部に保存されることを意味する。

*   ファイルであれば [Cloud Storage](https://cloud.google.com/storage/docs) などのオブジェクトストレージに保存することが望ましい
*   セッションデータは [Redis](https://cloud.google.com/memorystore/docs/redis/) や Memcached など、外部の低遅延なキーバリューストアに保存することが望ましい
*   ブロックストレージが必要な場合は GKE では [persistent disks](https://cloud.google.com/kubernetes-engine/docs/how-to/stateful-apps) の使用が望ましい

こうすることでデータを失うことなく、いつでもコンテナをシャットダウンすることができるし、更新も容易となる。

#### Immutability

イミュータブルとは実行中のコンテナに変更を加えないこと。設定変更やパッチ適用はコンテナイメージを作り直して入れ替えることで対応する。こうすることでロールバックも古いイメージを再度デプロイするだけで完了する。また全ての環境を同一に保つことを容易にする。

実行環境によって切り替えたい設定は [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/) や [ConfigMaps](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/) を使って指定できるようにしておく。

### Avoid privileged containers

重要度: 高

仮想サーバーでアプリケーションを root ユーザーで実行しないのと同じように、乗っ取られた場合の危険度を考慮し、コンテナに特権を与えてはいけない。

特権が必要だと思った場合には次の代替案を検討すべき

*   Kubernetes の [securityContext option](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-capabilities-for-a-container) や Docker の --cap-add フラグで特定の capabilities を与える。[Docker のドキュメント](https://docs.docker.com/engine/reference/run/#runtime-privilege-and-linux-capabilities)にデフォルトで有効な capabilities と明示的に追加の必要な capabilities のリストがある
*   どうしても host の設定を変更する必要がある場合はサイドカーや [init container](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/) を使う。このコンテナは直接外部からのアクセスを受けないためより安全になる
*   Kubernetes で sysctl を変更する必要がある場合は [dedicated annotation](https://kubernetes.io/docs/concepts/cluster-administration/sysctl-cluster/) を使う

Kubernetes では [Pod Security Policy](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#privileged) によって特権コンテナの実行を禁止することができる。

### Make your application easy to monitor

重要度: 高

ロギングと同様に、モニタリングはアプリケーションの運用に不可欠である。

コンテナ環境は動的に監視対象が変わるため、それに適したモニタリングシステムが必要であり、メトリクス収集では [Prometheus](https://prometheus.io/) が人気。[Stackdriver](https://cloud.google.com/monitoring/kubernetes-engine/) は Kubernetes クラスタとアプリを Prometheus でモニタリングが可能。([enable Stackdriver Kubernetes Monitoring on GKE](https://cloud.google.com/monitoring/kubernetes-engine/))

Prometheus や Stackdriver Kubernetes Monitoring でアプリのモニタリングを行うには Prometheus 形式のメトリクスを提供する必要がある。これには[アプリケーション自身にメトリクス用の HTTP エンドポイントを実装する](https://cloud.google.com/solutions/best-practices-for-operating-containers#expose_the_health_of_your_application)方法とサイドカーを使ってサイドカー側で提供する方法がある。後者は例えば [jmx\_exporter](https://github.com/prometheus/jmx_exporter) などをサイドカーで実行する。

### Expose the health of your application

重要度: 中

Kubernetes には Liveness probe と Readiness probe の2種類のヘルスチェックがある。詳細は [Kubernetes documentation](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-probes/) を参照。

#### Liveness probe

[Liveness probe](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-probes/#define-a-liveness-http-request) は /health という HTTP エンドポイントを使うことが推奨される。正常な場合は 200 OK を返す。正常でない結果が返った場合、Kubernetes はコンテナのリスタートをかけたりする。

#### Readiness probe

[Readiness probe](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-probes/#define-readiness-probes) は /ready という HTTP エンドポイントを使うことが推奨される。正常な場合は 200 OK を返す。これはリクエストを受けられる状態であることを意味し、Kubernetes はリクエストトラフィックを流し始める。

Deployment の更新時、Readiness が成功するまでまって次の Pod の更新に移る。

多くのアプリケーションでは Liveness と Readiness の状態に違いがなく、どちらも同じエンドポイントを使用する。

### Avoid running as root

重要度: 中

コンテナはホストと kernel を共有しているため、未知の脆弱性への対策としてコンテナ内のアプリを root で実行しないことが推奨される。Kubernetes では [PodSecurityPolicy](https://cloud.google.com/kubernetes-engine/docs/how-to/pod-security-policies) で root で実行させないように強制したり、[runAsUser option](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-pod) で Dockerfile の USER を上書きすることができるが、多くのメジャーなアプリの公式イメージが root で実行していたりして、ファイルシステムの権限周りで問題があるかもしれない。

External volume の場合は [fsGroup Kubernetes option](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-pod) で権限問題を回避可能。

root でないと 1024 より小さなポート番号で Listen できないことは Kubernetes のサービスが redirect してくれるため問題ではない。

### Carefully choose the image version

重要度: 中

とにかく latest タグは使うべきでない。Dockerfile で FROM に指定するイメージの tag はセマンティックバージョニングされていればパッチバージョンを省略すれば、新たにイメージをビルドする際にはパッチ適用済みのものが使われるのでこの辺りも要検討。

続く...