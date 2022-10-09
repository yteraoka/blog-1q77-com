---
title: 'Vitess で WordPress を動かしてみる'
date: Sun, 16 Feb 2020 14:37:56 +0000
draft: false
tags: ['MySQL', 'WordPress', 'vitess', 'vitess']
---

最近、目にすることの増えた [Vitess](https://vitess.io/) ですが、[Tutorial](https://vitess.io/docs/get-started/kubernetes/) を試してみてもなかなか分かった気になれません。Sharding するとそれによる制限は受けそうだなというのと、実際にクエリを投げてみて `SELECT *` すると ORDER BY が使えない（SELECT で列を明示する必要がある）とか Sharding の key とした列を WHERE で指定するとちゃんとそれを持ってる tablet にだけ投げてくれる IN で複数指定してもその tablet のものだけにして投げてくれるとか、tablet を跨ぐ JOIN をすると Nested Loop がだいぶ辛そうだなというのは分かったけど。動かしたいアプリで必要なクエリに vtgate が対応しているのかは実際に動かしてみるしかありません。

ところで手元に動かしたいアプリがありません...

私の思いつく最近の OSS では PostgreSQL を採用しているものが多く、WordPress を動かしてみることにしました。（コード読むの辛そうだからもっとシンプルなのが良かったけど）

まずは Sharding なしで動くかどうかを確認。

minikube で Kubernetes 環境を用意
---------------------------

ここでのポイントは vitess の helm chart がまだ Kuberntes 1.16 以降に対応していないため 1.15 を指定している点。

```bash
$ minikube start \
    --kubernetes-version=1.15.7 \
    --cpus=4 \
    --memory=6g
```

minikube の version は 1.7.1 でした。

```bash
$ minikube version
minikube version: v1.7.1
commit: 7de0325eedac0fbe3aabacfcc43a63eb5d029fda
```

helm の準備
--------

helm 2系です。3 系にはまだ未対応のようです。

```bash
$ kubectl -n kube-system create serviceaccount tiller
$ kubectl create clusterrolebinding tiller \
    --clusterrole cluster-admin --serviceaccount=kube-system:tiller
$ helm init --service-account tiller --wait
```

tiller のセットアップには minikube の addon を使うという手もあります。

etcd-operator の deploy
----------------------

ZooKeeper と Consul にも対応しているようですが、今のデフォルトは etcd みたいです。helm もそれ前提です。

```bash
$ git clone https://github.com/coreos/etcd-operator.git
$ cd etcd-operator
$ ./example/rbac/create_role.sh
$ kubectl create -f example/deployment.yaml
```

Persistent Volume の作成
---------------------

Vitess の tablet で使われる MySQL がデータを置く場所と WordPress 用が必要です。MySQL 用は今回の記事の範囲では Master, Replica, Backup 用の3つ、WordPress 用に1つ。

```bash
for i in $(seq 4); do
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

これで pv0001 から pv0004 まで作成されます。

```bash
$ kubectl get pv
NAME     CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   REASON   AGE
pv0001   10Gi       RWO            Recycle          Available           standard                7s
pv0002   10Gi       RWO            Recycle          Available           standard                7s
pv0003   10Gi       RWO            Recycle          Available           standard                7s
pv0004   10Gi       RWO            Recycle          Available           standard                7s
pv0005   10Gi       RWO            Recycle          Available           standard                7s
```

Persistent Volume の Permission 設定
---------------------------------

もっと良い方法が会ったら知りたいのだけれど、tablet の init container が mkdir するところで権限がなくてコケてしまうので、minikube サーバー上の Persistent Volume 用ディレクトリの owner を変更する。

Persistent Volume Claim を受けて、割り当てる時に owner が root のディレクトリが作成されるのだけれど先に作っておく。MySQL の実行ユーザーの uid が 1000 だったのでディレクトリの owner を 1000 にしておく。

```bash
minikube ssh 'for i in $(seq 5); do
  pvname=$(printf pv%04d $i)
  sudo install -o 1000 -m 0755 -d /mnt/vda1/data/${pvname}
done'
```

WordPress の方は 1000 じゃなくても良いのだけれどどれが割り当てられるかわからないし、1000 でも問題なさそうなので全部 1000 にしておく。

ちなみに minikube じゃなくて EKS とか GKE であればこの作業は不要。

vtgate 用パスワードのための Secrets 登録
----------------------------

MySQL クライアントが接続する先は Vitess の vtgate というサーバーで、認証もここで行われます。helm での deploy 時に使われるので Secrets にパスワードを登録する。

```bash
$ cat > wordpress-password-secret.yml << _EOF_
apiVersion: v1
kind: Secret
metadata:
  name: wordpress-password
type: Opaque
data:
  password: aG9nZWhvZ2U=
_EOF_
$ kubectl apply -f wordpress-password-secret.yml
```

`aG9nZWhvZ2U=` は `hogehoge` の base64 です。`echo -n hogehoge | base64`

Vitess の deploy
---------------

Vitess の [tutorial](https://vitess.io/docs/get-started/kubernetes/) でも使われている [helm chart](https://github.com/vitessio/vitess/tree/master/helm/vitess) を使います。

helm chart は Vitess の [git repository](https://github.com/vitessio/vitess) に入っているので　clone します。

```bash
$ git clone https://github.com/vitessio/vitess.git
$ cd vitess/example/helm
```

この `example/helm` ディレクトリには tutorial で使う helm の　variables ファイルが置かれています。ここにある `101_initial_cluster.yaml` をコピーしてちょっといじって使います。`vitess-wordpress-init.yaml` というファイル名とします。

```yaml
# vitess-wordpress-init.yaml
topology:
  cells:
    - name: "zone1"
      etcd:
        replicas: 1
      vtctld:
        replicas: 1
      vtgate:
        replicas: 1
      mysqlProtocol:
        enabled: true
        authType: "secret"
        username: wpapp
        passwordSecret: wordpress-password
      keyspaces:
        - name: "wordpress"
          shards:
            - name: "0"
              tablets:
                - type: "replica"
                  vttablet:
                    replicas: 2
                - type: "rdonly"
                  vttablet:
                    replicas: 1

etcd:
  replicas: 1
  resources:

vtctld:
  serviceType: "NodePort"
  resources:

vtgate:
  serviceType: "NodePort"
  resources:

vttablet:
  mysqlSize: "prod"
  resources:
  mysqlResources:

vtworker:
  resources:

pmm:
  enabled: false

orchestrator:
  enabled: false
```

table 作成は WordPress アプリに任せるので keyspaces 内の schema, vschema は削除しました。keyspace (database) 名は commerce から wordpress に変更しました。vtgate の認証を有効にするため mysqlProtocol の authType を "secret" にし、username, passwordSecret を追加しました。passwordSecret は先に作成した Kubernets の Secrets の名前です。

helm install コマンドで deploy します。

```bash
$ helm install ../../helm/vitess -f vitess-wordpress-init.yaml
```

これで、wordpress という keyspace (database) が作成され、master と semi-synchronous な replica 1つと async な repolica (rdonly) 1つのクラスタが作成されます。

しばらく、待っていると次のような状態になります。

```bash
$ kubectl get pods,jobs
NAME                                            READY   STATUS    RESTARTS   AGE
pod/etcd-global-7lhmznmvld                      1/1     Running   0          2m21s
pod/etcd-operator-866875d5dc-8btrw              1/1     Running   0          18m
pod/etcd-zone1-vcjkdtkrdv                       1/1     Running   0          2m21s
pod/vtctld-8547867c9c-jrmw9                     1/1     Running   3          2m21s
pod/vtgate-zone1-774b6c87d5-96ngl               1/1     Running   3          2m21s
pod/zone1-wordpress-0-init-shard-master-jl7c5   1/1     Running   0          2m21s
pod/zone1-wordpress-0-rdonly-0                  4/6     Running   0          2m21s
pod/zone1-wordpress-0-replica-0                 4/6     Running   0          2m21s
pod/zone1-wordpress-0-replica-1                 4/6     Running   0          2m21s

NAME                                            COMPLETIONS   DURATION   AGE
job.batch/zone1-wordpress-0-init-shard-master   0/1           2m21s      2m21ss
```

`zone1-wordpress-0-replica` という statefulset が master と semi-synchronous な replica です。`{cell}-{keyspace}-{shard}-replica` という命名規則となっています。

サービスはこうです。WordPress からの接続先は `vtgate-zone1:3306` です。

```bash
$ kubectl get svc
NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                                          AGE
etcd-global          ClusterIP   None            2379/TCP,2380/TCP                                3m23s
etcd-global-client   ClusterIP   10.99.214.68    2379/TCP                                         3m23s
etcd-zone1           ClusterIP   None            2379/TCP,2380/TCP                                3m23s
etcd-zone1-client    ClusterIP   10.96.178.199   2379/TCP                                         3m23s
kubernetes           ClusterIP   10.96.0.1       443/TCP                                          21m
vtctld               NodePort    10.103.67.88    15000:31292/TCP,15999:32327/TCP                  3m23s
vtgate-zone1         NodePort    10.104.197.56   15001:31352/TCP,15991:32133/TCP,3306:32651/TCP   3m23s
vttablet             ClusterIP   None            15002/TCP,16002/TCP                              3m23s 
```

minikube の外からアクセスするには nodeport を確認する必要があります。minikube には service list というコマンドがあります。

```bash
$ minikube service list
|-------------|--------------------|--------------------------------|-----|
|  NAMESPACE  |        NAME        |          TARGET PORT           | URL |
|-------------|--------------------|--------------------------------|-----|
| default     | etcd-global        | No node port                   |
| default     | etcd-global-client | No node port                   |
| default     | etcd-zone1         | No node port                   |
| default     | etcd-zone1-client  | No node port                   |
| default     | kubernetes         | No node port                   |
| default     | vtctld             | http://192.168.64.11:31292     |
|             |                    | http://192.168.64.11:32327     |
| default     | vtgate-zone1       | http://192.168.64.11:31352     |
|             |                    | http://192.168.64.11:32133     |
|             |                    | http://192.168.64.11:32651     |
| default     | vttablet           | No node port                   |
| kube-system | kube-dns           | No node port                   |
| kube-system | tiller-deploy      | No node port                   |
|-------------|--------------------|--------------------------------|-----|
```

が、protocl が不明です。全部 http:// となっていますが、嘘です・・・  
次の様にしてアクセスすることが出来ます。

```bash
host=$(minikube ip)
port=$(kubectl describe service vtgate-zone1 | grep NodePort | grep mysql | awk '{print $3}' | awk -F'/' '{print $1}')
mysql -h $host -P $port -u wpapp -phogehoge wordpress
```

ほぼ、普通の MySQL サーバーの様にアクセスできます。

```
mysql> select version();
+---------------+
| version()     |
+---------------+
| 5.7.26-29-log |
+---------------+
1 row in set (0.01 sec)

mysql> show databases;
+-----------+
| Databases |
+-----------+
| wordpress |
+-----------+
1 row in set (0.01 sec)

mysql> 
```

WordPress を deploy する
---------------------

DB の準備ができたので次は WordPress を deploy します。Kubernetes のサイトに [Example: Deploying WordPress and MySQL with Persistent Volumes](https://kubernetes.io/docs/tutorials/stateful-application/mysql-wordpress-persistent-volume/) という StatefulSet として WordPress を deploy する例があったので、ここの [wordpress-deployment.yaml](https://kubernetes.io/examples/application/wordpress/wordpress-deployment.yaml) を参考にします。

```yaml
# wordpress-deployment.yaml
---
apiVersion: v1
kind: Service
metadata:
  name: wordpress
  labels:
    app: wordpress
spec:
  ports:
    - port: 80
  selector:
    app: wordpress
    tier: frontend
  type: NodePort
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wp-pv-claim
  labels:
    app: wordpress
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1 # for versions before 1.9.0 use apps/v1beta2
kind: Deployment
metadata:
  name: wordpress
  labels:
    app: wordpress
spec:
  selector:
    matchLabels:
      app: wordpress
      tier: frontend
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: wordpress
        tier: frontend
    spec:
      containers:
      - image: wordpress:5.3.2-php7.2-apache
        name: wordpress
        env:
        - name: WORDPRESS_DB_HOST
          value: vtgate-zone1
        - name: WORDPRESS_DB_USER
          value: wpapp
        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: wordpress-password
              key: password
        ports:
        - containerPort: 80
          name: wordpress
        volumeMounts:
        - name: wordpress-persistent-storage
          mountPath: /var/www/html
      volumes:
      - name: wordpress-persistent-storage
        persistentVolumeClaim:
          claimName: wp-pv-claim
```

image を [Docker Hub](https://hub.docker.com/_/wordpress/?tab=description) の最新のものにしました。環境変数の `WORDPRESS_DB_HOST`, `WORDPRESS_DB_USER` を Vitess 側で設定したものにしました。`WORDPRESS_DB_PASSWORD` は Secrets を参照していますが、これも Vitess 側で使ったものを指定しました。PersistentVolumeClaim はサイズが 20Gi になっていましたが、事前に作成していた PV のサイズを超えているので 10Gi に変更しました。Service の type を LoadBalancer から NodePort に変更しました。

deploy します。

```bash
$ kubectl apply -f wordpress-deployment.yaml
```

これで起動を待って `minikube service wordpress` とすると NodePort の URL をブラウザで開いてくれます。

```bash
$ minikube service wordpress 
|-----------|-----------|-------------|----------------------------|
| NAMESPACE |   NAME    | TARGET PORT |            URL             |
|-----------|-----------|-------------|----------------------------|
| default   | wordpress |             | http://192.168.64.11:30803 |
|-----------|-----------|-------------|----------------------------|
🎉  Opening service default/wordpress in default browser...
```

無事起動しました。

が、言語選択して、ブログのタイトルやユーザー名、パスワードを入力して先に進むと「成功しました！」という表示と共に見慣れないエラーが...

{{< figure src="wordpress-database-error.png" alt="Database Error Screenshot" >}}

\[vtgate: http://vtgate-zone1-774b6c87d5-96ngl:15001/: target: wordpress.0.master, used tablet: zone1-1372366900 (zone1-wordpress-0-replica-0.vttablet): vttablet: rpc error: code = Unimplemented desc = unsupported: cannot identify primary key of statement (CallerID: wpapp)\]

```
rpc error:
code = Unimplemented
desc = unsupported: cannot identify primary key of statement
```

Primary key が見つけられないってことか？エラーになったのは次の2つの SQL。見慣れないクエリだ。

```sql
DELETE a, b
  FROM wp_options a, wp_options b
 WHERE a.option_name LIKE '\\_transient\\_%'
   AND a.option_name NOT LIKE '\\_transient\\_timeout\\_%'
   AND b.option_name = CONCAT( '_transient_timeout_', SUBSTRING( a.option_name, 12 ) )
   AND b.option_value < 1581760340

```

```sql
DELETE a, b
  FROM wp_options a, wp_options b
 WHERE a.option_name LIKE '\\_site\\_transient\\_%'
   AND a.option_name NOT LIKE '\\_site\\_transient\\_timeout\\_%'
   AND b.option_name = CONCAT( '_site_transient_timeout_', SUBSTRING( a.option_name, 17 ) )
   AND b.option_value < 1581760340
```

この SQL を投げているのは [delete\_expired\_transients()](https://developer.wordpress.org/reference/functions/delete_expired_transients/) でしたが、MySQL に直接投げてみてもマッチするレコードは存在しないのでとりあえず無視して先に進みます。

次は Dashboard の表示です。

{{< figure src="wordpress-dashboard.png" alt="Wordpress Dashboard" >}}

画面上にエラーは表示されませんでしたが、apache の error\_log に沢山エラーが出てました。

1行目の `PHP Warning: mysqli_query(): Error reading result set's header in /var/www/html/wp-includes/wp-db.php on line 2030` が後続のエラーを引き起こしてるのかな？[wp-includes/wp-db.php の 2030行目](https://github.com/WordPress/WordPress/blob/5.3.2/wp-includes/wp-db.php#L2030) という情報からでは追いかけるのが厳しいのでまたの機会に調べてみようかな。

### 追記

vttablet のログに次のものがありました。

```
tabletserver.go:1643] Incorrect string value: '\xF0\x9F\x99\x82" ...' for column 'option_value' at row 1 (errno 1366) (sqlstate HY000) (CallerID: wpapp): Sql: "insert into wp_options(option_name,...
```

「Incorrect string value: 🙂" ...」character set が utf8mb4 になってない問題か？でも、この文字自体は MySQL に直接 INSERT することは可能だな。

余談ですが Apache のエラーログはセキュリティのために printable な ASCII 意外はエスケープして `\x` と16進のコードで出力されてしまいます。元はなんだったのかな？ってこれを変換するスクリプトでも書こうかと思ったのですが、これ、zsh なら echo に渡すだけで良かったんですね！！ (追記: bash でも `echo -e` で同じことができました)

```
$ echo 'WordPress \xe3\x83\x87\xe3\x83\xbc\xe3\x82\xbf\xe3\x83\x99\xe3\x83\xbc\xe3\x82\xb9\xe3\x82\xa8\xe3\x83\xa9\xe3\x83\xbc'
WordPress データベースエラー
```

で、さっきのエラーログも warning と notice だし、致命的ではなかったので先に進んで記事を投稿してみます。

{{< figure src="wordpress-post.png" alt="Wordpress Post" >}}

無事投稿して表示も確認できました。WordPress を動かすのは難しいかな？なんて思ってたんですが意外にも動きましたね。

そうそう、管理画面のメディアページでもエラーが出ました。

```sql
SELECT SQL_CALC_FOUND_ROWS  wp_posts.ID
  FROM wp_posts
 WHERE 1=1
   AND wp_posts.post_type = 'attachment'
   AND ((wp_posts.post_status = 'inherit' OR wp_posts.post_status = 'private'))
 ORDER BY wp_posts.post_date DESC
 LIMIT 0
```

という SQL で syntax error となりました。`SQL_CALC_FOUND_ROWS` に対応していないようです。それはそうと数を数えるだけなのになんで ORDER BY なんかついてるのかな。

MySQL との互換性の情報は [MySQL Compatibility](https://vitess.io/docs/reference/mysql-compatibility/) にありました。

おまけ
---

### MySQL に直接接続する方法

複数コンテナが入っているので -c で mysql コンテナを指定します。

```
$ kubectl exec -itc mysql zone1-wordpress-0-replica-0 -- mysql --socket=/vtdataroot/tabletdata/mysql.sock -u root
```

### MySQL 側でのクエリ確認

Vitess の helm で deploy される Pod はファイルに出力される error.log, slow-query.log, general.log をそれぞれ `tail -F` して stdout に流すコンテナがいる（rotation させるのも別途いる）んですが、general.log は MySQL 側で設定されてないため、起動後に MySQL にアクセスして設定してやる必要があります。

上の方法で MySQL にアクセスしたら次の設定をします。

```
set global general_log_file = '/vtdataroot/tabletdata/general.log';
set global general_log = on;
```

まとめ
---

Tutorial 試しても楽しくなかったので WordPress を動かしてみました。意外と動きましたね、でもやっぱり vtgate でサポートされてないクエリも使われてますね。ここから Sharding とか Backup や障害復旧などを試していこうかなと。vtctlclient コマンドの使い方とか VReplication とか Topology Service とかまだ全然わからない。
