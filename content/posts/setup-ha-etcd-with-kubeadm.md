---
title: 'kubeadm で HA な etcd をセットアップ'
date: Mon, 13 Aug 2018 15:49:58 +0000
draft: false
tags: ['etcd', 'kubeadm']
---

[Set up a Highly Availabile etcd Cluster With kubeadm](https://kubernetes.io/docs/setup/independent/setup-ha-etcd-with-kubeadm/) をなぞります。

### 各種バージョン情報

* CentOS Linux release 7.5.1804
* kubeadm v1.11.2 (GitCommit:"bb9ffb1654d4a729bb4cec18ff088eacc153c239")
* docker 1.13.1 (docker-1.13.1-68.gitdded712.el7.centos.x86\_64)
* kubelet v1.11.2 (Kubernetes v1.11.2)
* etcd 3.2.18

### Before you begin

* 互いに 2379/tcp (client ↔ server), 2380/tcp (server ↔ server peering) ポートで通信可能な 3 台のホスト (ポート番号を変更する場合は kubeadm の設定を変更する必要がある)
* それぞれのホストには docker, kubelet, kubeadm がインストールされていること ([Installing kubeadm](https://kubernetes.io/docs/setup/independent/install-kubeadm/))
* ssh や scp で互いにファイルをコピーできること

### Setting up the cluster

ひとつのホストですべての証明書を作成し、他のホストへ配ります。

1.  kubelet が etcd のサービスマネージャとなるように設定する
    
    etcd は kubernetes よりもシンプルであり、kubeadm が生成する kubelet の unit ファイルを上書きする必要があります
    
    ```bash
    mkdir /var/lib/kubelet
    cat << EOF > /var/lib/kubelet/config.yaml
    kind: KubeletConfiguration
    apiVersion: kubelet.config.k8s.io/v1beta1
    cgroupDriver: "systemd"
    address: "127.0.0.1"
    staticPodPath: "/etc/kubernetes/manifests"
    authentication:
      x509:
        clientCAFile: "/etc/kubernetes/pki/etcd/ca.crt"
        enabled: true
      webhook:
        enabled: false
      anonymous:
        enabled: false
    authorization:
      mode: "AlwaysAllow"
    EOF
    ```
    
    `staticPodPath` で指定したディレクトリに手順の後の方で出てくる kubeadm コマンドで etcd.yaml が出力されます。webhook での認証・認可環境がないので無効にして認証の x509 を有効にして認可を AlwaysAllow にしてあります。x509 ではなく anonymous を有効にするという方法もある
    
    ```bash
    cat << 'EOF' > /etc/systemd/system/kubelet.service.d/20-etcd-service-manager.conf
    [Service]
    ExecStart=
    ExecStart=/usr/bin/kubelet $KUBELET_CONFIG_ARGS --allow-privileged=true
    Restart=always
    EOF
    
    systemctl daemon-reload
    ```

    `$KUBELET_CONFIG_ARGS` は `--config=/var/lib/kubelet/config.yaml` となっている、`--allow-privileged` オプションは将来無くなるらしいが、そもそも etcd の実行に必要なんだろうか？
2.  kubeadm の設定ファイルを作成する
    
    次のスクリプトを使って各ホストの kubeadm 用設定ファイルを生成します
    
    ```bash
    # Update HOST0, HOST1, and HOST2 with the IPs or resolvable names of your hosts
    export HOST0=10.0.0.6
    export HOST1=10.0.0.7
    export HOST2=10.0.0.8
    
    # Create temp directories to store files that will end up on other hosts.
    mkdir -p /tmp/${HOST0}/ /tmp/${HOST1}/ /tmp/${HOST2}/
    
    ETCDHOSTS=(${HOST0} ${HOST1} ${HOST2})
    NAMES=("etcd1" "etcd2" "etcd3")
    
    for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    NAME=${NAMES[$i]}
    cat << EOF > /tmp/${HOST}/kubeadmcfg.yaml
    apiVersion: "kubeadm.k8s.io/v1alpha2"
    kind: MasterConfiguration
    etcd:
        local:
            serverCertSANs:
            - "${HOST}"
            peerCertSANs:
            - "${HOST}"
            extraArgs:
                initial-cluster: ${NAMES[0]}=https://${ETCDHOSTS[0]}:2380,${NAMES[1]}=https://${ETCDHOSTS[1]}:2380,${NAMES[2]}=https://${ETCDHOSTS[2]}:2380
                initial-cluster-state: new
                name: ${NAME}
                listen-peer-urls: https://${HOST}:2380
                listen-client-urls: https://${HOST}:2379
                advertise-client-urls: https://${HOST}:2379
                initial-advertise-peer-urls: https://${HOST}:2380
    EOF
    done
    ```
3.  認証局(CA)ファイルの生成
    
    すでに CA が存在すれが、その `crt` と `key` ファイルを `/etc/kubernetes/pki/etcd/ca.crt`, `/etc/kubernetes/pki/etcd/ca.key` にコピーするだけです。
    
    CA ファイルがまだない場合は次のコマンドを `$HOST0` （kubeadm 用の設定ファイルを作成したホスト）上で実行します
    
    ```
    kubeadm alpha phase certs etcd-ca
    ```
    
    これで次の2ファイルが生成されます
    
    * `/etc/kubernetes/pki/etcd/ca.crt`
    * `/etc/kubernetes/pki/etcd/ca.key`
    
4.  各ホスト用の証明書を作成する
    
    ```bash
    kubeadm alpha phase certs etcd-server --config=/tmp/${HOST2}/kubeadmcfg.yaml
    kubeadm alpha phase certs etcd-peer --config=/tmp/${HOST2}/kubeadmcfg.yaml
    kubeadm alpha phase certs etcd-healthcheck-client --config=/tmp/${HOST2}/kubeadmcfg.yaml
    kubeadm alpha phase certs apiserver-etcd-client --config=/tmp/${HOST2}/kubeadmcfg.yaml
    cp -R /etc/kubernetes/pki /tmp/${HOST2}/
    # cleanup non-reusable certificates
    find /etc/kubernetes/pki -not -name ca.crt -not -name ca.key -type f -delete
    
    kubeadm alpha phase certs etcd-server --config=/tmp/${HOST1}/kubeadmcfg.yaml
    kubeadm alpha phase certs etcd-peer --config=/tmp/${HOST1}/kubeadmcfg.yaml
    kubeadm alpha phase certs etcd-healthcheck-client --config=/tmp/${HOST1}/kubeadmcfg.yaml
    kubeadm alpha phase certs apiserver-etcd-client --config=/tmp/${HOST1}/kubeadmcfg.yaml
    cp -R /etc/kubernetes/pki /tmp/${HOST1}/
    find /etc/kubernetes/pki -not -name ca.crt -not -name ca.key -type f -delete
    
    kubeadm alpha phase certs etcd-server --config=/tmp/${HOST0}/kubeadmcfg.yaml
    kubeadm alpha phase certs etcd-peer --config=/tmp/${HOST0}/kubeadmcfg.yaml
    kubeadm alpha phase certs etcd-healthcheck-client --config=/tmp/${HOST0}/kubeadmcfg.yaml
    kubeadm alpha phase certs apiserver-etcd-client --config=/tmp/${HOST0}/kubeadmcfg.yaml
    # No need to move the certs because they are for HOST0
    
    # clean up certs that should not be copied off this host
    find /tmp/${HOST2} -name ca.key -type f -delete
    find /tmp/${HOST1} -name ca.key -type f -delete
    ```
5.  証明書と kubeadm 用の設定ファイルをコピーする
    
    ```bash
    scp -r /tmp/${HOST1}/* ${HOST1}:
    ssh ${HOST1} "sudo chown -R root:root pki; sudo mv pki /etc/kubernetes/"
    scp -r /tmp/${HOST2}/\* ${HOST2}:
    ssh ${HOST2} "sudo chown -R root:root pki; sudo mv pki /etc/kubernetes/"
    ```
6.  必要なファイルが存在していることを確認
    
    `$HOST0`
    
    ```
    /tmp/${HOST0}
    └── kubeadmcfg.yaml
    ---
    /etc/kubernetes/pki
    ├── apiserver-etcd-client.crt
    ├── apiserver-etcd-client.key
    └── etcd
        ├── ca.crt
        ├── ca.key
        ├── healthcheck-client.crt
        ├── healthcheck-client.key
        ├── peer.crt
        ├── peer.key
        ├── server.crt
        └── server.key
    ```
    
    `$HOST1`
    
    ```
    $HOME
    └── kubeadmcfg.yaml
    ---
    /etc/kubernetes/pki
    ├── apiserver-etcd-client.crt
    ├── apiserver-etcd-client.key
    └── etcd
        ├── ca.crt
        ├── healthcheck-client.crt
        ├── healthcheck-client.key
        ├── peer.crt
        ├── peer.key
        ├── server.crt
        └── server.key
    ```
    
    `$HOST2`
    
    ```
    $HOME
    └── kubeadmcfg.yaml
    ---
    /etc/kubernetes/pki
    ├── apiserver-etcd-client.crt
    ├── apiserver-etcd-client.key
    └── etcd
        ├── ca.crt
        ├── healthcheck-client.crt
        ├── healthcheck-client.key
        ├── peer.crt
        ├── peer.key
        ├── server.crt
        └── server.key
    ```
    
    ```
    apiserver-etcd-client.crt
        Subject O=system:masters, CN=kube-apiserver-etcd-client
    server.crt
        Subject CN=etcd1  
        SAN DNS:etcd1, DNS:localhost, IP Address:127.0.0.1, IP Address:0:0:0:0:0:0:0:1, IP Address:${HOSTn}
    healthcheck-client.crt
        Subject O=system:masters, CN=kube-etcd-healthcheck-client
    peer.crt
        Subject CN=etcd1  
        SAN DNS:etcd1, DNS:localhost, IP Address:${HOST0}, IP Address:127.0.0.1, IP Address:0:0:0:0:0:0:0:1, IP Address:${HOSTn}
    ```
    
    `etcd1` は `kubeadm` コマンドを実行した1台目のホスト名
    
7.  静的Podマニフェストを作成
    
    証明書と設定ファイルのコピーが終わったらマニフェストを作成します。各ホストで `kubeadm` コマンドを使ってマニフェストを作成します。
    
    ```
    root@HOST0 $ kubeadm alpha phase etcd local --config=/tmp/${HOST0}/kubeadmcfg.yaml
    root@HOST1 $ kubeadm alpha phase etcd local --config=kubeadmcfg.yaml
    root@HOST2 $ kubeadm alpha phase etcd local --config=kubeadmcfg.yaml
    ```
8.  任意：クラスタの状態を確認する
    
    ```bash
    docker run --rm -it \
    --net host \
    -v /etc/kubernetes:/etc/kubernetes quay.io/coreos/etcd:v3.2.18 etcdctl \
    --cert-file /etc/kubernetes/pki/etcd/peer.crt \
    --key-file /etc/kubernetes/pki/etcd/peer.key \
    --ca-file /etc/kubernetes/pki/etcd/ca.crt \
    --endpoints https://${HOST0}:2379 cluster-health
    ```
    
    出力に `cluster is healthy` があれば etcd クラスタは正常に稼働しているはずです
