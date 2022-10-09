---
title: 'Docker on Lima'
date: Tue, 04 Jan 2022 16:23:46 +0000
draft: false
tags: ['Docker', 'Docker']
---

以前、「[Lima で nerdctl](/2021/09/lima/)」という記事を書きました。その後、lima の VM 上で docker daemon を実行し、ホスト側から docker コマンドでアクセスするという方法があることを知りました。たまたま、brew upgrade を実行していたところ lima が 0.8.0 に更新されたのを見て Github の [releases ページ](https://github.com/lima-vm/lima/releases)を見、試してみようかなと思ったのでメモです。 ちなみに、前回試した時のバージョンは 0.6.4 でした。

Docker 入りの VM を起動させる
--------------------

私は brew のインストール先を $HOME にしていますが、brew で lima をインストールすると `[~/.homebrew/Cellar/lima/0.8.0/share/doc/lima/examples/docker.yaml](https://github.com/lima-vm/lima/blob/v0.8.0/examples/docker.yaml)` に docker 入りの VM を作成するための設定ファイルも一緒にインストールされています。これを使うことで簡単に VM が作成できます。次のように `limactl start` に続けてファイルの path を指定するだけです。

```
$ limactl start ~/.homebrew/Cellar/lima/0.8.0/share/doc/lima/examples/docker.yaml
```

ファイルは URL でも良いみたいなので次のようにすることもできるようです。

```
$ limactl start https://raw.githubusercontent.com/lima-vm/lima/v0.8.0/examples/docker.yaml
```

limactl start を実行すると、指定したファイルの内容そのままでインスタンスを作成するか、編集するかを尋ねられます。その場で編集して起動させられるのは便利ですね。

```
? Creating an instance "docker"  [Use arrows to move, type to filter]
> Proceed with the default configuration
  Open an editor to override the configuration
  Exit
```

デフォルトでは $HOME ディレクトリが Read-Only でマウントされるので　Writable　に変更しておくと便利です。([default.yaml](https://github.com/lima-vm/lima/blob/v0.8.0/pkg/limayaml/default.yaml) のコメントでは writable は false にしておけって書かれてますけど)

```yaml
mounts:
  - location: "~"
    # CAUTION: `writable` SHOULD be false for the home directory.
    # Setting `writable` to true is possible, but untested and dangerous.
    writable: true
```

CPU, Memory, Disk のデフォルトは次のようになっており、変更はお好みで。

```yaml
# CPUs: if you see performance issues, try limiting cpus to 1.
# Default: 4
cpus: 4

# Memory size
# Default: "4GiB"
memory: "4GiB"

# Disk size
# Default: "100GiB"
disk: "100GiB"
```

docker コマンドでアクセス
----------------

起動すると、`DOCKER_HOST` 環境変数の設定方法が表示されるのでそれをコピペすれば docker コマンドで lima の VM 上の docker daemon を操作できるようになります。この際、Docker Desktop 付属の docker コマンドでは何かで待たされてちょっとイラッとするので `brew install docker` で別途 docker コマンドをインストールしてそちらを使うのが良いかと思います。(何に引っ掛かってるのか調べたかったけど dtruss もなぜかうまく機能しないので諦め)

```
To run `docker` on the host (assumes docker-cli is installed):
$ export DOCKER_HOST=unix://{{.Dir}}/sock/docker.sock
$ docker ...
```

lima コマンドの引数で指定したコマンドを　VM 内で実行してくれる便利機能は default　以外の VM で使うためには `LIMA_INSTANCE` という環境変数を設定する必要があります。

```
$ lima hostname
lima-default

$ LIMA_INSTANCE=docker lima hostname
lima-docker
```

VM 内で shell を実行してしまえば良いなら `limactl shell docker` とすれば環境変数を使わずにすみます。

その他の変更
------

沢山あると思いますが、Intel VM を M1 mac で、Arm VM を Intel mac で実行可能になっています。

[examples ディレクトリ](https://github.com/lima-vm/lima/tree/v0.8.0/examples)には docker だけじゃなくていろんな VM 用のテンプレが用意されています。

port-forward が 1024 未満のポートにも対応しています。(podman の件と混同してしまって、以前どういう状態だったか覚えていない)

以前は複数の VM を同時に起動させられなかったという記憶があるのですが、同時に起動できるようになってました。

```
$ limactl list
NAME       STATUS     SSH                ARCH      CPUS    MEMORY    DISK      DIR
default    Running    127.0.0.1:60022    x86_64    4       4GiB      100GiB    /Users/teraoka/.lima/default
docker     Running    127.0.0.1:60006    x86_64    4       4GiB      100GiB    /Users/teraoka/.lima/docker
```

docker compose も問題なく使えました。

[docker.yaml](https://raw.githubusercontent.com/lima-vm/lima/v0.8.0/examples/docker.yaml) を default.yaml にして `limactl start default.yaml` とすれば default VM が docker 用になります。

```
$ curl -Lo default.yaml https://raw.githubusercontent.com/lima-vm/lima/v0.8.0/examples/docker.yaml
$ limactl start default.yaml
```
