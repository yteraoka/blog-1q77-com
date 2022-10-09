---
title: 'telepresence 入門 (2)'
date: Sat, 08 Jan 2022 05:27:39 +0000
draft: false
tags: ['Kubernetes', 'Kubernetes', 'telepresence']
---

前回の [telepresence 入門 (1)](/2021/12/telepresence-part-1/) の続きです。今回は Kubernetes クラスタの Service へのアクセスをインターセプトして手元の環境に転送することを試します。Kubernetes 側の volume も手元で mount させるし、環境変数も引っ張ってきます。 バージョンなど環境については前回と同じ。

インターセプト設定
---------

Kubernetes の Service 宛の通信を手元に転送することを　intercept と呼ぶようです。

### インターセプト前の状態

[前回](/2021/12/telepresence-part-1/)使った hello という Service, Deployment を使います。

```
$ kubectl create deploy hello --image=k8s.gcr.io/echoserver:1.4
$ kubectl expose deploy hello --port 80 --target-port 8080
```

Service は port 80 をコンテナの port 8080 に転送するようになっています。

```
$ kubectl get svc hello -o jsonpath={.spec.ports} | jq
[
  {
    "port": 80,
    "protocol": "TCP",
    "targetPort": 8080
  }
]
```

`telepresence intercept` コマンド実行前の状態です。`(traffic-agent not yet installed)` ということで agent がまだインストールされていません。

```
$ telepresence list            
hello: ready to intercept (traffic-agent not yet installed)
```

### インターセプト

`telepresence intercept` コマンドを実行します。`--port` はローカルの転送先 port の指定です。デフォルトが 8080 です。

```
$ telepresence intercept hello --port 8080
Using Deployment hello
intercepted
    Intercept name    : hello
    State             : ACTIVE
    Workload kind     : Deployment
    Destination       : 127.0.0.1:8080
    Volume Mount Point: /var/folders/nd/8mk6834s31g8dymd1_9pnqq00000gn/T/telfs-3519194956
    Intercepting      : all TCP connections
```

これで、手元で port 8080 で Listen するプロセスを実行すれば Kubernetes 内で hello サービスにアクセスするとそこに流れてきます。例えば python で HTTP サーバーを起動させて、Kubernetes の別 Pod から `curl -s http://hello.default/` を実行してみたら次のように 127.0.0.1 からのアクセスが行われました。

```
$ python3 -m http.server 8080
Serving HTTP on :: port 8080 (http://[::]:8080/) ...
::ffff:127.0.0.1 - - [08/Jan/2022 11:01:18] "GET / HTTP/1.1" 200 -
```

手元のプロセスは docker などで実行しても問題ありません。

```
$ docker run -it --rm -p 8080:80 nginx:latest
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
10-listen-on-ipv6-by-default.sh: info: Getting the checksum of /etc/nginx/conf.d/default.conf
10-listen-on-ipv6-by-default.sh: info: Enabled listen on IPv6 in /etc/nginx/conf.d/default.conf
/docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
/docker-entrypoint.sh: Configuration complete; ready for start up
2022/01/08 02:05:31 [notice] 1#1: using the "epoll" event method
2022/01/08 02:05:31 [notice] 1#1: nginx/1.21.5
2022/01/08 02:05:31 [notice] 1#1: built by gcc 10.2.1 20210110 (Debian 10.2.1-6) 
2022/01/08 02:05:31 [notice] 1#1: OS: Linux 5.13.0-23-generic
2022/01/08 02:05:31 [notice] 1#1: getrlimit(RLIMIT_NOFILE): 1048576:1048576
2022/01/08 02:05:31 [notice] 1#1: start worker processes
2022/01/08 02:05:31 [notice] 1#1: start worker process 31
2022/01/08 02:05:31 [notice] 1#1: start worker process 32
2022/01/08 02:05:31 [notice] 1#1: start worker process 33
2022/01/08 02:05:31 [notice] 1#1: start worker process 34
172.17.0.1 - - [08/Jan/2022:02:05:36 +0000] "GET / HTTP/1.1" 200 615 "-" "curl/7.64.0" "-"
```

`telepresence intercept` コマンドの `--docker-run` オプションを使うと intercept の有効化と同時に docker run も実行してくれます。

### 図解

こんな感じっぽいです。`telepresence intercept` を実行すると Service に対応する Deployment などに対して traffic agent コンテナが追加されます(このため　Pod は再作成されます)。また、Service の targetPort が書き換えられます。

{{< figure src="telepresence-before-after.png" alt="telepresence 導入前後比較" >}}

追加されるコンテナ manifest の例

```yaml
spec:
  template:
    spec:
      containers:
      - args:
        - agent
        env:
        - name: TELEPRESENCE_CONTAINER
          value: echoserver
        - name: _TEL_AGENT_LOG_LEVEL
          value: info
        - name: _TEL_AGENT_NAME
          value: hello
        - name: _TEL_AGENT_NAMESPACE
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: metadata.namespace
        - name: _TEL_AGENT_POD_IP
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: status.podIP
        - name: _TEL_AGENT_APP_PORT
          value: "8080"
        - name: _TEL_AGENT_PORT
          value: "9900"
        - name: _TEL_AGENT_MANAGER_HOST
          value: traffic-manager.ambassador
        image: docker.io/datawire/tel2:2.4.9
        imagePullPolicy: IfNotPresent
        name: traffic-agent
        ports:
        - containerPort: 9900
          name: tx-8080
          protocol: TCP
        readinessProbe:
          exec:
            command:
            - /bin/stat
            - /tmp/agent/ready
          failureThreshold: 3
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 1
        resources: {}
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        volumeMounts:
        - mountPath: /tel_pod_info
          name: traffic-annotations
``` 

インターセプト前の Service

```
$ kubectl get svc hello -o jsonpath={.spec.ports} | jq
[
  {
    "port": 80,
    "protocol": "TCP",
    "targetPort": 8080
  }
]
```

インターセプト後の Service では targetPort が `tx-8080` に書き換えられており、これは追加された traffic-agent コンテナの 9900 port を指している。

```
$ kubectl get svc hello -o jsonpath={.spec.ports} | jq
[
  {
    "port": 80,
    "protocol": "TCP",
    "targetPort": "tx-8080"
  }
]
```

### インターセプトの中断

`telepresence leave` コマンドでインターセプトを中断できます。中断では Deployment や Service の書き換えはそのままで、agent の振る舞いが変更されるようです。traffic-agent は元のコンテナの port に転送することになるようです。

```
$ telepresence list
hello: ready to intercept (traffic-agent already installed)
```

traffic-agent の削除
-----------------

`telepresence uninstall` で書き換えた変更を戻します。また Deployment などが書き換えられるので Pod は再作成されます。

```
$ telepresence uninstall --agent hello
```

`(traffic-agent not yet installed)` に戻りました。

```
$ telepresence list
hello: ready to intercept (traffic-agent not yet installed)
```

全ての agent を削除する場合は　`telepresence uninstall --all-agents` が使えし、traffic-managet ごと削除する `--everything` というオプションもあります。

sshfs のインストール
-------------

telepresence では転送元 Pod がマウントしている volume に手元からもアクセスできるようにすることができますが、(mac では) これに sshfs が使われるため、手元の環境にインストールしておく必要があります。が、 `brew install sshfs` すると closed-source な macFUSE が必要だから無効になってるよとインストールできません。

```
Error: sshfs has been disabled because it requires closed-source macFUSE!
```

よって、まず、[github.com/osxfuse/osxfuse/releases](https://github.com/osxfuse/osxfuse/releases) にある macFUSE をインストールし、 その後に [github.com/gromgit/homebrew-fuse](https://github.com/gromgit/homebrew-fuse) にある Homebrew Formula を使ってインストールします。 このリポジトリは mscFUSE が closed-source になってしまったことで Homebrew の core から削られてしまったものをインストールするために作られたもののようです。

```
$ brew install gromgit/fuse/sshfs-mac
```

環境変数や volume のマウント
------------------

telepresence を使うと intercept 対象の Pod に設定されている環境変数を docker 用や json として取得し、使うことができますし、Pod がマウントしている volume を手元でマウントすることが可能で、それをさらに docker コンテナにマウントすることもできます。

普通に **telepresence intercept** コマンドを実行するだけでも転送先に docker コンテナを使うことは可能ですが、`--docker-run` というオプションがあり、これを使うことで `telepresence intercept` コマンド実行で一緒に docker run までしてくれるようになります。

### テスト用に Wordpress をデプロイする

wordpress と mysql との通信もあるし、volume マウントもあって動作確認に便利そうということで [bitnami の helm chart](https://github.com/bitnami/charts/tree/master/bitnami/wordpress) を使って wordpress をデプロイします。この chart は wordpress が NFS などの ReadWriteMany な volume を期待しているのですが、用意するのが面倒なので ReadWriteOne でも使えるように指定しています。(helm3 では `--set` で null を指定することで default の　key を消すということができないので `-f` で指定。外部に公開する必要もないので service の type は LoadBalancer から ClusterIP に変更。updateStrategy は Recreate にしないと volume が手放せないので intercept 時の Pod の再作成で詰まる)

```
$ helm repo add bitnami https://charts.bitnami.com/bitnami
$ helm repo update
$ kubectl create namespace wordpress
$ kubens wordpress
$ helm install wordpress bitnami/wordpress -f - <<EOF
updateStrategy:
  type: Recreate
  rollingUpdate: null
service:
  type: ClusterIP
EOF
```

こんな状態になります。

```
$ kubectl get svc,pod,pv
NAME                        TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
service/wordpress           ClusterIP   172.16.1.117   80/TCP,443/TCP   5m52s
service/wordpress-mariadb   ClusterIP   172.16.7.205   3306/TCP         5m52s

NAME                             READY   STATUS    RESTARTS   AGE
pod/wordpress-7c688c7f48-r8mrf   1/1     Running   0          5m45s
pod/wordpress-mariadb-0          1/1     Running   0          5m45s

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                STORAGECLASS   REASON   AGE
persistentvolume/pvc-07259eb1-aa1c-4521-9029-e57f12b2eedc   8Gi        RWO            Delete           Bound    wordpress/data-wordpress-mariadb-0   standard                5m49s
persistentvolume/pvc-4f85f20c-e376-4489-91df-b126cf029967   10Gi       RWO            Delete           Bound    wordpress/wordpress                  standard                5m50s 
```

wordpress で使われているコンテナイメージを確認

```
$ kubectl get deploy wordpress -o 'jsonpath={.spec.template.spec.containers[0].image}'
docker.io/bitnami/wordpress:5.8.2-debian-10-r47
```

volume のマウント位置を確認

```
$ **kubectl get deploy wordpress -o 'jsonpath={.spec.template.spec.containers[0].volumeMounts}' | jq**
[
  {
    "mountPath": "/bitnami/wordpress",
    "name": "wordpress-data",
    "subPath": "wordpress"
  }
]
```

### 環境変数のファイルへの書き出しと volume のマウント

ここで、次のようにすることで環境変数を wordpress.env というファイルに、Pod がマウントしている volume を wordpress.vol ディレクトリ配下にマウントすることができます。 (wordpress Service は http の 8080 と https の 8443 の2つの port があるので `--port 8080:http` と明示しています)

```
$ telepresence intercept wordpress --port 8080:http --env-file ./wordpress.env --mount ./wordpress.vol
Using Deployment wordpress
intercepted
    Intercept name         : wordpress
    State                  : ACTIVE
    Workload kind          : Deployment
    Destination            : 127.0.0.1:8080
    Service Port Identifier: http
    Volume Mount Point     : ./wordpress.vol
    Intercepting           : all TCP connections

```

wordpress.env の中身

```
$ cat wordpress.env
ALLOW_EMPTY_PASSWORD=yes
APACHE_HTTPS_PORT_NUMBER=8443
APACHE_HTTP_PORT_NUMBER=8080
BITNAMI_DEBUG=false
KO_DATA_PATH=/var/run/ko
KUBERNETES_PORT=tcp://172.16.0.1:443
KUBERNETES_PORT_443_TCP=tcp://172.16.0.1:443
KUBERNETES_PORT_443_TCP_ADDR=172.16.0.1
KUBERNETES_PORT_443_TCP_PORT=443
KUBERNETES_PORT_443_TCP_PROTO=tcp
KUBERNETES_SERVICE_HOST=172.16.0.1
KUBERNETES_SERVICE_PORT=443
KUBERNETES_SERVICE_PORT_HTTPS=443
MARIADB_HOST=wordpress-mariadb
MARIADB_PORT_NUMBER=3306
TELEPRESENCE_CONTAINER=wordpress
TELEPRESENCE_INTERCEPT_ID=bd126583-7aad-4e8b-b00c-09890e027630:wordpress
TELEPRESENCE_MOUNTS=/bitnami/wordpress:/var/run/secrets/kubernetes.io
TELEPRESENCE_ROOT=./wordpress.vol
WORDPRESS_AUTO_UPDATE_LEVEL=none
WORDPRESS_BLOG_NAME=User's Blog!
WORDPRESS_DATABASE_NAME=bitnami_wordpress
WORDPRESS_DATABASE_PASSWORD=kwSIdkeXEC
WORDPRESS_DATABASE_USER=bn_wordpress
WORDPRESS_EMAIL=user@example.com
WORDPRESS_ENABLE_HTACCESS_PERSISTENCE=no
WORDPRESS_EXTRA_WP_CONFIG_CONTENT=
WORDPRESS_FIRST_NAME=FirstName
WORDPRESS_HTACCESS_OVERRIDE_NONE=no
WORDPRESS_LAST_NAME=LastName
WORDPRESS_MARIADB_PORT=tcp://172.16.7.205:3306
WORDPRESS_MARIADB_PORT_3306_TCP=tcp://172.16.7.205:3306
WORDPRESS_MARIADB_PORT_3306_TCP_ADDR=172.16.7.205
WORDPRESS_MARIADB_PORT_3306_TCP_PORT=3306
WORDPRESS_MARIADB_PORT_3306_TCP_PROTO=tcp
WORDPRESS_MARIADB_SERVICE_HOST=172.16.7.205
WORDPRESS_MARIADB_SERVICE_PORT=3306
WORDPRESS_MARIADB_SERVICE_PORT_MYSQL=3306
WORDPRESS_PASSWORD=CZS97FQnB3
WORDPRESS_PLUGINS=none
WORDPRESS_PORT=tcp://172.16.1.117:80
WORDPRESS_PORT_443_TCP=tcp://172.16.1.117:443
WORDPRESS_PORT_443_TCP_ADDR=172.16.1.117
WORDPRESS_PORT_443_TCP_PORT=443
WORDPRESS_PORT_443_TCP_PROTO=tcp
WORDPRESS_PORT_80_TCP=tcp://172.16.1.117:80
WORDPRESS_PORT_80_TCP_ADDR=172.16.1.117
WORDPRESS_PORT_80_TCP_PORT=80
WORDPRESS_PORT_80_TCP_PROTO=tcp
WORDPRESS_SCHEME=http
WORDPRESS_SERVICE_HOST=172.16.1.117
WORDPRESS_SERVICE_PORT=80
WORDPRESS_SERVICE_PORT_HTTP=80
WORDPRESS_SERVICE_PORT_HTTPS=443
WORDPRESS_SKIP_BOOTSTRAP=no
WORDPRESS_TABLE_PREFIX=wp_
WORDPRESS_USERNAME=user
``` 

volume は指定したディレクトリ配下に Pod 内でマウントされていた path でマウントされます。`/bitnami/wordpress` と `/var/run/secrets/kubernetes.io/serviceaccount`

```
$ find wordpress.vol -maxdepth 3 -type d
wordpress.vol
wordpress.vol/bitnami
wordpress.vol/bitnami/wordpress
wordpress.vol/bitnami/wordpress/wp-content
wordpress.vol/var
wordpress.vol/var/run
wordpress.vol/var/run/secrets
```

元のコンテナはこうなってて

```yaml
    volumeMounts:
    - mountPath: /bitnami/wordpress
      name: wordpress-data
      subPath: wordpress
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      name: kube-api-access-cdcc8
      readOnly: true
```

traffic-agent コンテナではこうなっています

```yaml
    volumeMounts:
    - mountPath: /tel_app_mounts/bitnami/wordpress
      name: wordpress-data
      subPath: wordpress
    - mountPath: /tel_pod_info
      name: traffic-annotations
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      name: kube-api-access-cdcc8
      readOnly: true
```

traffic-agent が sftp プロトコルをサポートしてて、sshfs でマウントできるようになっています。

```
$ mount | grep wordpress
localhost:/tel_app_mounts on /Users/teraoka/wordpress.vol (macfuse, nodev, nosuid, synchronous, mounted by teraoka)
```

### 取得した環境変数と　volume を使ってコンテナを起動

環境変数と volume が準備できたのでこれを使って手元で docker コンテナを実行します。

```
$ docker run --rm -it -p 8080:8080 \
  -v $(pwd)/wordpress.vol/bitnami/wordpress:/bitnami/wordpress \
  --env-file ./wordpress.env \
  docker.io/bitnami/wordpress:5.8.2-debian-10-r47
```

```
$ docker run --rm -it -p 8080:8080 \
  -v $(pwd)/wordpress.vol/bitnami/wordpress:/bitnami/wordpress \
  --env-file ./wordpress.env \
  docker.io/bitnami/wordpress:5.8.2-debian-10-r47
wordpress 05:00:16.43 
wordpress 05:00:16.44 Welcome to the Bitnami wordpress container
wordpress 05:00:16.44 Subscribe to project updates by watching https://github.com/bitnami/bitnami-docker-wordpress
wordpress 05:00:16.44 Submit issues and feature requests at https://github.com/bitnami/bitnami-docker-wordpress/issues
wordpress 05:00:16.44 
wordpress 05:00:16.44 INFO  ==> ** Starting WordPress setup **
realpath: /bitnami/apache/conf: No such file or directory
wordpress 05:00:16.48 INFO  ==> Configuring the HTTP port
wordpress 05:00:16.49 INFO  ==> Configuring the HTTPS port
wordpress 05:00:16.51 INFO  ==> Configuring PHP options
wordpress 05:00:16.52 INFO  ==> Validating settings in MYSQL_CLIENT_* env vars
wordpress 05:00:16.57 WARN  ==> Hostname wordpress-mariadb could not be resolved, this could lead to connection issues
wordpress 05:00:16.58 WARN  ==> You set the environment variable ALLOW_EMPTY_PASSWORD=yes. For safety reasons, do not use this flag in a production environment.
wordpress 05:00:16.77 INFO  ==> Restoring persisted WordPress installation
wordpress 05:00:17.63 INFO  ==> Trying to connect to the database server
wordpress 05:03:00.25 ERROR ==> Could not connect to the database
```

残念ながら `Could not connect to the database` というエラーで起動しませんでした... 原因は DB サーバーのホスト名が wordpress-mariadb と指定されていることで、これは同じ namespace にいる Pod からであればアクセス可能なのですが、telepresence 経由では少なくとも namespace が付いていないと名前解決ができません。 ということなので、当該箇所を書き換えてみます。(mac の sed の -i は GNU sed の -i とは違うので gsed と指定)

```
$ grep DB_HOST wordpress.vol/bitnami/wordpress/wp-config.php
define( 'DB_HOST', 'wordpress-mariadb:3306' );

$ gsed -i 's/wordpress-mariadb/wordpress-mariadb.wordpress/' ./wordpress.vol/bitnami/wordpress/wp-config.php

$ grep DB_HOST wordpress.vol/bitnami/wordpress/wp-config.php
define( 'DB_HOST', 'wordpress-mariadb.wordpress:3306' );
```

これで再度コンテナを起動すれば無事起動しました。(環境変数の MARIADB\_HOST も namespace 無しで設定されているので、volume をマウントしないで試す場合はこちらを書き換える必要があります)

現在の状態は手元のコンテナで wordpress を実行しているが、その wp-content 配下は Kubernetes 内の volume に置かれているし、DB サーバーも Kubernetes 上で実行されている mariadb が使われていることになる。

手元でブラウザから localhost:8080 で Wordpress にアクセスすることも出来るし、Kubernetes 内から Service 経由でアクセスすることもできる。

使いたい場面に遭遇したら使えそうです。
