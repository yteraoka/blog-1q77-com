---
title: 'Presslabs の mysql-operator (part1)'
date: Sat, 29 Feb 2020 16:51:43 +0000
draft: false
tags: ['Kubernetes', 'MySQL']
---

[Vitess](https://vitess.io/) の [helm](https://github.com/vitessio/vitess/tree/master/helm/vitess) の完成後がまだまだっぽくて Issue を上げたりもしてるけど Shard 不要な要件なら他の選択肢も持っておくべきだろうなということで探してみると mysql-operator が Oracle からと [Presslabs](https://www.presslabs.com/) から公開されていた。Oracle の方は開発が停滞しているっぽいので除外。Presslabs は WordPress のホスティング業者で [wordpress-operator](https://github.com/presslabs/wordpress-operator) も公開されている。利用者のサイト単位で wordpress と mysql がデプロイされるっぽい。

デプロイ方法は [Getting started with MySQL operator](https://www.presslabs.com/docs/mysql-operator/) にあります。

とりあえず動かすだけなら helm で mysql-operator をインストールして

```
helm repo add presslabs https://presslabs.github.io/charts
helm install presslabs/mysql-operator --name mysql-operator
```

ユーザー、パスワード用の Secrets ([example-cluster-secret.yaml](https://github.com/presslabs/mysql-operator/blob/master/examples/example-cluster-secret.yaml)) を登録後に `kind: MysqlCluster` を apply するだけです。

```
kubectl apply -f https://raw.githubusercontent.com/presslabs/mysql-operator/master/examples/example-cluster-secret.yaml
kubectl apply -f https://raw.githubusercontent.com/presslabs/mysql-operator/master/examples/example-cluster.yaml
```

[example-cluster.yaml](https://github.com/presslabs/mysql-operator/blob/master/examples/example-cluster.yaml) はコメントを除くとこれだけです。コメントを見るといろいろ調整できそうなことがわかります。

```yaml
apiVersion: mysql.presslabs.org/v1alpha1
kind: MysqlCluster
metadata:
  name: my-cluster
spec:
  replicas: 2
  secretName: my-secret
```

Minikube への deploy
------------------

### Minikube の起動

パラメータは適当に。

```bash
minikube start \
  --kubernetes-version=v1.15.7 \
  --cpus=4 \
  --memory=8gb \
  --disk-size=20gb \
  --vm-driver=hyperkit
```

### helm の install

[helm 3 にも対応している](https://github.com/presslabs/mysql-operator/blob/master/charts/mysql-operator/README.md)ようですが、ここでは都合により helm 2 を使っています。

helm バイナリのダウンロードは [GitHub](https://github.com/helm/helm/releases) などから。

```bash
kubectl -n kube-system get serviceaccount tiller > /dev/null 2>&1 \
  || kubectl -n kube-system create serviceaccount tiller
kubectl get clusterrolebindings tiller > /dev/null 2>&1 \
  || kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
helm list > /dev/null 2>&1 || helm init --service-account tiller --wait
```

### PersistentVolume の作成

MySQL の Data ディレクトリにも使えますが、mysql-operator 内の orchestrator が SQLite のファイルを保存する先として使います。

```bash
for i in $(seq 5); do
  pvname=$(printf pv%04d $i)
  echo -e "---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${pvname}
spec:
  accessModes:
    - ReadWriteOnce
  capacity:
    storage: 10Gi
  hostPath:
    path: /data/${pvname}/
  storageClassName: standard
  persistentVolumeReclaimPolicy: Recycle"
done | kubectl apply -f -
```

```bash
minikube ssh 'for i in $(seq 5); do
  pvname=$(printf pv%04d $i)
  sudo install -m 0777 -d /mnt/vda1/data/${pvname}
done'
```

### mysql-operator の deploy

ここでは minikube なので orchestrator の Web UI へのアクセスに NodePort を使うように mysql-operator の deploy 時にちょっとカスタマイズしてみます。次の内容の `mysql-operator-values.yaml` というファイルを用意して

```yaml
orchestrator:
  service:
    type: NodePort
    port: 80
  config:
    Debug: true
    RecoveryPeriodBlockSeconds: 60
```

次のコマンドで deploy します。

```
helm repo add presslabs https://presslabs.github.io/charts
helm install presslabs/mysql-operator --name mysql-operator -f mysql-operator-values.yaml
```

これで mysqlbackups.mysql.presslabs.org と mysqlclusters.mysql.presslabs.org という2つの Custom Resource Definitions (CRD) が作成されています。また、mysql-operator と orchestrator を含む StatefulSets が deploy されています。

### MySQL クラスタの depeloy

最初に書いたように kubectl apply でも deploy 可能ですが、 mysql-operator を使って MySQL クラスタを deploy するための [mysql-cluster chart](https://github.com/presslabs/mysql-operator/tree/master/charts/mysql-cluster) もあるのでこれを使います。

次の内容で `mysql-cluster-values.yaml` というファイルを作成します。（ファイル名は何でも良いですが）

```yaml
# MySQL 3つのクラスタ
replicas: 3

rootPassword: "mypass"

# また懲りずに wordpress を動かしてみようと思うので
appUser: "wpapp"
appPassword: "password"
appDatabase: "wordpress"

# 動作確認だけなので要求するメモリ量をデフォルトより小さくしておく
podSpec:
  resources:
    requests:
      memory: 512M
      cpu:    200m

# S3 へのバックアップ設定、確認のために10分おきに実行
# 最新の5個だけ残す
# (バックアップしないなら全部未定義で良い)
backupSchedule: "0 */10 * * * *"
backupScheduleJobsHistoryLimit: 5
backupURL: s3://YOUR-BUCKET-NAME/
backupRemoteDeletePolicy: delete
backupCredentials:
  AWS_ACCESS_KEY_ID: AKIBAZGQUWZBKTIL5QRB
  AWS_SECRET_ACCESS_KEY: ****************************************
  AWS_REGION: ap-northeast-1
```

```
helm install presslabs/mysql-cluster --name mycluster -f mysql-cluster-values.yaml
```

すると、しばらくして次のような状況になります。

```
$ kubectl get all,secrets,configmaps
NAME                                     READY   STATUS    RESTARTS   AGE
pod/mycluster-mysql-cluster-db-mysql-0   4/4     Running   0          6m4s
pod/mycluster-mysql-cluster-db-mysql-1   4/4     Running   0          4m33s
pod/mycluster-mysql-cluster-db-mysql-2   4/4     Running   0          3m42s
pod/mysql-operator-0                     2/2     Running   0          52m


NAME                                              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE
service/kubernetes                                ClusterIP   10.96.0.1       443/TCP             36h
service/mycluster-mysql-cluster-db-mysql          ClusterIP   10.105.17.16    3306/TCP            6m4s
service/mycluster-mysql-cluster-db-mysql-master   ClusterIP   10.98.186.169   3306/TCP            6m4s
service/mysql                                     ClusterIP   None            3306/TCP,9125/TCP   6m4s
service/mysql-operator                            NodePort    10.108.47.3     80:32328/TCP        52m
service/mysql-operator-0-svc                      ClusterIP   10.102.82.83    80/TCP,10008/TCP    52m




NAME                                                READY   AGE
statefulset.apps/mycluster-mysql-cluster-db-mysql   3/3     6m4s
statefulset.apps/mysql-operator                     1/1     52m




NAME                                               TYPE                                  DATA   AGE
secret/default-token-92lnd                         kubernetes.io/service-account-token   3      36h
secret/mycluster-mysql-cluster-db                  Opaque                                5      6m4s
secret/mycluster-mysql-cluster-db-backup           Opaque                                3      6m4s
secret/mycluster-mysql-cluster-db-mysql-operated   Opaque                                10     6m4s
secret/mysql-operator-orc                          Opaque                                2      52m
secret/mysql-operator-token-h82jw                  kubernetes.io/service-account-token   3      52m

NAME                                         DATA   AGE
configmap/mycluster-mysql-cluster-db-mysql   1      6m4s
configmap/mysql-operator-leader-election     0      52m
configmap/mysql-operator-orc                 2      52m 
```

### Database 確認

`service/mycluster-mysql-cluster-db-mysql-master` の 3306/tcp にアクセスすれば Master の MySQL に接続することができます。`-master` suffix がつかない方の Service は Master も含んだ healthy=yes の Pod の集合です。

```bash
kubectl run mysql-client --rm --restart=Never \
  --image=mysql:5.7 -it --generator=run-pod/v1 --command -- \
  mysql -h mycluster-mysql-cluster-db-mysql-master -u root -pmypass
```

指定した wordpress というデータベースの他に sys\_operator というデータベースが存在します。

```
mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
| sys                |
| sys_operator       |
| wordpress          |
+--------------------+
6 rows in set (0.00 sec)
```

この sys\_operator は mysql-operator の中で監視やら起動確認に使われています。

```
mysql> show tables;
+------------------------+
| Tables_in_sys_operator |
+------------------------+
| heartbeat              |
| status                 |
+------------------------+
2 rows in set (0.00 sec)
```

### Orchestrator の Web UI を確認する

mysql-operator はクラスタの topology 管理に [Orchestrator](https://github.com/openark/orchestrator) を採用しています。Orchestrator については "[「MySQL High Availability tools」のフォローアップとorchestratorの追加](https://yakst.com/ja/posts/4693)" かその[原文](http://code.openark.org/blog/mysql/mysql-high-availability-tools-followup-the-missing-piece-orchestrator)(作者著)が詳しいです。

これには Web UI がついているので次のコマンドでアクセスしてみます。これでアクセス出来るように operator の deploy 時に NodePort に変更しました。

```
minikube service mysql-operator
```

Orchestrator の Dashboard にはクラスタの一覧が表示されます。mysql-operator で deploy されるクラスタは一組の orchestrator で管理されるのでここに追加されていきます。

{{< figure src="orchestrator-dashboard.png" >}}

クラスタを選択すると replication の topology が見えます。これは 3 node クラスタの例。

{{< figure src="orchestrator-mycluster.png" >}}

mysql-operator の [helm chart](https://github.com/presslabs/mysql-operator/tree/master/charts/mysql-operator) は replica 数がデフォルトで1ですが、orchestrator は Raft でクラスタが組めるようになっているため冗長構成にもできそうです。

先ほどの sys\_operator.heartbeat テーブルは orchestrator の SlaveLagQuery という設定から参照されています。

### 続く

長くなったので failover とか backup とかは別記事にしよう。

[続き](/2020/03/presslabs-mysql-operator-part2/)

### おまけ

Vitess は [PlanetScale](https://www.planetscale.com/) の [vitess-operator](https://github.com/planetscale/vitess-operator) の方が出来が良さそうです。こちらは彼らが Vitess をサービスとして提供しておりそこで使われているものをベースに彼らの infra に依存する部分を無くして公開しているようです。まだ PRE-RELEASE 状態だということですが。
