---
title: 'Kubernetes Secrets を使って minikube に netbox を deploy してみる'
date: Wed, 22 Feb 2017 15:59:40 +0000
draft: false
tags: ['Docker', 'Kubernetes', 'minikube', 'netbox']
---

[Kubernetes](https://kubernetes.io/) お試し中です。[Rancher](http://rancher.com/) で構築するべきか悩み中。
今回は YAML を書いて [Deployment](https://kubernetes.io/docs/user-guide/deployments/), [Service](https://kubernetes.io/docs/user-guide/services/) を作成して Kubernetes 上に [netbox](https://github.com/digitalocean/netbox) を構築してみます。(netbox は Django + PostgreSQL のデータセンターファシリティ管理ツールです、Wordpress のセットアップは飽きた) パスワードなどは Kubernetes [Secrets](https://kubernetes.io/docs/user-guide/secrets/) を使います。 minikube の起動は

```
$ minikube start
```

たったこれだけ。詳細は[以前の投稿](/2017/01/minikube-part2/)で。

### 構成図

こんな構成にしてみます

{{< figure src="kubernetes-netbox.png" alt="deploy-netbox-on-minikube" caption="kubernetes-netbox 構成図" >}}

### Version

minikube の version は 0.16.0

```
$ minikube version
minikube version: v0.16.0
```

Kubernetes の version は

```
$ kubectl version
Client Version: version.Info{Major:"1", Minor:"5", GitVersion:"v1.5.1", GitCommit:"82450d03cb057bab0950214ef122b67c83fb11df", GitTreeState:"clean", BuildDate:"2016-12-14T00:57:05Z", GoVersion:"go1.7.4", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"5", GitVersion:"v1.5.2", GitCommit:"08e099554f3c31f6e6f07b448ab3ed78d0520507", GitTreeState:"clean", BuildDate:"1970-01-01T00:00:00Z", GoVersion:"go1.7.1", Compiler:"gc", Platform:"linux/amd64"}
```

kubectl 更新しなきゃ

### Secret を作成

[https://kubernetes.io/docs/user-guide/secrets/](https://kubernetes.io/docs/user-guide/secrets/) 実際に試した時にはまずは Secrets なしでやったので順序が違いますが、Secrets を使うとなったらまずはこれを作るところから。
秘密なのでコマンドラインの履歴に残らないように `--from-file` を使いました。
YAML や JSON からでも作れますが、値を Base64 に encode する手間が必要です。直接文字列を渡すには `--from-literal=username=testuser` という指定を使います。

```
$ kubectl create secret generic netbox-secret \
  --from-file=secret_key=secrets/secret_key.txt \
  --from-file=email_address=secrets/email_address.txt \
  --from-file=email_password=secrets/email_password.txt \
  --from-file=netbox_password=secrets/netbox_password.txt \
  --from-file=db_password=secrets/db_password.txt \
  --from-file=superuser_password=secrets/superuser_password.txt
secret "netbox-secret" created
```

ファイルで渡す場合は末尾の改行も含まれてしまうため、改行が入らないようの `echo -n` などで作ります。
あれ？ echo コマンドが履歴に・・・

```
$ echo -n 'string' > secret.txt
```

**netbox-secret** という名前の secret ができているので確認してみます。

```
$ kubectl get secrets netbox-secret
NAME            TYPE      DATA      AGE
netbox-secret   Opaque    6         52s
```

```
$ kubectl describe secrets netbox-secret
Name:		netbox-secret
Namespace:	default
Labels:		<none>
Annotations:	<none>

Type:	Opaque

Data
====
superuser_password:	5 bytes
db_password:		16 bytes
email_address:		27 bytes
email_password:		16 bytes
netbox_password:	5 bytes
secret_key:		49 bytes
```

ひとつの secret に複数の key / value のセットを登録されていることが確認できます。

これを volume としてマウントてファイルのようにしてアクセスしたり、環境変数として渡すことができます。今回は環境変数として設定します。
[Docker 1.13 の secret](/2017/02/docker-1-13-secrets/) では一度設定した値を更新できませんでしたが、Kubernetes の場合には更新が可能で、ファイルとしてアクセスする場合には定期的に更新がチェックされ、反映されます。
マウント時にパーミッションも指定できるようなのでコンテナ側から更新できるのかな？試してないけど。

ファイルから登録してファイルとして見せられるので TLS の証明書と秘密鍵とか SSH の private key などを渡すのにも便利に使えそうです。

ドキュメントの [Risks](https://kubernetes.io/docs/user-guide/secrets/#risks) に書かれていることは理解しておいたほうが良いです。Kubernetes で任意のコンテナを起動できる人には Secrets は丸見えだとか、etcd の中には平文で入っているので etcd のファイルにアクセスできてしまうとダメだとか書かれています。

さらに、Kubernetes の Dashboard で値が見れちゃう、ええぇぇっ！
ということは

```
$ kubectl get secret netbox-secret -o yaml
```

とかで YAML や JSON には Base64 の文字列が含まれてるから簡単に値が読めちゃう。API にアクセス出来ちゃう人には丸見えってことだな。

### PostgreSQL Deployment の YAML ファイル作成

近頃の Kubernetes では Pod を直接作るのではなく、Deployment というものを使うみたいですね。
Deployment は template として設定した Pod を何個起動させるかを定義する感じです。

マスタの DB は1個で良いので **replicas: 1** です。

Pod のコンテナもここでは **postgres** の1個だけです。

```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: netbox-db-deployment
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: netbox-db
    spec:
      containers:
        - name: netbox-db
          image: postgres:9.6.2
          env:
            - name: POSTGRES_USER
              value: netbox
            - name: POSTGRES_PASSWORD
              # netbox-secret という secret volume から key で指定した値を環境変数に設定
              valueFrom:
                secretKeyRef:
                  name: netbox-secret
                  key: db_password
            - name: POSTGRES_DB
              value: netbox
          # 5432/tcp を公開
          ports:
            - containerPort: 5432
          volumeMounts:
            # /var/lib/postgresql にデータ用 volume をマウント
            - mountPath: /var/lib/postgresql
              name: netbox-db-data
      restartPolicy: Always
      volumes:
        # データファイル用の volume を定義
        - name: netbox-db-data
          emptyDir: {}
        # netbox-secret という名前の secret を netbox-secret という volume 名で定義
        - name: netbox-secret
          secret:
            secretName: netbox-secret
```

### アプリの Deployment の YAML ファイル作成

こちらの Pod には Reveerse Proxy としての nginx と Django で書かれた netbox アプリの2つのコンテナを入れてあります。

Django 側で持っている制定ファイルを nginx が直接返したいために volume を共有してあります。

また、冗長化、負荷分散として **replicas: 2** として2セット立ち上げるようにしてあります。
**replicas** は起動後にも増減が可能です。

netbox は [docker-entrypoint.sh](https://github.com/digitalocean/netbox/blob/develop/docker/docker-entrypoint.sh) で起動されるようになっています。

netbox の repository には [docker-compose.yml](https://github.com/digitalocean/netbox/blob/develop/docker-compose.yml) が置いてあるのでこれを参考に YAML ファイルを作りました。
Docker イメージは公開されていないようなので作りました。[yteraoka/netbox](https://hub.docker.com/r/yteraoka/netbox/), [yteraoka/netbox-nginx](https://hub.docker.com/r/yteraoka/netbox-nginx/)

環境変数は文字列として定義しないとダメというのになかなか気付けずにしばらくハマってしまいました。

```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: netbox-app-deployment
spec:
  replicas: 2
  template:
    metadata:
      labels:
        app: netbox-app
    spec:
      containers:
        # nginx コンテナ
        - name: netbox-nginx
          image: yteraoka/netbox-nginx:1.11.10
          command:
            - nginx
          # 80/tcp を公開する
          ports:
            - containerPort: 80
          # アプリ側と共有する volume を /opt/netbox/netbox/static にマウントする
          # /static/ はここのファイルを返すように nginx.conf で指定してある
          volumeMounts:
            - mountPath: /opt/netbox/netbox/static
              name: netbox-static-files

        # netbox アプリコンテナ
        - name: netbox-app
          image: yteraoka/netbox:1.8.3
          # 環境変数指定
          env:
            - name: SUPERUSER_NAME
              value: admin
            - name: SUPERUSER_EMAIL
              # netbox-secret volume から key で指定した secret の値を環境変数として指定
              valueFrom:
                secretKeyRef:
                  name: netbox-secret
                  key: email_address
            - name: SUPERUSER_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: netbox-secret
                  key: superuser_password
            - name: ALLOWED_HOSTS
              value: '*'
            - name: DB_NAME
              value: netbox
            - name: DB_USER
              value: netbox
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: netbox-secret
                  key: db_password
            - name: DB_HOST
              value: netbox-db
            - name: SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: netbox-secret
                  key: secret_key
            - name: EMAIL_SERVER
              value: smtp.gmail.com
            - name: EMAIL_PORT
              # ハマりポイント！環境変数は文字列として定義する必要があるので数値はクオートが必要
              value: "587"
            - name: EMAIL_USERNAME
              valueFrom:
                secretKeyRef:
                  name: netbox-secret
                  key: email_address
            - name: EMAIL_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: netbox-secret
                  key: email_password
            - name: EMAIL_TIMEOUT
              value: "10"
            - name: EMAIL_FROM
              valueFrom:
                secretKeyRef:
                  name: netbox-secret
                  key: email_address
            - name: NETBOX_USERNAME
              value: guest
            - name: NETBOX_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: netbox-secret
                  key: netbox_password
          volumeMounts:
            - mountPath: /opt/netbox/netbox/static
              name: netbox-static-files
      restartPolicy: Always
      volumes:
        - name: netbox-static-files
          emptyDir: {}
        # netbox-secret という名前の secret を netbox-secret という volume 名で定義
        - name: netbox-secret
          secret:
            secretName: netbox-secret
```

作った YAML ですぐに Deployment を作成しても良いのですが、後に回して次の Service の定義を作成します

### Service の作成

Deployment だけではコンテナは起動するものの外部からのアクセスはもちろん Pod 間の通信すらできません。
これを可能にするために受け口である Service を作成する必要があります。

PostgreSQL の Service

```yaml
kind: Service
apiVersion: v1
metadata:
  name: netbox-db
spec:
  selector:
    # 紐付ける pod (deployment) を label で指定
    app: netbox-db
  ports:
    - protocol: TCP
      port: 5432
      targetPort: 5432

```

アプリ側の Service

```yaml
kind: Service
apiVersion: v1
metadata:
  name: netbox-app
spec:
  selector:
    # 紐付ける pod (deployment) を label で指定
    app: netbox-app
  ports:
    - protocol: "TCP"
      port: 80
  # minikube なので node の port にマッピングします
  # minikube node の ephemeral port が割り当てられます
  type: NodePort
```

Deployment や Service の YAML は `---` 行を挟むことで複数をひとつのファイルにまとめることができるのでDBとアプリそれぞれを1つのファイルにして **netbox-db-deployment.yaml** **netbox-app-deployment.yaml** というファイルにしました。

### Service, Deployment の作成

Secret を作成し、Service と Deployment の定義ができたのでいよいよデプロイしてみます。

DB の起動

```
$ kubectl create -f netbox-db-deployment.yaml --record
service "netbox-db" created
deployment "netbox-db-deployment" created
```

アプリの起動

```
$ kubectl create -f netbox-app-deployment.yaml --record
service "netbox-app" created
deployment "netbox-app-deployment" created
```

`describe` コマンドで確認してみます

DB の Deployment

```
$ kubectl describe deployment netbox-db
Name:			netbox-db-deployment
Namespace:		default
CreationTimestamp:	Wed, 22 Feb 2017 23:00:03 +0900
Labels:			app=netbox-db
Selector:		app=netbox-db
Replicas:		1 updated | 1 total | 1 available | 0 unavailable
StrategyType:		RollingUpdate
MinReadySeconds:	0
RollingUpdateStrategy:	1 max unavailable, 1 max surge
Conditions:
  Type		Status	Reason
  ----		------	------
  Available 	True	MinimumReplicasAvailable
OldReplicaSets:	 NewReplicaSet:	netbox-db-deployment-3568492614 (1/1 replicas created)
Events:
  FirstSeen	LastSeen	Count	From				SubObjectPath	Type		Reason			Message
  ---------	--------	-----	----				-------------	--------	------			-------
  1m		1m		1	{deployment-controller }			Normal		ScalingReplicaSet	Scaled up replica set netbox-db-deployment-3568492614 to 1 
```

DB の Service

```
$ kubectl describe service netbox-db
Name:			netbox-db
Namespace:		default
Labels:			 Selector:		app=netbox-db
Type:			ClusterIP
IP:			10.0.0.94
Port:			 5432/TCP
Endpoints:		172.17.0.4:5432
Session Affinity:	None
No events. 
```

アプリの Deployment

```
$ kubectl describe deployment netbox-app
Name:			netbox-app-deployment
Namespace:		default
CreationTimestamp:	Wed, 22 Feb 2017 23:00:16 +0900
Labels:			app=netbox-app
Selector:		app=netbox-app
Replicas:		2 updated | 2 total | 2 available | 0 unavailable
StrategyType:		RollingUpdate
MinReadySeconds:	0
RollingUpdateStrategy:	1 max unavailable, 1 max surge
Conditions:
  Type		Status	Reason
  ----		------	------
  Available 	True	MinimumReplicasAvailable
OldReplicaSets:	 NewReplicaSet:	netbox-app-deployment-205279487 (2/2 replicas created)
Events:
  FirstSeen	LastSeen	Count	From				SubObjectPath	Type		Reason			Message
  ---------	--------	-----	----				-------------	--------	------			-------
  59s		59s		1	{deployment-controller }			Normal		ScalingReplicaSet	Scaled up replica set netbox-app-deployment-205279487 to 2 
```

アプリの Service **Endpoints** に2つの登録があるので2つのサーバーにアクセスが割り振られそうです。実際に Pod のログを確認すると2つに割り振られていました。
**NodePort** に **31631** とありますので http://192.168.99.100:31631/ で netbox にアクセスができます。
IPアドレスは **minikube ip** コマンドで確認できます。

```
$ kubectl describe service netbox-app
Name:			netbox-app
Namespace:		default
Labels:			 Selector:		app=netbox-app
Type:			NodePort
IP:			10.0.0.214
Port:			 80/TCP
NodePort:		 31631/TCP
Endpoints:		172.17.0.5:80,172.17.0.6:80
Session Affinity:	None
No events. 
```

前に教えてもらった `minikube service list` の方が便利なのでした

```
$ minikube service list
|-------------|----------------------|-----------------------------|
|  NAMESPACE  |         NAME         |             URL             |
|-------------|----------------------|-----------------------------|
| default     | kubernetes           | No node port                |
| default     | netbox-app           | http://192.168.99.100:31631 |
| default     | netbox-db            | No node port                |
| kube-system | kube-dns             | No node port                |
| kube-system | kubernetes-dashboard | http://192.168.99.100:30000 |
|-------------|----------------------|-----------------------------|
```

Pod の状況

```
$ kubectl get pods
NAME                                    READY     STATUS    RESTARTS   AGE
netbox-app-deployment-205279487-1lx6p   2/2       Running   0          1h
netbox-app-deployment-205279487-r2ksc   2/2       Running   0          1h
netbox-db-deployment-3568492614-qwblg   1/1       Running   0          1h
```

netbox にアクセスしてログインできました！！

{{< figure src="kubernetes-netbox-1.png" alt="Kubernetes Netbox" caption="Kubernetes Netbox Screenshot" >}}

あとは rolling update や healthcheck、実際の network 環境での Service 設定、ログ収集の仕組みとかいろいろあるなあ

### お掃除

作ったものの削除です。minikube をまるっと消すなら `minikube delete` で全部消えます。

Service の削除

```
$ kubectl get services
NAME         CLUSTER-IP   EXTERNAL-IP   PORT(S)        AGE
kubernetes   10.0.0.1     443/TCP        12m
netbox-app   10.0.0.117   80:32678/TCP   6m
netbox-db    10.0.0.140   5432/TCP       6m 
```

```
$ kubectl delete service netbox-app
service "netbox-app" deleted
$ kubectl delete service netbox-db
service "netbox-db" deleted
```

Deployment の削除

```
$ kubectl get deployments
NAME                    DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
netbox-app-deployment   2         2         2            0           6m
netbox-db-deployment    1         1         1            1           6m
```

```
$ kubectl delete deployment netbox-app-deployment
deployment "netbox-app-deployment" deleted
$ kubectl delete deployment netbox-db-deployment
deployment "netbox-db-deployment" deleted
```

これで Pod も削除されますが、完全に消えるまでにはちょっと時間がかかります。

Secret の削除

```
$ kubectl get secrets
NAME                  TYPE                                  DATA      AGE
default-token-8674j   kubernetes.io/service-account-token   3         52m
netbox-secret         Opaque                                6         41m
```

```
$ kubectl delete secrets netbox-secret
secret "netbox-secret" deleted
```
