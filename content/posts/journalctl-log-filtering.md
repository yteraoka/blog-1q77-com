---
title: 'journalctl で docker のログをフィルタリング'
date: Sun, 09 Sep 2018 09:51:59 +0000
draft: false
tags: ['Docker', 'journald', 'systemd']
---

CentOS 7 で kubeadm を使って Kubernetes をセットアップしていると docker の logging driver が journald になっています。 各 container は docker daemon 配下で動作するため、systemd の unit 名はどれも `docker.service` になってしまい、`journalctl -u xxx` ではコンテナ単位での確認ができません。 `journalctl` は `-o json` とすると、default の `short` では出力されないメタデータも出力されます。pipe で `[jq](https://stedolan.github.io/jq/)` コマンドに渡せば次のように出力されます。

```
{
  "__CURSOR": "s=3e5c46fa81a54c369a8e1858c04b5204;i=3f72;b=ae5c5309f05e4a699808679fe6781eb8;m=1b352c11d;t=5756cf7db2231;x=66b27cca0ce000f1",
  "__REALTIME_TIMESTAMP": "1536485758804529",
  "__MONOTONIC_TIMESTAMP": "7303512349",
  "_BOOT_ID": "ae5c5309f05e4a699808679fe6781eb8",
  "PRIORITY": "6",
  "CONTAINER_ID_FULL": "7930a5a8469b5d68ac6048a0df508c22425999d7a8cbe60f8a4165ba16a51256",
  "CONTAINER_NAME": "k8s_calico-node_calico-node-7t275_kube-system_12fd8feb-b404-11e8-8de4-76af76a1afa6_0",
  "CONTAINER_TAG": "7930a5a8469b",
  "CONTAINER_ID": "7930a5a8469b",
  "_TRANSPORT": "journal",
  "_PID": "9950",
  "_UID": "0",
  "_GID": "0",
  "_COMM": "dockerd-current",
  "_EXE": "/usr/bin/dockerd-current",
  "_CMDLINE": "/usr/bin/dockerd-current --add-runtime docker-runc=/usr/libexec/docker/docker-runc-current --default-runtime=docker-runc --exec-opt native.cgroupdriver=systemd --userland-proxy-path=/usr/libexec/docker/docker-proxy-current --init-path=/usr/libexec/docker/docker-init-current --seccomp-profile=/etc/docker/seccomp.json --selinux-enabled --log-driver=journald --signature-verification=false --storage-driver overlay2",
  "_CAP_EFFECTIVE": "1fffffffff",
  "_SYSTEMD_CGROUP": "/system.slice/docker.service",
  "_SYSTEMD_UNIT": "docker.service",
  "_SYSTEMD_SLICE": "system.slice",
  "_SELINUX_CONTEXT": "system_u:system_r:container_runtime_t:s0",
  "_MACHINE_ID": "b671b9b84b830619f4d211595b94cb0d",
  "_HOSTNAME": "cp1",
  "MESSAGE": "2018-09-09 09:35:58.797 [INFO][62] health.go 150: Overall health summary=&health.HealthReport{Live:true, Ready:true}",
  "_SOURCE_REALTIME_TIMESTAMP": "1536485758803706"
}
```

jouranalctl (1) の man を見ると `journalctl [OPTIONS...] [MATCHES...]` と `MATCHES...` にフィルタリング条件を渡せるとあります。 別の項目に対して複数の条件を指定すると両方にマッチしたログが出力されます

```
journalctl _SYSTEMD_UNIT=avahi-daemon.service _PID=28097
```

同じ項目に対して複数の条件をしていすると、どちらかにマッチしたログが出力されます

```
journalctl _SYSTEMD_UNIT=avahi-daemon.service _SYSTEMD_UNIT=dbus.service
```

`+` をセパレータとして使うと OR でつなげることになります。次の例では PID が 28097 でかつ systemd の unit が avahi-daemon のログと dbus (PID は関係ない) のログが出力されます。

```
journalctl _SYSTEMD_UNIT=avahi-daemon.service _PID=28097 + _SYSTEMD_UNIT=dbus.service
```

というわけで、上の docker のログの例では `CONTAINER_ID` や `CONTAINER_NAME` などでフィルタリングすると特定の docker のログが確認できます。
