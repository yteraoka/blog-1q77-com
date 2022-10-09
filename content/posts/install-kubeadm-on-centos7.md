---
title: 'CentOS 7 に kubeadm をインストール'
date: Sat, 11 Aug 2018 16:07:55 +0000
draft: false
tags: ['Docker', 'kubeadm']
---

"[Installing kubeadm - Kubernetes](https://kubernetes.io/docs/setup/independent/install-kubeadm/)" を参考に CentOS 7 に kubeadm をインストールします

### 各種バージョン情報

* CentOS Linux release 7.5.1804
* kubeadm v1.11.2 (GitCommit:"bb9ffb1654d4a729bb4cec18ff088eacc153c239")
* docker 1.13.1 (docker-1.13.1-68.gitdded712.el7.centos.x86\_64)
* kubelet v1.11.2 (Kubernetes v1.11.2)

### Before you begin

* サポートされている OS は沢山あるが今回は CentOS 7 を使います
* 2GB 以上のメモリ
* 2つ以上の CPU
* ホストは互いに通信可能なこと
* 一意な hostname, MAC address, product\_uuid (\``sudo cat /sys/class/dmi/id/product_uuid`\`)
* 必要なポートが開いていること(用途によって異なる)
* swap の無効化 (kubelet の動作のために必要)

### Installing Docker

```
yum install -y docker
systemctl enable docker && systemctl start docker
```

### Installing kubeadm, kubelet and kubectl

次のパッケージをインストールします

**kubeadm**

クラスタ構築用コマンド

**kubelet**

クラスタ内のすべてのホストで実行され、pod やコンテナの起動などを行う

**kubectl**

クラスタ操作用コマンド

`kubeadm` は `kubelet` と `kubectl` のインストールや更新を行わないため、`kubeadm` でインストールされる `kubernetes` のコントロールプレーンバージョンと合わせる必要があります。`kubelet` のバージョンはコントロールプレーンのバージョンの一つ前のマイナーバージョンまではサポートされます。たとえば、1.7.0 の `kubelet` は 1.8.0 のコントロールプレーンとは互換性があります。

```
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kube*
EOF
setenforce 0
sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
mkdir /var/lib/kubelet
cat <<EOF > /var/lib/kubelet/config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: "systemd"
EOF
systemctl enable kubelet
```

SELinux を無効にするため `setenforce 0` の実行が必要です。**kubelet** の SELinux 対応が改善されるまではこれが必要です。 永続化

```
sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config
```

iptables がバイパスされるために正しくルーティングされないという問題が報告されているため `sysctl` で `net.bridge.bridge-nf-call-iptables` を `1` にする必要があります。

```
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system
```

### Configure cgroup driver used by kubelet on Master Node

「Docker を使う場合、kubeadm は自動で cgroup driver を検出し、`/var/lib/kubelet/kubeadm-flags.env` にセットします」。別の CRI を使う場合は `/etc/default/kubelet` で次のように `cgroup-driver` を指定する必要があります」と書いてあるけど CentOS 7 の docker では `kubeadm-flags.env` は生成されなかった。 ドキュメントには `KUBELET_KUBEADM_EXTRA_ARGS` とあるが、systemd の unit ファイルにこの変数は無いので `KUBELET_EXTRA_ARGS` だろうか。

```
KUBELET_EXTRA_ARGS=--cgroup-driver=<value>
```

変更の反映には `kubelet` の次のようにして再起動する必要があります

```
systemctl daemon-reload
systemctl restart kubelet
```

しかし、1.10 以降、`--cgroup-driver` などの引数はすべて **DEPRECATED** となっており `--config` で指定するファイルに書けということになっている。"[Set Kubelet parameters via a config file](https://kubernetes.io/docs/tasks/administer-cluster/kubelet-config-file/)" 項目と値は [types.go](https://github.com/kubernetes/kubernetes/blob/release-1.10/pkg/kubelet/apis/kubeletconfig/v1beta1/types.go) を見て探す。 `/etc/systemd/system/kubelet.service.d/10-kubeadm.conf` に

```
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
```

と書かれているのでこのファイルを使うのが良いと思うが、ディレクトリは存在しないので作成する必要がある。設定内容はセットアップするものや環境に依存するようなので、それぞれのセットアップにて試してみる。 参考： [Kubernetes 1.10のkubeletの起動オプションをKubelet ConfigファイルとPodSecurityPolicyで置き換える](https://www.kaitoy.xyz/2018/05/05/kubernetes-kubelet-config-and-pod-sec-policy/)

後に、コントロールプレーン用に `kubeadm init` を実行したらその処理の中で `/var/lib/kubelet/kubeadm-flags.env` と `/var/lib/kubelet/config.yaml` が作成されていた。

```
[preflight/images] Pulling images required for setting up a Kubernetes cluster
[preflight/images] This might take a minute or two, depending on the speed of your internet connection
[preflight/images] You can also perform this action in beforehand using 'kubeadm config images pull'
[kubelet] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[preflight] Activating the kubelet service
```

### Troubleshooting

なにか問題にぶつかったら "[Troubleshooting kubeadm](https://kubernetes.io/docs/setup/independent/troubleshooting-kubeadm/)" を見てみましょう。
