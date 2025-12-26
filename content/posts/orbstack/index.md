---
title: "Orbstack を Docker Desktop の代わりに使う"
date: 2023-04-04T22:17:51+09:00
draft: false
tags: ["Docker", "orbstack"]
---

## きっかけ

{{< x user="yteraoka" id="1613544910606716929" >}}

で、[orbstack](https://orbstack.dev/) っていう formula が追加されてるのを見てほー、そんなものが、ということで試してみる。

```
$ brew info orbstack
==> orbstack: 0.6.0_1088 (auto_updates)
https://orbstack.dev/
/Users/teraoka/.homebrew/Caskroom/orbstack/0.5.2_1012 (122B)
From: https://github.com/Homebrew/homebrew-cask/blob/HEAD/Casks/orbstack.rb
==> Name
OrbStack
==> Description
Replacement for Docker Desktop
==> Artifacts
OrbStack.app (App)
/Applications/OrbStack.app/Contents/MacOS/bin/orb (Binary)
/Applications/OrbStack.app/Contents/MacOS/bin/orbctl (Binary)
==> Caveats
Open the OrbStack app to finish setup.

==> Analytics
install: 3 (30 days), 3 (90 days), 3 (365 days)
```

## 環境

Intel Mac です。

```
$ sw_vers
ProductName:        macOS
ProductVersion:     13.3
BuildVersion:       22E252
```


## Install

```
brew install orbstack
```

管理者権限を求められますが、キャンセルしても大丈夫。`/var/run/docker.sock` へのリンクが作成されないだけで docker の context は作られるので問題ありません。

{{< figure src="guihelper.png" >}}

```
$ orbctl status
Running
```


## Docker

`orbstack` という context が作成され、デフォルトになっているので docker コマンドがもう使える状態です。

```
$ docker context ls
NAME           DESCRIPTION                               DOCKER ENDPOINT                                        ERROR
default        Current DOCKER_HOST based configuration   unix:///var/run/docker.sock
lima-default                                             unix:///Users/teraoka/.lima/default/sock/docker.sock
orbstack *     OrbStack                                  unix:///Users/teraoka/.orbstack/run/docker.sock
```

```
$ docker info
Client:
 Context:    orbstack
 Debug Mode: false
 Plugins:
  buildx: Docker Buildx (Docker Inc.)
    Version:  v0.10.4
    Path:     /Users/teraoka/.docker/cli-plugins/docker-buildx
  compose: Docker Compose (Docker Inc.)
    Version:  v2.17.2
    Path:     /Users/teraoka/.docker/cli-plugins/docker-compose

Server:
 Containers: 0
  Running: 0
  Paused: 0
  Stopped: 0
 Images: 0
 Server Version: 23.0.2
 Storage Driver: overlay2
  Backing Filesystem: btrfs
  Supports d_type: true
  Using metacopy: false
  Native Overlay Diff: true
  userxattr: false
 Logging Driver: json-file
 Cgroup Driver: cgroupfs
 Cgroup Version: 2
 Plugins:
  Volume: local
  Network: bridge host ipvlan macvlan null overlay
  Log: awslogs fluentd gcplogs gelf journald json-file local logentries splunk syslog
 Swarm: inactive
 Runtimes: io.containerd.runc.v2 runc
 Default Runtime: runc
 Init Binary: docker-init
 containerd version: 1fbd70374134b891f97ce19c70b6e50c7b9f4e0d
 runc version: 5fd4c4d144137e991c4acebb2146ab1483a97925
 init version:
 Security Options:
  seccomp
   Profile: builtin
  cgroupns
 Kernel Version: 6.1.22-orbstack-00101-gc15df7c38de4
 Operating System: Alpine Linux edge (containerized)
 OSType: linux
 Architecture: x86_64
 CPUs: 12
 Total Memory: 5.134GiB
 Name: docker
 ID: 6f96abe2-3dd1-4148-b0ce-28a8e0ad8860
 Docker Root Dir: /var/lib/docker
 Debug Mode: false
 Registry: https://index.docker.io/v1/
 Experimental: false
 Insecure Registries:
  127.0.0.0/8
 Live Restore Enabled: false
```

macOS 側の volume をマウントして読み書きすることも可能だし

```
$ docker run -it --rm -v $(pwd):/work ubuntu:latest bash
Unable to find image 'ubuntu:latest' locally
latest: Pulling from library/ubuntu
2ab09b027e7f: Pull complete
Digest: sha256:67211c14fa74f070d27cc59d69a7fa9aeff8e28ea118ef3babc295a0428a6d21
Status: Downloaded newer image for ubuntu:latest
root@fc9ad9b3a3ef:/#
```

TCP も UDP も転送が可能です。[Docker on Lima](/2022/01/docker-on-lima/) では TCP しか転送できない。

```
$ docker run -d -p 8053:53/tcp -p 8053:53/udp --cap-add=NET_ADMIN \
 --name dns andyshinn/dnsmasq
Unable to find image 'andyshinn/dnsmasq:latest' locally
latest: Pulling from andyshinn/dnsmasq
4c0d98bf9879: Pull complete
7d2bee783f4f: Pull complete
Digest: sha256:4fea93e30551a5971e8934c4b47f70d293c2774a9c7dae1edb1a663e2b2402a3
Status: Downloaded newer image for andyshinn/dnsmasq:latest
1726157a2ed51e687eb07ff4876969bb353e6b0f972321dc8c150ebabe036b5c
```

## Disk IO 性能

[Lima の vz で試した](/2022/12/lima-vz/) 時の git の tarball 展開をやってみる。

```
docker run --rm -it -v $(pwd):/host debian:11.6 bash
apt-get update
apt-get install -y curl
curl -LO https://github.com/git/git/archive/refs/tags/v2.39.0.tar.gz
gunzip v2.39.0.tar.gz
cd /host
time tar -x --no-same-owner -f ../v2.39.0.tar
rm -fr git-2.39.0
time tar -x --no-same-owner -f ../v2.39.0.tar
rm -fr git-2.39.0
time tar -x --no-same-owner -f ../v2.39.0.tar
rm -fr git-2.39.0
```

### 結果

Lima で最速だった VZ + virtiofs よりちょっとだけ遅い？

| vmType   | mountType | time     |
|----------|-----------|---------:|
| VZ       | virtiofs  | 0m6.130s |
| VZ       | virtiofs  | 0m5.259s |
| VZ       | virtiofs  | 0m5.370s |
| orbstack | ?         | 0m9.881s |
| orbstack | ?         | 0m7.354s |
| orbstack | ?         | 0m7.720s |


## docker daemon の設定

`~/.orbstack/config/docker.json` で設定可能っぽい。
`orb config docker` コマンドを実行するとエディタが立ち上がる。

編集したら `orb restart docker` で docker daemon を restart させる。


## Intel (x86) emulation

Apple Silicon の mac では Rosetta でエミュレーションされるらしい。
まだ試せてない。


## Virtual Machine としての利用

Lima と同様に Linux VM としても使用可能

[Linux machines](https://docs.orbstack.dev/machines/)

2023年04月時点では 15 の Distribution をサポートしているようです。

例えば次のようにすれば ALMA Linux 8 環境が作られます。

```
orb create alma:8
```

```
$ orbctl list
NAME  STATE    DISTRO     VERSION  ARCH
----  -----    ------     -------  ----
alma  running  almalinux  8        amd64
```

この状態で `orb` と実行するだけで VM の中に入れます。

```
$ orb
[teraoka@alma teraoka]$ uname -a
Linux alma 6.1.22-orbstack-00101-gc15df7c38de4 #62 SMP Thu Mar 30 08:54:33 PDT 2023 x86_64 x86_64 x86_64 GNU/Linux
[teraoka@alma teraoka]$ cat /etc/os-release
NAME="AlmaLinux"
VERSION="8.7 (Stone Smilodon)"
ID="almalinux"
ID_LIKE="rhel centos fedora"
VERSION_ID="8.7"
PLATFORM_ID="platform:el8"
PRETTY_NAME="AlmaLinux 8.7 (Stone Smilodon)"
ANSI_COLOR="0;34"
LOGO="fedora-logo-icon"
CPE_NAME="cpe:/o:almalinux:almalinux:8::baseos"
HOME_URL="https://almalinux.org/"
DOCUMENTATION_URL="https://wiki.almalinux.org/"
BUG_REPORT_URL="https://bugs.almalinux.org/"

ALMALINUX_MANTISBT_PROJECT="AlmaLinux-8"
ALMALINUX_MANTISBT_PROJECT_VERSION="8.7"
REDHAT_SUPPORT_PRODUCT="AlmaLinux"
REDHAT_SUPPORT_PRODUCT_VERSION="8.7"
```

Ubuntu マシンも追加してみます

```
orb create ubuntu:jammy
```

作成されました。

```
$ orbctl list
NAME    STATE    DISTRO     VERSION  ARCH
----    -----    ------     -------  ----
alma    running  almalinux  8        amd64
ubuntu  running  ubuntu     jammy    amd64
```

この状態では default が alma のままなので

```
$ orbctl default
alma
```

default を ubuntu に変更します

```
orbctl default ubuntu
```

これで、`orb` コマンドでのアクセス先が ubuntu に変わりました。

```
$ orb
To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

teraoka@ubuntu:/Users/teraoka$ uname -a
Linux ubuntu 6.1.22-orbstack-00101-gc15df7c38de4 #62 SMP Thu Mar 30 08:54:33 PDT 2023 x86_64 x86_64 x86_64 GNU/Linux
teraoka@ubuntu:/Users/teraoka$ cat /etc/os-release
PRETTY_NAME="Ubuntu 22.04.2 LTS"
NAME="Ubuntu"
VERSION_ID="22.04"
VERSION="22.04.2 LTS (Jammy Jellyfish)"
VERSION_CODENAME=jammy
ID=ubuntu
ID_LIKE=debian
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
UBUNTU_CODENAME=jammy
teraoka@ubuntu:/Users/teraoka$
```

`orb` コマンドに `-m` で対象 VM を指定することが可能でした。`-u` でユーザー名も指定可能で `-u root` とすれば root でアクセスできます。

```
orb -m alma
```

ちょっと古い ubuntu を追加

```
orb create ubuntu:focal ubuntu-focal
```

```
$ orbctl list
NAME          STATE    DISTRO     VERSION  ARCH
----          -----    ------     -------  ----
alma          running  almalinux  8        amd64
ubuntu        running  ubuntu     jammy    amd64
ubuntu-focal  running  ubuntu     focal    amd64
```

```
teraoka@ubuntu-focal:/Users/teraoka$ uname -r
6.1.22-orbstack-00101-gc15df7c38de4
```

どれもこれも `uname -r` の値が同じですね。ということで、これは VirtualBox とかとは違って kernel が共有されていそうです。
[LXD らしい](https://docs.orbstack.dev/architecture#security)です。

### mac 側とのファイル共有

`~/OrbStack` 配下に各 VM のファイルシステムが見えます。

```
$ ls ~/OrbStack
alma  docker  ubuntu  ubuntu-focal
```

VM 内からは `/mnt/mac` で mac 側のファイルシステム全体にアクセスできます。これはセキュリティ的にはどうなっているのかな？

mac 側の `~/OrbStack` にあったファイルが VM 内では `/mnt/machines` にありそうな感じ、そして btrfs

```
[teraoka@alma teraoka]$ mount | grep machines
nfstmp on /mnt/machines type tmpfs (ro,noatime,mode=700)
/dev/vdb1 on /mnt/machines/alma type btrfs (rw,noatime,nodatasum,nodatacow,ssd,discard=async,space_cache=v2,subvolid=5,subvol=/)
/dev/vdb1 on /mnt/machines/ubuntu type btrfs (rw,noatime,nodatasum,nodatacow,ssd,discard=async,space_cache=v2,subvolid=5,subvol=/)
/dev/vdb1 on /mnt/machines/ubuntu-focal type btrfs (rw,noatime,nodatasum,nodatacow,ssd,discard=async,space_cache=v2,subvolid=5,subvol=/)
```

- [File sharing](https://docs.orbstack.dev/machines/file-sharing)

### mac コマンド

VM 内には `/opt/orbstack-guest/bin` に [mac](https://docs.orbstack.dev/machines/commands#mac) コマンドがあり `mac open ~/` などとするとファインダーでそのディレクトリを開くことができる。

```
[teraoka@alma teraoka]$ ls -l /opt/orbstack-guest/bin
total 3580
lrwxrwxrwx 1 root root      30 Apr  3 16:15 code -> /opt/orbstack-guest/bin/macctl
lrwxrwxrwx 1 root root      30 Apr  3 16:15 mac -> /opt/orbstack-guest/bin/macctl
-rwxr-xr-x 1 root root 6356992 Apr  3 16:15 macctl
lrwxrwxrwx 1 root root      30 Apr  3 16:15 orb -> /opt/orbstack-guest/bin/macctl
lrwxrwxrwx 1 root root      30 Apr  3 16:15 orbctl -> /opt/orbstack-guest/bin/macctl
lrwxrwxrwx 1 root root      30 Apr  3 16:15 osascript -> /opt/orbstack-guest/bin/macctl
```

## VM 間、VM と mac、VM と docker 間の通信

- 各 VM 間は eth0 についた IP アドレスで通信可能 ([Connecting between machines](https://docs.orbstack.dev/machines/network#connecting-between-machines))
- VM から mac に対しては `host.internal` というホスト名でアクセス可能 ([Connecting to servers on Mac](https://docs.orbstack.dev/machines/network#connecting-to-servers-on-mac))
- VM から docker に対しては `docker.internal` というホスト名でアクセス可能 ([Connecting to Docker containers](https://docs.orbstack.dev/machines/network#connecting-to-docker-containers))


## Is OrbStack free?

- [Is OrbStack free?](https://docs.orbstack.dev/faq#free)

beta の間は無料だけど、将来的には有償になるみたい。
