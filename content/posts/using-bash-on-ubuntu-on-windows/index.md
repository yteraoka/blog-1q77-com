---
title: 'Bash on Ubuntu on Windows をセットアップする'
date: Sat, 20 Aug 2016 02:01:28 +0000
draft: false
tags: ['Linux', 'Windows', 'Windows', 'bash', 'ubuntu']
---

そろそろ Bash on Ubuntu on Linux ([https://msdn.microsoft.com/ja-jp/commandline/wsl/about](https://msdn.microsoft.com/ja-jp/commandline/wsl/about)) を試してみようかなと。 普段 Ubuntu 16.04 のインストールされた VAIO を使っているので特に何かやりたいというわけではないけど... インストールの手順は [https://msdn.microsoft.com/commandline/wsl/install\_guide](https://msdn.microsoft.com/commandline/wsl/install_guide) に書いてある通り。ただ、英語環境向けなので日本語環境では検索時のキーワードが違ってたりする。

### 前提条件の確認

* 2016年8月2日に適用可能となった Windows 10 Anniversary Update - build 14393 が適用されていること
* 64bit CPU であること
* AMD/Intel x64 互換の CPU であること
* [Windows Insider Program](http://insider.windows.com/) に参加し、できれば Fast-Ring を使うこと

Fast-Ring については [http://ascii.jp/elem/000/001/099/1099995/](http://ascii.jp/elem/000/001/099/1099995/) がわかりやすい。が、Beta 版 OS を使うということになるので、普段使いの PC では有効にしないほうが無難。

スタートメニューから歯車アイコンの設定を選択
{{< figure src="settings.png" alt="設定" >}}

「システム」を選択
{{< figure src="settings_system.png" alt="システム" >}}

バージョン情報を確認
{{< figure src="windows10_version.png" alt="バージョン確認" >}}

### 開発者モードを有効にする

設定から「更新とセキュリティ」を選択
{{< figure src="settings_update_and_security.png" alt="更新とセキュリティ" >}}

開発者モードにチェックを入れる
{{< figure src="developer-mode.png" alt="開発者モード" >}}

確認が出るのでリスクを許容する
{{< figure src="developer-mode-confirm.png" alt="開発者モードの確認" >}}

「設定」の検索窓で「Windows の機能の有効化または無効化」を探す
{{< figure src="search-turn.png" alt="有効化で検索" >}}

「Windows Subsystem for Linux (Beta)」にチェックを入れて「OK」をクリック
{{< figure src="windows_subsystem_for_linux.png" alt="Windows Subsystem for Linux (Beta)" >}}

### 再起動

ここでいったん再起動

### Bash の起動

「Windows + R」でコマンドプロンプトを起動し、「Bash」を起動
{{< figure src="bash_confirm.png" alt="Bashインストールの確認" >}}

インストール完了
{{< figure src="bash_setup_finished.png" alt="Bashインストールの完了" >}}

```
$ cat /etc/os-release
NAME="Ubuntu"
VERSION="14.04.4 LTS, Trusty Tahr"
ID=ubuntu
ID_LIKE=debian
PRETTY_NAME="Ubuntu 14.04.4 LTS"
VERSION_ID="14.04"
HOME_URL="http://www.ubuntu.com/"
SUPPORT_URL="http://help.ubuntu.com/"
BUG_REPORT_URL="http://bugs.launchpad.net/ubuntu/"
```

### 更新

スタートメニューから「Bash on Ubuntu on Windows」を起動してみると

```
52 個のパッケージがアップデート可能です。
30 個のアップデートはセキュリティアップデートです。
```

と表示されるので `sudo apt-get update`, `sudo apt-get upgrade -y` で更新しました。 sudo のパスワードは Bash インストール時に設定したものを入力します

### 次は？

普段使いするにはコマンドプロンプトはつらいので何か良い代替ソフトを探す必要がありますね
