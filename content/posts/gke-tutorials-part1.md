---
title: 'GKE Tutorials (1)'
date: Sun, 05 Jan 2020 15:55:53 +0000
draft: false
tags: ['GCP']
---

[Tutorials](https://cloud.google.com/kubernetes-engine/docs/tutorials/?hl=en) を順に試す。

Deploying a containerized web application
-----------------------------------------

[Deploying a containerized web application](https://cloud.google.com/kubernetes-engine/docs/tutorials/hello-app)

サンプルアプリを git clone して docker build, push して YAML を使わず kubectl でコンテナをデプロイして、expose して pod の数を増やしたり、イメージを入れ替えたりする。

Create a Guestbook with Redis and PHP
-------------------------------------

[Create a Guestbook with Redis and PHP](https://cloud.google.com/kubernetes-engine/docs/tutorials/guestbook)  
Deployment リソースができる前の初期からある PHP + Redis のゲストブックですね。Redis の master サービスと replica サービスを作ります。これはなんかもう古くさい手順かな？[こっち](https://github.com/GoogleCloudPlatform/kubernetes-engine-samples/tree/master/guestbook)のやつはまだ ReplicationController って書いてある。

Deploying WordPress on GKE with Persistent Disks and Cloud SQL
--------------------------------------------------------------

[Deploying WordPress on GKE with Persistent Disks and Cloud SQL](https://cloud.google.com/kubernetes-engine/docs/tutorials/persistent-disk) Persistent Volume と Cloud SQL を使った WordPress をデプロイする。Deploy 用の YAML は [wordpress-persistent-disks](https://github.com/GoogleCloudPlatform/kubernetes-engine-samples/tree/master/wordpress-persistent-disks) にある。

*   Cloud SQL の MySQL インスタンスを作成
*   MySQL のユーザー作成
*   Cloud SQL Proxy 用の Service Account を作成
*   作成した Service Account に cloudsql.client ロールを紐付ける
*   Service Account のクレデンシャルを取得して Kubernetes の Secrets に登録
*   MySQL ユーザーのパスワードを Kubernetes の Secrets に登録
*   WordPress の Deployment を作成
    *   Pod に Cloud SQL Proxy コンテナも相乗りして MySQL へのアクセスはこれを経由させる
    *   Persistent Volume を /var/www/html にマウント  
        （/var/www/html に index.php とかが存在しない場合はコピーされる）
*   type: LoadBalancer で Service を作成し、外部公開

Authenticating to Cloud Platform with Service Accounts
------------------------------------------------------

[Authenticating to Cloud Platform with Service Accounts](https://cloud.google.com/kubernetes-engine/docs/tutorials/authenticating-to-cloud-platform)

GKE Workload (container) から Google API へアクセスするサンプル。Service Account を作ってクレデンシャルを Secrets に登録して Cloud Pub/Sub へアクセスします。

Cloud Pub/Sub の topic を作成するのに **gcloud pubsub topics create echo** と gcloud コマンドを使う方法とは別に YAML を書いて kubectl で適用する（kubernetes のリソースのように宣言型の管理が可能となる）[Config Connector](https://cloud.google.com/config-connector/docs/overview) ってのが登場して、これはなんぞや？って調べ始めると [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity) というまた知らないものが出てくる...😩

GKE で実行する Workload から Google API にアクセスする場合は [Google Service Accounts](https://cloud.google.com/iam/docs/service-accounts) (GSAs) のクレデンシャルを Secrets などで別途指定するのではなく、Pod に割り当てる [Kubernetes Service Accounts](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) (KSAs) で Google API にもアクセスできるようにすればよりセキュアだということらしい。（Workload Identity は 2020-01-04 時点ではまだベータ）

Workload Identity を有効にするにはクラスタ作成時に指定すれば良いみたい。ネームスペースがプロジェクト単位であるため、同一プロジェクト内に用途の違うクラスタは相乗りさせない方が良いらしい。開発用と本番用のクラスタを同じプロジェクトに作るとおそらくハマると。

Config Connector / Workload Identiry は手順をなぞってみたけどうまくいかなかったので別途調査が必要。

Best practices for building containers
--------------------------------------

[Best practices for building containers](https://cloud.google.com/solutions/best-practices-for-building-containers)

これはチュートリアルなのか？？？

### Package a single app per container

重要度: 高

コンテナを仮想マシンのように複数のアプリを同居させるのは良くある間違い。Apache, PHP, MySQL であれば2つ(mod\_php)か3つ(PHP-FPM)のコンテナに分ける。アプリが止まればコンテナも止まる、コンテナが止まればアプリも止まる。ライフサイクルの違うものは混ぜるな危険。

Public Image や有名 Vendor の提供する Image にも同居させているものがありますが、安易にそれを真似しないこと。

### Properly handle PID 1, signal handling, and zombie processes

重要度: 高

PID 1 のシグナルハンドリングやゾンビプロセスを正しく扱う。

#### Problem 1: How the Linux kernel handles signals

Linux では PID 1 のプロセスは特別扱いされ、SIGTERM や SIGINT でプロセスの終了という他の PID での処理が行われないため、コンテナ内で PID 1 として起動されるプロセスが自身でシグナルハンドリングしてやる必要がある。

#### Problem 2: How classic init systems handle orphaned processes

systemd などの従来の init システムはゾンビプロセスの削除も担っているし、親プロセスを失ったプロセスの親にもなります。コンテナではこの処理を PID 1 として起動するプロセスが担う必要がある。これをきちんと行わないとメモリやその他のリソースが不足する要因となる。

#### Solution 1: Run as PID 1 and register signal handlers

シグナルハンドラを実装したアプリを PID 1 として実行する。ENTRYPOINT や CMD で直接そのアプリを指定する、前処理などのためにシェルスクリプトから起動させる場合は exec を使って PID 1 がアプリの PID となるようにする。

#### Solution 2: Enable process namespace sharing in Kubernetes

Pod (複数コンテナを含むことが出来る) 内のプロセスネームスペースを一つにする [process namespace sharing](https://kubernetes.io/docs/tasks/configure-pod-container/share-process-namespace/) を有効にすると Kubernetes Pod infrastructure container が PID 1 となり、親のいなくなったプロセスを引き取る。

#### Solution 3: Use a specialized init system

通常の Linux サーバーの PID 1 のような処理をするプログラムを使うことで回避することも可能だが、systemd はコンテナ向けとしては高機能で複雑すぎるため [tini](https://github.com/krallin/tini) などがおすすめ。Docker では --init オプションを指定することで tini を使った docker-init プロセスが PID 1 となる。docker-compose.yml でも [init](https://docs.docker.com/compose/compose-file/#init) という設定項目がある。

### Optimize for the Docker build cache

重要度: 高

Docker の [build cache](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#leverage-build-cache) の仕組みをきちんと理解して有効活用するべし。誤って使うと古いキャッシュを使い続けることになってしまうため要注意。

### Remove unnecessary tools

重要度: 中

攻撃対象となる不要なツールをインストールしないようにする。例えば Reverse Shell として使われることの多い [netcat](http://netcat.sourceforge.net/) をインストールしないなど。これはコンテナに限った話ではないが、コンテナの方が容易である。これを十分に推進するとデバッグツールの類も入れられなくなるため、ログの管理やトレーシング、プロファイリングのシステムが必然的に必要になってくる。

コンテナ内のファイルは可能な限り少なくする。スタティックにリンクしたバイナリだけであれば [scratch image](https://hub.docker.com/_/scratch/) を使うことも出来る。

イメージにツールがインストールされていないだけでは不十分であり、インストールもできないようにする必要があるため root でアプリを実行しないようにします。docker run の --read-only フラグで書き込みを禁止することが可能。Kubernetes の場合は readOnlyRootFilesystem オプションが使え、[PodSecurityPolicy](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#volumes-and-file-systems) で強制することも可能である。

### Build the smallest image possible

重要度: 中

小さなイメージファイルはアップロードもダウンロードも早く終わるので起動も速くなる。小さなベースイメージを使おう。スタティックリンクされたバイナリなら scratch から作るのも簡単だが、そうではないことが多い。[distroless](https://github.com/GoogleContainerTools/distroless) は言語別にランタイムで必要なものだけを含んだイメージを提供している。shell とかパケージマネージャーなどは入っていない。不要なファイルを別レイヤーで削除してもイメージサイズは小さくならないため、一つの RUN コマンドに削除まで全部含めるのが良いが、Docker 17.05 で追加された Multi-staged builds を使うと良い。同じ node で実行するコンテナであればベースイメージを共通化することでレイヤーのキャッシュが有効に使える。

### Use vulnerability scanning in Container Registry

重要度: 中

コンテナレジストリの持つ脆弱性スキャナを使うと便利です。Cloud Pub/Sub 経由で patch の適用された新しいイメージの作成を自動化することも出来る。([Getting vulnerabilities and metadata for images](https://cloud.google.com/container-registry/docs/get-image-vulnerabilities))

### Properly tag your images

重要度: 中

コンテナイメージには適切な Tag をつけるべき、[Semantic Versioning](https://semver.org/) か Git の commit hash を使うなど。

### Carefully consider whether to use a public image

重要度: N/A

公開されているイメージを使わない場合、ベースイメージのビルドの自動化や、それを使ったイメージのビルドの自動化まで考えておくべき。[Cloud Build](https://cloud.google.com/cloud-build/docs/) の [Build triggers](https://cloud.google.com/cloud-build/docs/running-builds/automate-builds) はこれを助ける手段となるし、Google はメジャーなディストリビューションの [base image](https://github.com/GoogleContainerTools/base-images-docker) も提供している。[container-diff](https://github.com/GoogleCloudPlatform/container-diff) はコンテナイメージ間の差分を確認できる。[container-structure-test](https://github.com/GoogleContainerTools/container-structure-test) は ServerSpec 的な感じでイメージのテストが行える。[Grafeas](https://grafeas.io/) は metadata の API で保存したイメージの metadata を後からチェックすることができる。Kubernetes の場合はデプロイ前に必須条件を確認する [admission controllers](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#validatingadmissionwebhook) もあるし、[pod security policies](https://kubernetes.io/docs/concepts/policy/pod-security-policy/) でセキュリティオプションを強制することが可能。

サードパーティ製ライブラリやパッケージを含める場合にはライセンスにも注意すること。

チュートリアルはまだまだ続く... 次もベストプラクティス (Best Practices for Operating Containers) って書いてあるんだよなあ