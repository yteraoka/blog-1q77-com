---
title: "WSL の仮想ディスクサイズを Export & Import で縮小する"
date: 2026-07-11T22:28:32+09:00
tags: ["WSL"]
draft: false
image: cover.png
author: "@yteraoka"
categories:
  - Windows
description: |
  WSL の仮想ディスクを export & import を行うことで小さくする手順
---

## WSL の仮想ディスクの肥大化問題

Windows の WSL は便利ですが、利用しているうちに仮想ディスク(VHDX)のサイズが思わぬ大きさになって Windows のディスクの空き容量が少なくなって困ることがあります。
Windows が Enterprise Edition であれば optimize-vhd コマンドが使えるよとか、そうでない場合は diskpart コマンドが使えるよといった情報がありますが、一番確実なのは export & import だよなということになったのでその手順のメモです。

もちろん export 先にそれなりの空き容量が必要ですが、内臓ディスクに空きがなければ USB 接続でもして用意しましょう。

## export

### shutdown

まずは WSL のディストリビューションを停止させます。

```
wsl --shutdown
```

### 名前の確認

```
wsl --list --verbose
```

今回は Ubuntu という名前でした。

### export 

Ubuntu という名前のディストリビューションを ubuntu-exported.tar というファイルに出力する例です。

```
wsl --export Ubuntu ubuntu-exported.tar
```

<details>
<summary><code>--export</code> の説明</summary>

```
--export <Distro> <FileName> [Options]
    ディストリビューションを tar ファイルにエクスポートします。
    stdout の場合は、ファイル名に - を使用できます。

    オプション:
        --format <Format>
            エクスポート形式を指定します。サポートされている値は、
	    tar、tar.gz、tar.xz、vhd です。
```

</details>


### 削除

次のコマンドを実行すると仮想ディスクファイルも削除されます。

```
wsl --unregister Ubuntu
```

## import

元の VHDX ファイルは次の場所にありましたが、別にどこにあっても良いみたいです。

`C:\Users\ytera\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu_79rhkp1fndgsc\LocalState`

今回は次の場所に VHDX ファイルを配置することにします。(`"C:\Users\ytera\AppData\Local\Ubuntu\ext4.vhdx"`)

```
mkdir $env:LOCALAPPDATA\Ubuntu
```

```
wsl --import Ubuntu $env:LOCALAPPDATA\Ubuntu ubuntu-exported.tar --version 2
```

import が完了したら `ubuntu-exported.tar` ファイルは不要になるので動作確認後に削除します。

<details>
<summary><code>--import</code> の説明</summary>

```
--import <Distro> <InstallLocation> <FileName> [Options]
    指定された tar ファイルを新しいディストリビューションとしてインポートします。
    stdin の場合は、ファイル名に - を使用できます。

    オプション:
        --version <Version>
            新しいディストリビューションに使用するバージョンを指定します。

        --vhd
            指定されたファイルが tar ファイルではなく、.vhd または .vhdx
	    ファイルであることを指定します。
            この操作により、指定したインストール場所に VHD ファイルのコピー
	    が作成されます。
```

</details>

## デフォルトユーザーを元に戻す

import すると root でのアクセスになっているためデフォルトユーザーを以前使っていたユーザーに戻す必要がありました。

```
ubuntu config --default-user yteraoka
```

- [ディストリビューションの既定のユーザーを変更する](https://learn.microsoft.com/ja-jp/windows/wsl/basic-commands#change-the-default-user-for-a-distribution)

## Ubuntu 内で Windows の exe ファイルを実行可能にする

open コマンドを次のようにしていたり、ssh で 1password 連携（）をしたり、Windows 側の Web ブラウザを開くために Windows 側の exe ファイルを実行できる必要があるのですが、import 後にできなくなっていたので `/etc/wsl.conf` に次の設定を追加しました。

```ini
[interop]
enabled = true
appendWindowsPath = true
```

- [1Password の SSH Agent を WSL でも使う](https://qiita.com/yteraoka/items/a056f7c055cc73b06d19)
- [WSL の Linux から Windows のブラウザで URL を開く](/2024/01/open-browser-in-wsl/)

{{< x user="mattn_jp" id="1965950125416808682" >}}

## 参考サイト

- [Windows内のLinux環境を手軽に初期化、WSL2の賢い操作法](https://xtech.nikkei.com/atcl/nxt/column/18/01863/112600004/)
