---
title: 'Docker Desktop の代わりに Minikube を使ってみる'
date: Sun, 19 Sep 2021 01:07:27 +0900
draft: false
tags: ['Docker', 'Kubernetes', 'minikube']
---

Docker のおかげで今の便利なコンテナがあります、ありがとうございます。でもどうなるのかやってみたかったんです。

[Goodbye Docker Desktop, Hello Minikube!](https://itnext.io/goodbye-docker-desktop-hello-minikube-3649f2a1c469) を参考に試してみます。

環境は Intel Mac の Big Sur です。Mac で docker を使うには docker daemon を稼働させるための Linux 仮想マシンが必要で、Docker Desktop はそこをうまいことやってくれています。その docker daemon の稼働する仮想マシンとして minikube 用のものを活用しようという話です。

Docker Desktop の Uninstall
--------------------------

アプリとしては消したけどでっかい VM のイメージは残ってるから、もう再度インストールすることもないという状況になったら削除しよう。

`~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw`

Docker CLI の Install
--------------------

```
$ brew install docker

```

必要なら docker-compose も。ただし、今時は docker のサブコマンドになっているので docker-compose コマンドをインストールする必要はなさそう。

```
$ brew install docker-compose

```

hyperkit の Install (しなかった)
--------------------------

hyperkit ってインストール済みだと思ってたけど消えてた(?) Docker Desktop と共に消えてたりするのかな？

```
$ brew install hyperkit

```

App Store から Xcode をインストールしろと言われた。ダウンロードに時間がかかる... が、途中で VirtualBox でも問題なくね？ もうインストール済みだし、と思って中断した。以前に Minikube を使ってた時も VirtualBox だったし。

Minikube の Install
------------------

[Homebrew](https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/minikube.rb) にもあるけど [asdf](https://github.com/asdf-vm/asdf) (_www.mod.go.jp/asdf/_ じゃないよ) でもインストールできます。

```
$ asdf plugin add minikube
$ asdf install minikube latest
$ asdf global minikube latest

```

```
$ minikube version
minikube version: v1.23.1
commit: 84d52cd81015effbdd40c632d9de13db91d48d43

```

### Minikube VM 起動

```
$ minikube start
😄  minikube v1.23.1 on Darwin 11.6
    ▪ MINIKUBE_ACTIVE_DOCKERD=minikube
✨  Automatically selected the virtualbox driver
💿  Downloading VM boot image ...
    > minikube-v1.23.1.iso.sha256: 65 B / 65 B [-------------] 100.00% ? p/s 0s
    > minikube-v1.23.1.iso: 225.22 MiB / 225.22 MiB [] 100.00% 8.65 MiB p/s 26s
👍  Starting control plane node minikube in cluster minikube
💾  Downloading Kubernetes v1.22.1 preload ...
    > preloaded-images-k8s-v13-v1...: 511.84 MiB / 511.84 MiB  100.00% 8.43 MiB
🔥  Creating virtualbox VM (CPUs=2, Memory=4000MB, Disk=20000MB) ...
🐳  Preparing Kubernetes v1.22.1 on Docker 20.10.8 ...
    ▪ Generating certificates and keys ...
    ▪ Booting up control plane ...
    ▪ Configuring RBAC rules ...
    ▪ Using image gcr.io/k8s-minikube/storage-provisioner:v5
🔎  Verifying Kubernetes components...
🌟  Enabled addons: storage-provisioner, default-storageclass
🏄  Done! kubectl is now configured to use "minikube" cluster and "default" namespace by default
```

昔の設定が ~/.minikube に残ってたらいくつかエラーが出てたけど消してやり直したらきれいになった。

docker コマンドが使えるようにする
--------------------

mac 上で docker コマンドが使えるようにする。`minikube docker-env` コマンドの出力はこんな感じ。

```
$ minikube docker-env
export DOCKER_TLS_VERIFY="1"
export DOCKER_HOST="tcp://192.168.99.104:2376"
export DOCKER_CERT_PATH="/Users/teraoka/.minikube/certs"
export MINIKUBE_ACTIVE_DOCKERD="minikube"

# To point your shell to minikube's docker-daemon, run:
# eval $(minikube -p minikube docker-env)
```

eval で shell に読み込ませる

```
$ eval $(minikube docker-env)
```

まあ、わかってたことだけど、ネットワーク越しに minikube VM (Virtual Machine) 上の docker daemon を使うってだけなのよね。

```
$ docker info
Client:
 Context:    default
 Debug Mode: false

Server:
 Containers: 15
  Running: 14
  Paused: 0
  Stopped: 1
 Images: 10
 Server Version: 20.10.8
 Storage Driver: overlay2
  Backing Filesystem: extfs
  Supports d\_type: true
  Native Overlay Diff: true
  userxattr: false
 Logging Driver: json-file
 Cgroup Driver: systemd
 Cgroup Version: 1
 Plugins:
  Volume: local
  Network: bridge host ipvlan macvlan null overlay
  Log: awslogs fluentd gcplogs gelf journald json-file local logentries splunk syslog
 Swarm: inactive
 Runtimes: io.containerd.runtime.v1.linux runc io.containerd.runc.v2
 Default Runtime: runc
 Init Binary: docker-init
 containerd version: e25210fe30a0a703442421b0f60afac609f950a3
 runc version: 4144b63817ebcc5b358fc2c8ef95f7cddd709aa7
 init version: de40ad0
 Security Options:
  seccomp
   Profile: default
 Kernel Version: 4.19.202
 Operating System: Buildroot 2021.02.4
 OSType: linux
 Architecture: x86\_64
 CPUs: 2
 Total Memory: 3.753GiB
 Name: minikube
 ID: CGNK:YXRA:XBUK:QGIQ:73CZ:RNAV:NFAQ:CILA:UWB2:6SQ7:XTHN:36LK
 Docker Root Dir: /var/lib/docker
 Debug Mode: false
 Registry: https://index.docker.io/v1/
 Labels:
  provider=virtualbox
 Experimental: false
 Insecure Registries:
  10.96.0.0/12
  127.0.0.0/8
 Live Restore Enabled: false
 Product License: Community Engine

WARNING: No blkio throttle.read_bps_device support
WARNING: No blkio throttle.write_bps_device support
WARNING: No blkio throttle.read_iops_device support
WARNING: No blkio throttle.write_iops_device support

```

普段から minikube を使ってるって人にとってはこれでも良だそうだけど、そうでなければ不必要なものを沢山動かすことになってリソースが勿体無い

```
$ docker ps
CONTAINER ID   IMAGE                  COMMAND                  CREATED              STATUS              PORTS     NAMES
1aeae02d7106   6e38f40d628d           "/storage-provisioner"   About a minute ago   Up About a minute             k8s_storage-provisioner_storage-provisioner_kube-system_98d3f7de-f2e3-491e-b876-a49872bcd33c_1
de5bb6423584   8d147537fb7d           "/coredns -conf /etc…"   About a minute ago   Up About a minute             k8s_coredns_coredns-78fcd69978-qg8fw_kube-system_7f9697a5-b019-41fd-abe7-e2d07f2eb6ca_0
b8cde6bf5ee5   k8s.gcr.io/pause:3.5   "/pause"                 About a minute ago   Up About a minute             k8s_POD_coredns-78fcd69978-qg8fw_kube-system_7f9697a5-b019-41fd-abe7-e2d07f2eb6ca_0
97986df4b04b   36c4ebbc9d97           "/usr/local/bin/kube…"   About a minute ago   Up About a minute             k8s_kube-proxy_kube-proxy-6s82v_kube-system_32554fb1-b716-4e8b-b1ec-ae4ed5385b9d_0
4068a36aea92   k8s.gcr.io/pause:3.5   "/pause"                 About a minute ago   Up About a minute             k8s_POD_kube-proxy-6s82v_kube-system_32554fb1-b716-4e8b-b1ec-ae4ed5385b9d_0
312b76f0c855   k8s.gcr.io/pause:3.5   "/pause"                 About a minute ago   Up About a minute             k8s_POD_storage-provisioner_kube-system_98d3f7de-f2e3-491e-b876-a49872bcd33c_0
9eacdd6b851a   aca5ededae9c           "kube-scheduler --au…"   2 minutes ago        Up 2 minutes                  k8s_kube-scheduler_kube-scheduler-minikube_kube-system_6fd078a966e479e33d7689b1955afaa5_0
bf5f741cd675   6e002eb89a88           "kube-controller-man…"   2 minutes ago        Up 2 minutes                  k8s_kube-controller-manager_kube-controller-manager-minikube_kube-system_e8c1f1261ee630eae00126001a8e22df_0
2836454dfc0c   f30469a2491a           "kube-apiserver --ad…"   2 minutes ago        Up 2 minutes                  k8s_kube-apiserver_kube-apiserver-minikube_kube-system_be6473e3f27b6fbc4123c6b2d7489c82_0
cac78141b312   004811815584           "etcd --advertise-cl…"   2 minutes ago        Up 2 minutes                  k8s_etcd_etcd-minikube_kube-system_651082f7ca1d6843bfefc4a589200e75_0
7f0ce289318c   k8s.gcr.io/pause:3.5   "/pause"                 2 minutes ago        Up 2 minutes                  k8s_POD_kube-controller-manager-minikube_kube-system_e8c1f1261ee630eae00126001a8e22df_0
71a468581e7e   k8s.gcr.io/pause:3.5   "/pause"                 2 minutes ago        Up 2 minutes                  k8s_POD_kube-apiserver-minikube_kube-system_be6473e3f27b6fbc4123c6b2d7489c82_0
cac60b0f8152   k8s.gcr.io/pause:3.5   "/pause"                 2 minutes ago        Up 2 minutes                  k8s_POD_etcd-minikube_kube-system_651082f7ca1d6843bfefc4a589200e75_0
19a35095f3d2   k8s.gcr.io/pause:3.5   "/pause"                 2 minutes ago        Up 2 minutes                  k8s_POD_kube-scheduler-minikube_kube-system_6fd078a966e479e33d7689b1955afaa5_0
```

コンテナを実行してみる
-----------

docker pull もできる。もちろん image は minikube の VM 内に置かれる

```
$ docker pull nginx:latest
latest: Pulling from library/nginx
a330b6cecb98: Pull complete 
e0ad2c0621bc: Pull complete 
9e56c3e0e6b7: Pull complete 
09f31c94adc6: Pull complete 
32b26e9cdb83: Pull complete 
20ab512bbb07: Pull complete 
Digest: sha256:853b221d3341add7aaadf5f81dd088ea943ab9c918766e295321294b035f3f3e
Status: Downloaded newer image for nginx:latest
docker.io/library/nginx:latest
```

port の expose も出来るし、ブラウザでアクセスすることもできる。ただし、localhost ではない。

```
$ docker run -d --rm -p 80:80 nginx:latest
b5ebaf240d5d53d733e0b3346b4d8c822fedc1385a7338c8b433df9010289572
```

```
$ docker ps | grep b5ebaf2
b5ebaf240d5d   nginx:latest           "/docker-entrypoint.…"   18 seconds ago   Up 18 seconds   0.0.0.0:80->80/tcp   frosty_allen
```

minikube VM の IP アドレスを確認

```
$ minikube ip
192.168.99.105
```

```
$ curl http://192.168.99.105/
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

元記事では [ingress-dns](https://minikube.sigs.k8s.io/docs/handbook/addons/ingress-dns/) や metallb addon についても触れられている。

ところで、minikube 内の Pod から Host (ここでは mac) にアクセスするために **host.minikube.internal** という名前が使えるようになってるんですね。 VM の /etc/hosts と CoreDNS の設定ファイル Corefile に書かれています、だから docker コマンドでデプロイしたコンテナでは使えない。 ([Host access](https://minikube.sigs.k8s.io/docs/handbook/host-access/))

Docker Desktop では **host.docker.internal** という名前で Host にアクセスできていました。Minikube + Docker CLI では自分で `--add-host` を使って指定する必要があります。ここで指定するアドレスは上記の **host.minikube.internal** で指定されてるアドレスです。

Credential Helpder
------------------

Docker Desktop を削除したことで **docker-credential-helper** も消えてしまっており、`docker push` は **denied: requested access to the resource is denied** となり、 `docker login` もエラーになってしまいました。

```
$ docker login
Login with your Docker ID to push and pull images from Docker Hub. If you don't have a Docker ID, head over to https://hub.docker.com to create one.
Username: yteraoka
Password: 
Error saving credentials: error storing credentials - err: exec: "docker-credential-desktop": executable file not found in $PATH, out: ``
```

これは一旦 ~/.docker/config.json を削除することで再度 docker login が可能になるのですが、これでは base64 されただけのパスワードが json ファイルに書かれてしまいます。これは **[docker-credential-helper](https://github.com/docker/docker-credential-helpers)** を [Homebrew](https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/docker-credential-helper.rb) でインストールすれば **docker-credential-osxkeychain** がキーチェーンにアクセスしてくれます。Docker Desktop の場合は config.json 内の `credsStore` は `desktop` でしたが、docker-credential-helper では `osxkeychain` になっています。ということなのでファイルごと消さなくても `credsStore` の値を書き換えれば良いのかも。でも keychain へのアクセス権を与えるのは慎重に。

```
$ **brew install docker-credential-helper**

```

Minikube の停止について
----------------

元記事では Hyperkit を使った場合、`minikube stop` で停止するとコンテナイメージや Persistent Volume が消えるから `minikube pause` / `minikube unpause` を使えとありますが、VirtualBox の場合は stop しても消えません。`minikube delete` したら VM のイメージごと削除されます。**~/.minikube/cache/images/** 配下に image を置いておくと VM イメージを削除しても残ってます。

Host のディレクトリを docker コンテナでマウントしたい
---------------------------------

Docker を使って開発したりする場合はこの機能は必須ですね。Minikube を使う場合はまず minikube VM にマウントさせる必要があります。`minikube mount` コマンドを使うことで指定したディレクトリに minikube VM からアクセスすることができるようになります。

```
$ minikube mount $HOME:$HOME
📁  Mounting host path /Users/teraoka into VM as /Users/teraoka ...
    ▪ Mount type:   
    ▪ User ID:      docker
    ▪ Group ID:     docker
    ▪ Version:      9p2000.L
    ▪ Message Size: 262144
    ▪ Permissions:  755 (-rwxr-xr-x)
    ▪ Options:      map[]
    ▪ Bind Address: 192.168.99.1:62416
🚀  Userspace file server: ufs starting
✅  Successfully mounted /Users/teraoka to /Users/teraoka

📌  NOTE: This process must stay alive for the mount to be accessible ...
```

このコマンドは実行中はマウントされているという状態で、Ctrl-C で停止すると次のように表示されるわけですが、なぜかこの状態でも VM 上からアクセスできちゃいました？？？

```
🔥  Unmounting /Users/teraoka ...

❌  Exiting due to MK_INTERRUPTED: Received interrupt signal
```

`minikube stop` && `minikube start` してもマウントした状態は維持されてました。謎

VM 内で mount コマンドで確認してみると **vboxsf** というやつだった

```
$ mount | grep /Users
Users on /Users type vboxsf (rw,nodev,relatime)
```

VM 上で単に umount コマンドを実行するだけではダメで

```
$ sudo umount /Users
umount.nfs: Users on /Users is not an NFS filesystem
```

`-t vboxfs` と `-i` を指定する必要があった。`-i` は初めて使った。`--internal-only` らしい。(Don't call the /sbin/umount.<filesystem> helper even if it exists. By default /sbin/umount.<filesystem> helper is called if one exists.)

```
$ sudo umount -t vboxsf -i /Users
```

が、その後小さなディレクトリをマウントしたら minikube mount を止めた時点でマウントは解除されたし、VM からの見え方も違ってた

```
$ mount | grep /html
192.168.99.1 on /html type 9p (rw,relatime,sync,dirsync,dfltuid=1000,dfltgid=1000,access=any,msize=65536,trans=tcp,noextend,port=62602)
```

で、docker でのマウントだが、minikube mount でマウントしたディレクトリ内を `docker run` コマンドの `-v` オプションで指定すれば機体の動作をしてくれた

めでたしめでたし
--------

しかし、Kubernetes が runtime として docker を非推奨としているので minikube で docker が使われなくなる日が来るかもしれないということは気に留めておく必要がありそう。[containerd](https://github.com/containerd/containerd) 変わったら [nerdctl](https://github.com/containerd/nerdctl) が使えるようになるかな？

参考資料
----

*   [Goodbye Docker Desktop, Hello Minikube!](https://itnext.io/goodbye-docker-desktop-hello-minikube-3649f2a1c469)
*   [Docker Desktop for Macの裏で動いている仮想マシン(Linux)に直接アクセスする方法](https://qiita.com/notakaos/items/b08ba7166bb5b56576a1)
*   [Virtualbox の 共有フォルダ を マウント/アンマウント したい](https://qiita.com/dojineko/items/f7f94e94dcbb29bb5cf9)
