---
title: "WSL の Linux から Windows のブラウザで URL を開く"
date: 2024-01-07T20:43:53+09:00
draft: false
tags: ["Windows", "WSL2"]
---

## 課題

WSL の Linux 内で awscli を使って SSO 認証する場合の `aws sso login` 実行時や GitHub の CLI である [gh](https://github.com/cli/cli) ([cli.github.com](https://cli.github.com/) ) コマンドで `gh auth login` を実行した場合に可能であれば自動でブラウザで指定の URL が開かれますが、WSL の場合、Linux 内のブラウザを使うわけではないため何も設定していない状態だと開いてくれないのでひと手間かかって面倒です。

gh コマンドはログイン以外にもブラウザで開くコマンドがいくつもあるのでこれが使えるようになるのは重要。


## BROWSER 環境変数

これを回避するためには `BROWSER` という環境変数に Windows 側のブラウザへの path を設定すれば良いというのはググってわかったのですが、次のように設定した場合 `aws sso login` では機能するものの `gh auth login` では空白を含むせいで実行に失敗します。

```bash
export BROWSER="/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"
```

さらにクオートしてやると `gh` では機能するけど `aws` の方が機能しなくなります。

```bash
export BROWSER="'/mnt/c/Program Files/Google/Chrome/Application/chrome.exe'"
```


## symbolic link で空白を含む path 問題を回避

symbolic link を経由させることでこの問題を回避することができました。

```bash
ln -s /mnt/c/Program\ Files/Google/Chrome/Application/chrome.exe ~/bin/chrome
export BROWSER=$HOME/bin/chrome
```

## GH\_BROWSER 環境変数

`gh` コマンドは `GH_BROWSER` 環境変数がセットされていればそちらが優先されるので、こちらにクオートした値をセットすることでも回避可能でした。しかし、あきらかに `gh` コマンドの実装に問題があるのになんで放置されてるんだろうか？

```bash
export GH_BROWSER="'/mnt/c/Program Files/Google/Chrome/Application/chrome.exe'"
```

## wslu

[wslu - A collection of utilities for WSL](https://github.com/wslutilities/wslu) ([wslutiliti.es/wslu](https://wslutiliti.es/wslu/) ) という便利ツールがあって、これに含まれる wslview コマンドを使うというのも良いみたいです。Windows 側のデフォルトブラウザで開いてくれるようです。

Ubuntu 22.04 では apt で 3.2.3 がインストールされました。

```bash
sudo apt update
sudo apt install wslu
```

最新バージョンは [ppa:wslutilities/wslu](https://launchpad.net/~wslutilities/+archive/ubuntu/wslu) からインストールできます。

```bash
sudo add-apt-repository ppa:wslutilities/wslu
sudo apt update
sudo apt install wslu
```

wslu 4.1.1 でインストールされたコマンド

```bash
$ dpkg -L wslu | grep bin/
/usr/bin/wslact
/usr/bin/wslclip
/usr/bin/wslfetch
/usr/bin/wslgsu
/usr/bin/wslsys
/usr/bin/wslupath
/usr/bin/wslusc
/usr/bin/wslvar
/usr/bin/wslview
```

```bash
export BROWSER=/usr/bin/wslview
```

`wslclip` コマンドは clipboard の値の取得や登録が可能なツールでした。


## Microsoft Edge の path

直接ブラウザを指定する方法で Edge を使いたい場合は次の path にあります。

```
/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe
```

## BROWSER 環境変数を使うその他のツール

`az login` や `gcloud auth login` でも同じように `BROWSER` 環境変数で対応できるようです。

