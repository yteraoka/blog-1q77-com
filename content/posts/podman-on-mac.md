---
title: 'mac で podman'
date: Thu, 23 Sep 2021 14:20:51 +0000
draft: false
tags: ['Docker', 'Docker', 'Podman']
---

Docker Desktop 代替シリーズ第三部、Podman です。([第一部 minkikube 編](/2021/09/replace-docker-desktop-with-minikube/)、[第二部 Lima + nerdctl 編](/2021/09/lima/))

Podman については [Red Hat さんのブログ](https://rheb.hatenablog.com/archive/category/Podman)が大変参考になります。

今回の Docker 社によるライセンス周りの変更が発表されるよりだいぶ前に [How to replace Docker with Podman on a Mac](https://www.redhat.com/sysadmin/replace-docker-podman-macos) という記事もありました。Podman は Linux 上で稼働する daemon とそのクライアントという構成となっており、Windows と Mac にはクライアントしかありません。この時の記事では Vagrant を使って Linux 仮想サーバーを起動させるという処理を macOS app にしようという内容でした。現在は `podman machine` というサブコマンドで仮想サーバーを起動させることができるようになっているようです。それでは試してみましょう。

podman のインストール
--------------

```
$ brew install podman
```

これにより `podman`, `podman-remote`, `gvproxy` コマンドが `$(brew --prefix)/bin/` にリンクされていました。

podman machine の起動
------------------

### podman machine init

`podman machine init` で初期設定。初回は仮想マシンのイメージのダウンロードも行われます。

```
$ podman machine init
Downloading VM image: fedora-coreos-34.20210919.1.0-qemu.x86_64.qcow2.xz [=>------------------------] 52.7MiB / 598.3MiB
Downloading VM image: fedora-coreos-34.20210919.1.0-qemu.x86_64.qcow2.xz: done  
Extracting compressed file
```

ホームディレクトリ配下、`~/.local/share/containers/podman/machine/qemu/` に仮想マシンのイメージファイル (qcow2) が配置されています。

```
$ ls -lh ~/.local/share/containers/podman/machine/qemu
total 2.1G
-rw-r--r-- 1 teraoka staff 599M Sep 23 18:05 fedora-coreos-34.20210919.1.0-qemu.x86_64.qcow2.xz
-rw------- 1 teraoka staff 1.5G Sep 23 18:06 podman-machine-default_fedora-coreos-34.20210919.1.0-qemu.x86_64.qcow2
```

### podman machine start

`podman machine start` で仮想マシンを起動させます。

```
$ podman machine start
INFO[0000] waiting for clients...
INFO[0000] listening tcp://0.0.0.0:7777
INFO[0000] new connection from  to /var/folders/nd/8mk6834s31g8dymd1_9pnqq00000gn/T/podman/qemu_podman-machine-default.sock
Waiting for VM ...
qemu-system-x86_64: warning: host doesn't support requested feature: CPUID.80000001H:ECX.svm [bit 2]
```

`podman machine ls` コマンドで仮想マシンの状態を確認できます。

```
$ podman machine ls
NAME                     VM TYPE     CREATED        LAST UP
podman-machine-default*  qemu        7 minutes ago  Currently running
```

### podman machine ssh

`podman machine ssh` で仮想マシンに ssh でログインできます。

```
$ podman machine ssh
Connecting to vm podman-machine-default. To close connection, use `~.` or `exit`
Warning: Permanently added '[localhost]:54552' (ECDSA) to the list of known hosts.
Fedora CoreOS 34.20210919.1.0
Tracker: https://github.com/coreos/fedora-coreos-tracker
Discuss: https://discussion.fedoraproject.org/c/server/coreos/

[core@localhost ~]$
```

これまでの流れで hosts は確認しちゃいますね。ホスト(mac)へアクセスするための名前は設定されていないようです。

```
[core@localhost ~]$ cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
```

lima や minikube (virtualbox) の仮想マシンでは default router となっているアドレスにアクセスすることでホストにアクセスできたので、podman machine でも同様かな？と思って 192.168.127.1 にアクセスしてみましたがダメでした。(ホスト(mac)のIPアドレスを指定すればアクセスはできるんですけど、DHCP なので場所とかによって変わってしまうんですよね)

```
[core@localhost ~]$ ip a s
1: lo: mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: enp0s2: mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 5a:94:ef:e4:0c:ee brd ff:ff:ff:ff:ff:ff
    inet 192.168.127.2/24 brd 192.168.127.255 scope global dynamic noprefixroute enp0s2
       valid_lft 3256sec preferred_lft 3256sec
    inet6 fe80::7a18:f299:cead:4ecc/64 scope link noprefixroute 
       valid_lft forever preferred_lft forever

[core@localhost ~]$ ip r
default via 192.168.127.1 dev enp0s2 proto dhcp metric 100 
192.168.127.0/24 dev enp0s2 proto kernel scope link src 192.168.127.2 metric 100 
```

ところで、なんでしょう？ この謎のメッセージは？ curl じゃない何かがエラーメッセージを出しています。 tcp の proxy をするやつがいそうです。

```
$ curl http://192.168.127.1:8080/
ERRO[6288] net.Dial() = dial tcp 192.168.127.1:8080: connect: operation timed out 
ERRO[6322] net.Dial() = dial tcp 192.168.127.1:8080: connect: operation timed out 
curl: (7) Failed to connect to 192.168.127.1 port 8080: Connection refused
```

curl の connect timeout を 1 秒にしてみる

```
[core@localhost ~]$ **curl --connect-timeout 1 http://192.168.127.1:8080/**
curl: (28) Connection timed out after 1006 milliseconds
[core@localhost ~]$ ERRO[6616] net.Dial() = dial tcp 192.168.127.1:8080: connect: operation timed out 
```

curl が Go で書かれた別物というわけではなさそうです。

```
[core@localhost ~]$ curl --version
curl 7.76.1 (x86_64-redhat-linux-gnu) libcurl/7.76.1 OpenSSL/1.1.1l-fips zlib/1.2.11 brotli/1.0.9 libidn2/2.3.2 libpsl/0.21.1 (+libidn2/2.3.0) libssh/0.9.5/openssl/zlib nghttp2/1.43.0
Release-Date: 2021-04-14
Protocols: dict file ftp ftps gopher gophers http https imap imaps ldap ldaps mqtt pop3 pop3s rtsp scp sftp smb smbs smtp smtps telnet tftp 
Features: alt-svc AsynchDNS brotli GSS-API HTTP2 HTTPS-proxy IDN IPv6 Kerberos Largefile libz NTLM NTLM_WB PSL SPNEGO SSL TLS-SRP UnixSockets
```

どうやら `podman machine start` で起動した際に `listening tcp://0.0.0.0:7777` と表示されていたのは **gvproxy** のログのようですね。これを起動した terminal で `podman machine ssh` してたのでそこに出てきただけで仮想マシン内ででたメッセージではありませんでした。

mac 側で gvproxy プロセスを確認してみる。

```
$ pgrep -lf gvproxy
52708 /Users/teraoka/.homebrew/bin/gvproxy -listen tcp://0.0.0.0:7777 -listen-qemu unix:///var/folders/nd/8mk6834s31g8dymd1_9pnqq00000gn/T/podman/qemu_podman-machine-default.sock -pid-file /var/folders/nd/8mk6834s31g8dymd1_9pnqq00000gn/T/podman/podman-machine-default.pid -ssh-port 54552
```

podman machine ssh した時に localhost の 54552 ポートに接続しようとしているのもこの gvproxy が中継しているようですね。`podman run` の `-p` で port を expose すると mac から localhost でもアクセスできるようにしてくれているのがこの gvproxy らしいんですが、仮想マシンからの outbound にも絡んでいるとは... (嬉しくない)

仮想マシンのリソース設定
------------

デフォルトでは 2GB のメモリと 1 コアの CPU が割り当てられてました。

```
[core@localhost ~]$ free -h
               total        used        free      shared  buff/cache   available
Mem:           1.9Gi       128Mi       1.6Gi       5.0Mi       208Mi       1.7Gi
Swap:             0B          0B          0B
[core@localhost ~]$ **lscpu**
Architecture:                    x86_64
CPU op-mode(s):                  32-bit, 64-bit
Byte Order:                      Little Endian
Address sizes:                   40 bits physical, 48 bits virtual
CPU(s):                          1
On-line CPU(s) list:             0
Thread(s) per core:              1
Core(s) per socket:              1
Socket(s):                       1
NUMA node(s):                    1
Vendor ID:                       GenuineIntel
CPU family:                      15
Model:                           107
Model name:                      QEMU Virtual CPU version 2.5+
Stepping:                        1
CPU MHz:                         2591.776
BogoMIPS:                        5183.55
L1d cache:                       32 KiB
L1i cache:                       32 KiB
L2 cache:                        4 MiB
L3 cache:                        16 MiB
NUMA node0 CPU(s):               0
Vulnerability Itlb multihit:     KVM: Mitigation: VMX unsupported
Vulnerability L1tf:              Mitigation; PTE Inversion
Vulnerability Mds:               Vulnerable: Clear CPU buffers attempted, no microcode; SMT Host state unknown
Vulnerability Meltdown:          Mitigation; PTI
Vulnerability Spec store bypass: Vulnerable
Vulnerability Spectre v1:        Mitigation; usercopy/swapgs barriers and __user pointer sanitization
Vulnerability Spectre v2:        Mitigation; Full generic retpoline, STIBP disabled, RSB filling
Vulnerability Srbds:             Not affected
Vulnerability Tsx async abort:   Not affected
Flags:                           fpu de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr ss
                                 e sse2 syscall nx lm constant_tsc nopl xtopology cpuid pni cx16 hypervisor lahf_lm pti
```

CPU やメモリのサイズを調整するには `podman machine init` 時に設定する必要があるようです。

```
$ podman machine init --help
Initialize a virtual machine

Description:
  initialize a virtual machine 

Usage:
  podman machine init [options] [NAME]

Examples:
  podman machine init myvm

Options:
      --cpus uint              Number of CPUs. The default is 1. (default 1)
      --disk-size uint         Disk size in GB (default 10)
      --ignition-path string   Path to ignition file
      --image-path string      Path to qcow image
  -m, --memory uint            Memory (in MB) (default 2048)
```

```
$ podman machine init --cpus 2 --disk-size 5 --memory 1024 vm2
Extracting compressed file
```

```
$ podman machine ls
NAME                     VM TYPE     CREATED             LAST UP
podman-machine-default*  qemu        4 hours ago         Currently running
vm2                      qemu        About a minute ago  About a minute ago
```

仮想マシンを複数作成できるから同時に起動させることもできるのかな？と思ったけど同時に起動させられるのは1つだけのようです。

```
$ podman machine start vm2
Error: cannot start VM vm2. VM podman-machine-default is currently running: only one VM can be active at a time
```

仮想マシンの設定は `~/.config/containers/podman/machine/` 配下に作成されていました。

```
$ find .config/containers/podman/machine
.config/containers/podman/machine
.config/containers/podman/machine/qemu
.config/containers/podman/machine/qemu/podman-machine-default.json
.config/containers/podman/machine/qemu/podman-machine-default.ign
.config/containers/podman/machine/qemu/vm2.json
.config/containers/podman/machine/qemu/vm2.ign
```

podman run
----------

コンテナを実行してみます。

まずは image を pull してみる。

```
$ podman pull nginx:alpine
Error: failed to parse "X-Registry-Auth" header for /v3.3.1/libpod/images/pull?alltags=false&arch=&authfile=&os=&password=&policy=always&quiet=false&reference=nginx%3Aalpine&username=&variant=: error storing credentials in temporary auth file (server: "https://index.docker.io/v1/", user: ""): key https://index.docker.io/v1/ contains http[s]:// prefix
```

うーむ、~/.docker/config.json が悪さをしているらしいので rename して再チャレンジ。

ちなみにこの時の config.json は次のようになっていました。 ([containers-auth.json(5)](https://github.com/containers/image/blob/main/docs/containers-auth.json.5.md))

```json
{
	"auths": {
		"https://index.docker.io/v1/": {}
	},
	"credsStore": "osxkeychain"
}

```

```
$ podman pull nginx:alpine
Error: short-name resolution enforced but cannot prompt without a TTY
```

エラーメッセージが変わった。short-name の解決したいけど TTY が使えないとダメだよと言ってるみたいなので docker.io もつけてみる。 (podman は image のホスト名部分を省略した場合にリストを順に検索してくれる設定があるらしい。未調査)

```
$ podman pull docker.io/nginx:alpine
Trying to pull docker.io/library/nginx:alpine...
Getting image source signatures
Copying blob sha256:61074acc7dd227cfbeaf719f9b5cdfb64711bc6b60b3865c7b886b7099c15d15
Copying blob sha256:a0d0a0d46f8b52473982a3c466318f479767577551a53ffc9074c9fa7035982e
Copying blob sha256:4dd4efe90939ab5711aaf5fcd9fd8feb34307bab48ba93030e8b845f8312ed8e
Copying blob sha256:c1368e94e1ec563b31c3fb1fea02c9fbdc4c79a95e9ad0cac6df29c228ee2df3
Copying blob sha256:3e72c40d0ff43c52c5cc37713b75053e8cb5baea8e137a784d480123814982a2
Copying blob sha256:969825a5ca61c8320c63ff9ce0e8b24b83442503d79c5940ba4e2f0bd9e34df8
Copying blob sha256:969825a5ca61c8320c63ff9ce0e8b24b83442503d79c5940ba4e2f0bd9e34df8
Copying blob sha256:3e72c40d0ff43c52c5cc37713b75053e8cb5baea8e137a784d480123814982a2
Copying blob sha256:61074acc7dd227cfbeaf719f9b5cdfb64711bc6b60b3865c7b886b7099c15d15
Copying blob sha256:4dd4efe90939ab5711aaf5fcd9fd8feb34307bab48ba93030e8b845f8312ed8e
Copying blob sha256:c1368e94e1ec563b31c3fb1fea02c9fbdc4c79a95e9ad0cac6df29c228ee2df3
Copying blob sha256:a0d0a0d46f8b52473982a3c466318f479767577551a53ffc9074c9fa7035982e
Copying config sha256:513f9a9d8748b25cdb0ec6f16b4523af7bba216a6bf0f43f70af75b4cf7cb780
Writing manifest to image destination
Storing signatures
513f9a9d8748b25cdb0ec6f16b4523af7bba216a6bf0f43f70af75b4cf7cb780
```

TTY 問題ですが、仮想マシン内で podman を実行した場合は次のような選択 UI になります。

```
[core@localhost ~]$ podman pull nginx:latest
? Please select an image: 
  ▸ registry.fedoraproject.org/nginx:latest
    registry.access.redhat.com/nginx:latest
    docker.io/library/nginx:latest
    quay.io/nginx:latest
```

この registry の選択肢は仮想マシン側の `/etc/containers/registries.conf` に定義されていました。 ([containers-registries.conf(5)](https://github.com/containers/image/blob/main/docs/containers-registries.conf.5.md))  
この設定はホスト (mac) 側の ~/.config/containers/registries.conf に書くこともできます。次のように docker.io だけにしておけば docker の場合と同じように動作します。 ホスト側のファイルで制御できるというのは間違いでした。debian のイメージで試したのですが、実はこれは下で紹介する alias によって pull できただけでした。仮想マシン内の `~/.config/containers/registries.conf` に書いてください。

```
[core@localhost ~]$ cat ~/.config/containers/registries.conf
unqualified-search-registries = ["docker.io"]
```

@tnk4on さんから情報をいただきました。short-name の選択は仮想マシン側でファイルに cache されるそうです。`~/.cache/containers/short-name-aliases.conf` にありました。

```
[core@localhost containers]$ cat ~/.cache/containers/short-name-aliases.conf
[aliases]
  nginx = "docker.io/library/nginx"
```

この状態で pull してみると `Resolved "nginx" as an alias (/var/home/core/.cache/containers/short-name-aliases.conf)` って出力されてました。

```
$ podman pull nginx:1.19.1
Resolved "nginx" as an alias (/var/home/core/.cache/containers/short-name-aliases.conf)
Trying to pull docker.io/library/nginx:1.19.1...
Getting image source signatures
Copying blob sha256:1f1070938ccd20f58e90d4a03e71b859274580306295ec8b68cf39c6d7f1978f
(snip)
Copying blob sha256:c57dd87d0b93cc883c4af602c0a8e1a6bd9083f723fb426432427812fe3c0e31
Copying config sha256:08393e824c32d456ff69aec72c64d1ab63fecdad060ab0e8d3d42640fc3d64c5
Writing manifest to image destination
Storing signatures
08393e824c32d456ff69aec72c64d1ab63fecdad060ab0e8d3d42640fc3d64c5
```

これまた @tnk4on さんからの情報ですが、registries.conf によるレジストリの一覧だけでなく、この　cache のような形式で `/etc/containers/registries.conf.d/000-shortnames.conf` に alias の一覧がありました。 次のようになっていて、ここに列挙されたものは

```
[core@localhost ~]$ head /etc/containers/registries.conf.d/000-shortnames.conf
[aliases]
  # centos
  "centos" = "quay.io/centos/centos"
  # containers
  "skopeo" = "quay.io/skopeo/stable"
  "buildah" = "quay.io/buildah/stable"
  "podman" = "quay.io/podman/stable"
  # docker
  "alpine" = "docker.io/library/alpine"
  "docker" = "docker.io/library/docker"
```

次に **podman run** を試してみる。

podman で特権ポート (1024 未満) は listen できないよというのは知ってるけど試してみる。

```
$ podman run -it -p 80:80 docker.io/nginx:alpine
Error: error preparing container 800d78d0aecb23d5838d0cce77ebe7fa4ef4209c01a97d13e4979bcad387634f for attach: rootlessport cannot expose privileged port 80, you can add 'net.ipv4.ip_unprivileged_port_start=80' to /etc/sysctl.conf (currently 1024), or choose a larger port number (>= 1024): listen tcp 0.0.0.0:80: bind: permission denied
```

事前の情報通りエラーになった。次は `-p 8080:80` で試す。

```
$ podman run -it -p 8080:80 docker.io/nginx:alpine
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
10-listen-on-ipv6-by-default.sh: info: Getting the checksum of /etc/nginx/conf.d/default.conf
10-listen-on-ipv6-by-default.sh: info: Enabled listen on IPv6 in /etc/nginx/conf.d/default.conf
/docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
/docker-entrypoint.sh: Configuration complete; ready for start up
2021/09/23 12:56:00 [notice] 1#1: using the "epoll" event method
2021/09/23 12:56:00 [notice] 1#1: nginx/1.21.3
2021/09/23 12:56:00 [notice] 1#1: built by gcc 10.3.1 20210424 (Alpine 10.3.1_git20210424) 
2021/09/23 12:56:00 [notice] 1#1: OS: Linux 5.13.16-200.fc34.x86_64
2021/09/23 12:56:00 [notice] 1#1: getrlimit(RLIMIT_NOFILE): 524288:524288
2021/09/23 12:56:00 [notice] 1#1: start worker processes
2021/09/23 12:56:00 [notice] 1#1: start worker process 27
```

podman の仮想マシン内であれば `curl http://localhost:8080/` でアクセスできましたが、ホストの mac からは connection refused でした。冒頭で紹介した[ブログ](https://rheb.hatenablog.com/entry/podman-machine#%E8%87%AA%E5%8B%95%E3%83%9D%E3%83%BC%E3%83%88%E3%83%95%E3%82%A9%E3%83%AF%E3%83%BC%E3%83%89)を確認すると、podman 3.3.1 では既知の問題らしいです。

> [Note:] Podman v3.3.1時点でこの機能には不具合があり、上記のように--network bridgeをつけるか、他にも事前にpodman network createで作成したネットワークを指定する方法やcontainers.confファイルの[containers]セクションにrootless_networking = "cni"を追加する、などのワークアラウンドがあります。 この不具合については私の上げた下記Issue（すでにClose済み）で対応がなされており、次のバージョン（v3.3.2？）に修正が適用される見込みです。

でも仮想マシン内の `.config/containers/containers.conf` には `rootless_networking = "cni"` が最初から入ってたんだけどなあ。

```
[core@localhost ~]$ cat .config/containers/containers.conf
[containers]
netns="bridge"
rootless_networking="cni"

```

podman run に `--network bridge` をつけたら mac からも localhost でアクセスできました。

```
$ curl -s http://localhost:8080/
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

ホスト (mac) 側にも containers.conf がありました。そして、こっちの `[containers]` に `rootless_networking = "cni"` を書けば `--network bridge` 指定なしで mac から localhost でアクセスできました。

```
$ cat ~/.config/containers/containers.conf
[containers]
  log_size_max = -1
  pids_limit = 2048
  userns_size = 65536

[engine]
  image_parallel_copies = 0
  num_locks = 2048
  active_service = "podman-machine-default"
  stop_timeout = 10
  chown_copied_files = false
  [engine.service_destinations]
    [engine.service_destinations.podman-machine-default]
      uri = "ssh://core@localhost:54552/run/user/1000/podman/podman.sock"
      identity = "/Users/teraoka/.ssh/podman-machine-default"
    [engine.service_destinations.podman-machine-default-root]
      uri = "ssh://root@localhost:54552/run/podman/podman.sock"
      identity = "/Users/teraoka/.ssh/podman-machine-default"
    [engine.service_destinations.vm2]
      uri = "ssh://core@localhost:55656/run/user/1000/podman/podman.sock"
      identity = "/Users/teraoka/.ssh/vm2"
    [engine.service_destinations.vm2-root]
      uri = "ssh://root@localhost:55656/run/podman/podman.sock"
      identity = "/Users/teraoka/.ssh/vm2"

[network]

[secrets]

```

podman build
------------

コンテナイメージをビルドしてみる。

手元にあったこの Dockerfile で試してみます。

```
FROM fluent/fluentd:v1.12.4-debian-1.0
USER root
RUN fluent-gem install fluent-plugin-kinesis -v 3.4.0
RUN fluent-gem install fluent-plugin-s3
COPY fluent.conf /fluentd/etc/fluent.conf
USER fluent

```

```
$ podman build .
STEP 1/6: FROM fluent/fluentd:v1.12.4-debian-1.0
Error: error creating build container: short-name resolution enforced but cannot prompt without a TTY
```

ここでも FROM の image に docker.io を足す必要がありました。

```
FROM docker.io/fluent/fluentd:v1.12.4-debian-1.0
USER root
RUN fluent-gem install fluent-plugin-kinesis -v 3.4.0
RUN fluent-gem install fluent-plugin-s3
COPY fluent.conf /fluentd/etc/fluent.conf
USER fluent
```

これで build はできました。

podman push
-----------

docker hub に push するためにはログインが必要です。`podman login docker.io` でログインできました。認証情報は `~/.config/containers/auth.json` に保存されました。

```
$ cat ~/.config/containers/auth.json
{
	"auths": {
		"docker.io": {
			"auth": "44Om44O844K244O85ZCNOuimi+OBoeOCg+ODgOODoeOCiA=="
		}
	}
}

```

ボリュームマウント
---------

仮想マシン上のディレクトりをマウントすることは可能です。

```
$ podman run -it -v /usr:/work --privileged docker.io/ubuntu
```

しかし、mac 側のディレクトリはマウントさせられません。Docker Desktop のように仮想マシンレイヤーを意識せずにマウントさせられるようになることを期待。

ちなみに、上記の ubuntu の実行ですが、root で実行するコンテナだからか `--privileged` が必要でした。また、port-forward のための `rootless_networking = "cni"` が書いてあるとエラーになりました。

```
$ podman run -it -v /usr:/work --privileged docker.io/ubuntu
Error: error preparing container 98a665c8090d1693a963b7da46c5dfc0337d060f5010def610a9bad5f312ec8a for attach: error configuring network namespace for container 98a665c8090d1693a963b7da46c5dfc0337d060f5010def610a9bad5f312ec8a: error adding pod agitated_wiles_agitated_wiles to CNI network "podman": unexpected end of JSON input
```

こちらも @tnk4on からの情報で、これは podman machine のバグで、すでにアップストリームでは修正されているそうです。([tweet](https://twitter.com/tnk4on/status/1441223276211015685?s=20))

podman-compose
--------------

試していませんが docker-compose が必要な場合は Python で書かれた [podman-compose](https://github.com/containers/podman-compose) というものが使えるようです。

alias
-----

shell の alias で docker=podman とすれば、ほぼそのまま使えると思います。

まとめ
---

イメージを build するだけなら問題なさそうですが、ローカルでの開発用だとまだツラそう。今後に期待
