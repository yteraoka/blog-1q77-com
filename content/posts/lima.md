---
title: 'Lima で nerdctl'
date: Mon, 20 Sep 2021 01:58:10 +0900
draft: false
tags: ['Docker', 'Docker']
---

[Docker Desktop の代わりに docker cli + Minikube](/2021/09/replace-docker-desktop-with-minikube/) ってのを試しただけど、Kubernetes は docker を非推奨にしてるし、kubernetes は不要な場合は無駄が多いしなあ... ってことで [lima](https://github.com/lima-vm/lima) も試してみる。

(2021/01/05 追記: [Docker on Lima](/2022/01/docker-on-lima/) も見てね)

Lima は自動のファイル共有、ポートフォワード、containerd をサポートした仮想マシンを提供してくれるツール。Windows subsystem for Linux の mac 版とも言えるとドキュメントに書かれている。

今回は Intel Mac 環境で試しています。M1 Mac の場合は qemu に patch が必要みたいです。

Lima のインストール
------------

[Homebrew](https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/lima.rb) でインストール

```
$ brew install lima
```

Lima Virtual Machine の起動
------------------------

`limactl` コマンドを使う

```
$ limactl
NAME:
   limactl - Lima: Linux virtual machines

USAGE:
   limactl [global options] command [command options] [arguments...]

VERSION:
   0.6.4

COMMANDS:
   start               Start an instance of Lima. If the instance does not exist, open an editor for creating new one, with name "default"
   stop                Stop an instance
   shell               Execute shell in Lima
   copy, cp            Copy files between host and guest
   list, ls            List instances of Lima.
   delete, remove, rm  Delete an instance of Lima.
   validate            Validate yaml files
   prune               Prune garbage objects
   completion          Show shell completion
   help, h             Shows a list of commands or help for one command

GLOBAL OPTIONS:
   --debug        debug mode (default: false)
   --help, -h     show help (default: false)
   --version, -v  print the version (default: false)
```

`limactl start` だけで実行するとインタラクティブなメニュー表示になった。とりあえず "Proceed with the default configuration" で Enter

```
$ limactl start
? Creating an instance "default"  [Use arrows to move, type to filter]
> Proceed with the default configuration
  Open an editor to override the configuration
  Exit
```

nerdctl のダウンロードが始まりました。(GitHub からのダウンロードが遅い...)

```
$ limactl start
? Creating an instance "default" Proceed with the default configuration
INFO[0096] Downloading "https://github.com/containerd/nerdctl/releases/download/v0.11.2/nerdctl-full-0.11.2-linux-amd64.tar.gz" (sha256:27dbb238f9eb248ca68f11b412670db51db84905e3583834400305b2149915f2) 
3.69 MiB / 174.89 MiB [>____________________________________] 2.11% 149.75 KiB/s
```

暇なので関連ファイルを探してみたら `~/.lima` ディレクトリに作成されていました。

```
$ find .lima -type f
.lima/default/lima.yaml
.lima/_config/user
.lima/_config/user.pub
```

`default/lima.yaml` が default というデフォルト仮想マシンの設定ファイルっぽいです。中身は次のようになっていました。ふむふむ、なるほどって感じですね。

```yaml
# ===================================================================== #
# BASIC CONFIGURATION
# ===================================================================== #

# Arch: "default", "x86_64", "aarch64".
# "default" corresponds to the host architecture.
arch: "default"

# An image must support systemd and cloud-init.
# Ubuntu and Fedora are known to work.
# Default: none (must be specified)
images:
  # Try to use a local image first.
  - location: "~/Downloads/hirsute-server-cloudimg-amd64.img"
    arch: "x86_64"
  - location: "~/Downloads/hirsute-server-cloudimg-arm64.img"
    arch: "aarch64"

  # Download the file from the internet when the local file is missing.
  # Hint: run `limactl prune` to invalidate the "current" cache
  - location: "https://cloud-images.ubuntu.com/hirsute/current/hirsute-server-cloudimg-amd64.img"
    arch: "x86_64"
  - location: "https://cloud-images.ubuntu.com/hirsute/current/hirsute-server-cloudimg-arm64.img"
    arch: "aarch64"

# CPUs: if you see performance issues, try limiting cpus to 1.
# Default: 4
cpus: 4

# Memory size
# Default: "4GiB"
memory: "4GiB"

# Disk size
# Default: "100GiB"
disk: "100GiB"

# Expose host directories to the guest, the mount point might be accessible from all UIDs in the guest
# Default: none
mounts:
  - location: "~"
    # CAUTION: `writable` SHOULD be false for the home directory.
    # Setting `writable` to true is possible, but untested and dangerous.
    writable: false
  - location: "/tmp/lima"
    writable: true

ssh:
  # A localhost port of the host. Forwarded to port 22 of the guest.
  # Currently, this port number has to be specified manually.
  # Default: none
  localPort: 60022
  # Load ~/.ssh/*.pub in addition to $LIMA_HOME/_config/user.pub .
  # This option is useful when you want to use other SSH-based
  # applications such as rsync with the Lima instance.
  # If you have an insecure key under ~/.ssh, do not use this option.
  # Default: true
  loadDotSSHPubKeys: true



# ===================================================================== #
# ADVANCED CONFIGURATION
# ===================================================================== #

containerd:
  # Enable system-wide (aka rootful)  containerd and its dependencies (BuildKit, Stargz Snapshotter)
  # Default: false
  system: false
  # Enable user-scoped (aka rootless) containerd and its dependencies
  # Default: true
  user: true

# Provisioning scripts need to be idempotent because they might be called
# multiple times, e.g. when the host VM is being restarted.
# provision:
#   # `system` is executed with the root privilege
#   - mode: system
#     script: |
#       #!/bin/bash
#       set -eux -o pipefail
#       export DEBIAN_FRONTEND=noninteractive
#       apt-get install -y vim
#   # `user` is executed without the root privilege
#   - mode: user
#     script: |
#       #!/bin/bash
#       set -eux -o pipefail
#       cat < ~/.vimrc
#       set number
#       EOF

# probes:
#  # Only `readiness` probes are supported right now.
#  - mode: readiness
#    description: vim to be installed
#    script: |
#       #!/bin/bash
#       set -eux -o pipefail
#       if ! timeout 30s bash -c "until command -v vim; do sleep 3; done"; then
#         echo >&2 "vim is not installed yet"
#         exit 1
#       fi
#    hint: |
#      vim was not installed in the guest. Make sure the package system is working correctly.
#      Also see "/var/log/cloud-init-output.log" in the guest.

# ===================================================================== #
# FURTHER ADVANCED CONFIGURATION
# ===================================================================== #

firmware:
  # Use legacy BIOS instead of UEFI.
  # Default: false
  legacyBIOS: false

video:
  # QEMU display, e.g., "none", "cocoa", "sdl".
  # As of QEMU v5.2, enabling this is known to have negative impact
  # on performance on macOS hosts: https://gitlab.com/qemu-project/qemu/-/issues/334
  # Default: "none"
  display: "none"

network:
  # The instance can get routable IP addresses from the vmnet framework using
  # https://github.com/lima-vm/vde_vmnet. Both vde_switch and vde_vmnet
  # daemons must be running before the instance is started. The interface type
  # (host, shared, or bridged) is configured in vde_vmnet and not lima.
  vde:
    # vnl (virtual network locator) points to the vde_switch socket directory,
    # optionally with vde:// prefix
    # - vnl: "vde:///var/run/vde.ctl"
    #   # VDE Switch port number (not TCP/UDP port number). Set to 65535 for PTP mode.
    #   # Default: 0
    #   switchPort: 0
    #   # MAC address of the instance; lima will pick one based on the instance name,
    #   # so DHCP assigned ip addresses should remain constant over instance restarts.
    #   macAddress: ""
    #   # Interface name, defaults to "vde0", "vde1", etc.
    #   name: ""

# Port forwarding rules. Forwarding between ports 22 and ssh.localPort cannot be overridden.
# Rules are checked sequentially until the first one matches.
# portForwards:
#   - guestPort: 443
#     hostIP: "0.0.0.0" # overrides the default value "127.0.0.1"; allows privileged port forwarding
#   # default: hostPort: 443 (same as guestPort)
#   # default: guestIP: "127.0.0.1" (also matches bind addresses "0.0.0.0", "::", and "::1")
#   # default: proto: "tcp" (only valid value right now)
#   - guestPortRange: [4000, 4999]
#     hostIP:  "0.0.0.0" # overrides the default value "127.0.0.1"
#   # default: hostPortRange: [4000, 4999] (must specify same number of ports as guestPortRange)
#   - guestPort: 80
#     hostPort: 8080 # overrides the default value 80
#   - guestIP: "127.0.0.2" # overrides the default value "127.0.0.1"
#     hostIP: "127.0.0.2" # overrides the default value "127.0.0.1"
#   # default: guestPortRange: [1024, 65535]
#   # default: hostPortRange: [1024, 65535]
#   - guestPort: 8888
#     ignore: true (don't forward this port)
#   # Lima internally appends this fallback rule at the end:
#   - guestIP: "127.0.0.1"
#     guestPortRange: [1024, 65535]
#     hostIP: "127.0.0.1"
#     hostPortRange: [1024, 65535]
#   # Any port still not matched by a rule will not be forwarded (ignored)

# Extra environment variables that will be loaded into the VM at start up.
# These variables are currently only consumed by internal init scripts, not by the user shell.
# This field is experimental and may change in a future release of Lima.
# https://github.com/lima-vm/lima/pull/200
# env:
#   KEY: value

# Explicitly set DNS addresses for qemu user-mode networking. By default qemu picks *one*
# nameserver from the host config and forwards all queries to this server. On macOS
# Lima adds the nameservers configured for the "en0" interface to the list. In case this
# still doesn't work (e.g. VPN setups), the servers can be specified here explicitly.
# If nameservers are specified here, then the "en0" configuration will be ignored.
# dns:
# - 1.1.1.1
# - 1.0.0.1

# ===================================================================== #
# END OF TEMPLATE
# ===================================================================== # 
```

nerdctl のダウンロードが終わったら仮想マシンイメージのダウンロードが始まりました。こっちは速い。それが終わると仮想マシンの起動が始まりました。

```
$ limactl start
? Creating an instance "default" Proceed with the default configuration
INFO[0096] Downloading "https://github.com/containerd/nerdctl/releases/download/v0.11.2/nerdctl-full-0.11.2-linux-amd64.tar.gz"(sha256:27dbb238f9eb248ca68f11b412670db51db84905e3583834400305b2149915f2)
174.89 MiB / 174.89 MiB [---------------------------------] 100.00% 150.72 KiB/s
INFO[1286] Downloaded "nerdctl-full-0.11.2-linux-amd64.tar.gz"
INFO[1287] Attempting to download the image from "~/Downloads/hirsute-server-cloudimg-amd64.img"
INFO[1287] Attempting to download the image from "https://cloud-images.ubuntu.com/hirsute/current/hirsute-server-cloudimg-amd64.img"
558.00 MiB / 558.00 MiB [-----------------------------------] 100.00% 7.57 MiB/s
INFO[1362] Downloaded image from "https://cloud-images.ubuntu.com/hirsute/current/hirsute-server-cloudimg-amd64.img"
INFO[1366] [hostagent] Starting QEMU (hint: to watch the boot progress, see "/Users/teraoka/.lima/default/serial.log")
INFO[1366] SSH Local Port: 60022
INFO[1366] [hostagent] Waiting for the essential requirement 1 of 4: "ssh"
INFO[1394] [hostagent] Waiting for the essential requirement 1 of 4: "ssh"
INFO[1395] [hostagent] The essential requirement 1 of 4 is satisfied
INFO[1395] [hostagent] Waiting for the essential requirement 2 of 4: "sshfs binary to be installed"
INFO[1416] [hostagent] The essential requirement 2 of 4 is satisfied
INFO[1416] [hostagent] Waiting for the essential requirement 3 of 4: "/etc/fuse.conf to contain \"user_allow_other\""
INFO[1431] [hostagent] The essential requirement 3 of 4 is satisfied
INFO[1431] [hostagent] Waiting for the essential requirement 4 of 4: "the guest agent to be running"
INFO[1431] [hostagent] The essential requirement 4 of 4 is satisfied
INFO[1431] [hostagent] Mounting "/Users/teraoka"
INFO[1432] [hostagent] Mounting "/tmp/lima"
INFO[1432] [hostagent] Waiting for the optional requirement 1 of 2: "systemd must be available"
INFO[1433] [hostagent] Forwarding "/run/user/501/lima-guestagent.sock" (guest) to "/Users/teraoka/.lima/default/ga.sock" (host)
INFO[1433] [hostagent] Not forwarding TCP 127.0.0.53:53
INFO[1433] [hostagent] Not forwarding TCP 0.0.0.0:22
INFO[1433] [hostagent] Not forwarding TCP [::]:22
INFO[1433] [hostagent] The optional requirement 1 of 2 is satisfied
INFO[1433] [hostagent] Waiting for the optional requirement 2 of 2: "containerd binaries to be installed"
INFO[1433] [hostagent] The optional requirement 2 of 2 is satisfied
INFO[1433] READY. Run `lima` to open the shell.

```

この状態で `lima` と実行するだけで Linux VM 内の shell に入ります。

```
$ lima
teraoka@lima-default:/Users/teraoka$ uname -a
Linux lima-default 5.11.0-34-generic #36-Ubuntu SMP Thu Aug 26 19:22:09 UTC 2021 x86_64 x86_64 x86_64 GNU/Linux
```

OS は Ubuntu ですね。systemd で各種サービスが起動されています。

```
teraoka@lima-default:/Users/teraoka$ cat /etc/os-release
NAME="Ubuntu"
VERSION="21.04 (Hirsute Hippo)"
ID=ubuntu
ID_LIKE=debian
PRETTY_NAME="Ubuntu 21.04"
VERSION_ID="21.04"
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
VERSION_CODENAME=hirsute
UBUNTU_CODENAME=hirsute

```

ホームディレクトリと /tmp/lima が sshfs でマウントされています。ホームディレクトリは Read-Only です。どこをどこにマウントするかや、Read-Write を許可するかどうかは lima.yaml で指定可能っぽいです。

```
teraoka@lima-default:/Users/teraoka$ df -h
Filesystem       Size  Used Avail Use% Mounted on
tmpfs            393M  1.1M  392M   1% /run
/dev/vda1         97G  1.9G   95G   2% /
tmpfs            2.0G     0  2.0G   0% /dev/shm
tmpfs            5.0M     0  5.0M   0% /run/lock
tmpfs            4.0M     0  4.0M   0% /sys/fs/cgroup
/dev/vda15       105M  5.2M  100M   5% /boot/efi
/dev/sr0         182M  182M     0 100% /mnt/lima-cidata
tmpfs            393M  8.0K  393M   1% /run/user/501
:/Users/teraoka  466G  305G  143G  69% /Users/teraoka
:/tmp/lima       466G  305G  143G  69% /tmp/lima
```

`/etc/hosts` を確認したら `192.168.5.2 host.lima.internal` という行がありました。Host (Mac) へのアクセスに使えそうです。

lima コマンドの引数に linux のコマンドを渡せばそのまま Linux 内で実行されます。

```
$ lima uname -a
Linux lima-default 5.11.0-34-generic #36-Ubuntu SMP Thu Aug 26 19:22:09 UTC 2021 x86_64 x86_64 x86_64 GNU/Linux
```

コンテナの実行
-------

nerdctl も Linux 内にあります。次のようにしてコンテナの実行が可能。

```
$ lima nerdctl run -d --name nginx -p 127.0.0.1:8080:80 nginx:alpine
```

```
$ lima nerdctl ps
CONTAINER ID    IMAGE                             COMMAND                   CREATED               STATUS    PORTS                     NAMES
1230bf478818    docker.io/library/nginx:alpine    "/docker-entrypoint.…"    About a minute ago    Up        127.0.0.1:8080->80/tcp    nginx

```

この状態で Mac から localhost:8080 にアクセスすると nginx にアクセスできます。`~/.lima/default/lima.yaml` に portForwarding 設定がありましたが、これはあれとは別物のようです。nerdctl で指定したポートでアクセスできます。

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

Lima Virtual Machine の停止
------------------------

```
$ limactl stop
INFO[0000] Sending SIGINT to hostagent process 18940    
INFO[0000] Waiting for the host agent and the qemu processes to shut down 
INFO[0000] [hostagent] Received SIGINT, shutting down the host agent 
INFO[0000] [hostagent] Shutting down the host agent     
INFO[0000] [hostagent] Unmounting "/Users/teraoka"      
INFO[0000] [hostagent] Unmounting "/tmp/lima"           
WARN[0000] [hostagent] connection to the guest agent was closed unexpectedly 
INFO[0000] [hostagent] Shutting down QEMU with ACPI     
INFO[0000] [hostagent] Sending QMP system_powerdown command 
INFO[0001] [hostagent] QEMU has exited
```

```
$ limactl ls
NAME       STATUS     SSH                ARCH      DIR
default    Stopped    127.0.0.1:60022    x86_64    /Users/teraoka/.lima/default
```

`limactl start` で再度起動させることができます。コンテナイメージや停止状態のコンテナは残っています。

Lima Virtual Machine の削除
------------------------

削除の場合は仮想マシン名が省略できず、`default` も明示する必要がありました。

```
$ limactl delete default
INFO[0000] The QEMU process seems already stopped       
INFO[0000] The host agent process seems already stopped 
INFO[0000] Removing *.pid *.sock under "/Users/teraoka/.lima/default" 
INFO[0000] Removing "/Users/teraoka/.lima/default/ga.sock" 
INFO[0000] Deleted "default" ("/Users/teraoka/.lima/default")
```

`limactl prune` では cache が消されるっぽい。ここにはダウンロードした nerdctl や仮想マシンイメージがあり、消してしまうと limactl delete 後に再度 limactl start を実行するとまたダウンロードからやり直しです。

```
$ limactl prune
INFO[0000] Pruning "/Users/teraoka/Library/Caches/lima"
```

docker エイリアス
------------

shell の alias を設定することでほぼ docker として使えるようです。

```
alias docker="lima nerdctl"
```

ひとつ、非互換に気づいた。nerdctl では `run` で `-d` と `--rm` が同時に使えない。ゴミを残したくないからよく使うんだけどなあ。

```
$ lima nerdctl run -d --rm -p 8080:80 nginx:alpine
FATA[0000] flag -d and --rm cannot be specified together 
exit status 1
```

docker build / docker push
--------------------------

lima コマンド実行時の working dictory が仮想マシン内にも引き継がれるのでホームディレクトリ配下であれば `docker build -t xxx .` と実行しても、仮想マシン内の同じディレクトリで実行されるので　build が可能となっているようだ。

`docker login` (`nerdctl login`) も当然仮想マシン内でログインするのだが、`/Users/teraoka` は Read-Only だし、Linux でのホームディレクトリは `/home/teraoka.linux` になっており、ログイン情報は `/home/teraoka.linux/.docker/config.json` に書かれます。keychain は使えない。

ログインしてしまえば docker push も可能です。

docker-compose
--------------

試していませんが nerdctl には compose サブコマンドがあります。

```
$ lima nerdctl compose
NAME:
   nerdctl compose - Compose

USAGE:
   nerdctl compose command [command options] [arguments...]

COMMANDS:
   up       Create and start containers
   logs     View output from containers.
   build    Build or rebuild services
   down     Remove containers and associated resources
   help, h  Shows a list of commands or help for one command

OPTIONS:
   --file value, -f value          Specify an alternate compose file
   --project-directory value       Specify an alternate working directory
   --project-name value, -p value  Specify an alternate project name
   --env-file value                Specify an alternate environment file
   --help, -h                      show help (default: false)
```

次のようにして使えるようです。本家 docker-compose も新しいバージョンは docker のサブコマンドになっていますね。

```
$ lima nerdctl compose -f ./examples/compose-wordpress/docker-compose.yaml up

```

nerdctl の [GitHub repository](https://github.com/containerd/nerdctl) に [example](https://github.com/containerd/nerdctl/tree/master/examples/compose-wordpress) があります。

まとめ
---

Minikube や Docker Desktop との違いとして nerdctl コマンドは Linux 仮想マシン内にあるというところが大きいですね。ここを意識できていればまずまず使えるんじゃないでしょうか。

Docker Desktop の volume mount 機能は便利ですね。
