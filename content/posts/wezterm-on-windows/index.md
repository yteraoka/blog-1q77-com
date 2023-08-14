---
title: "WezTerm で快適な WSL2 環境にする"
date: 2023-08-12T20:07:01+09:00
draft: false
tags: ['Windows', 'Ubuntu', 'WSL2', 'WezTerm']
---

家の自分用 Laptop はずっと Linux を使ってきましたが、数か月前に Inspiron 14 に買い替えたタイミングで Ubuntu 22.04 にしてからやっぱり不便だなあとも思っていました。(InputMethod の切り替えで直接入力とひらがなだけにしたいのに Hankaku ってのが外せないとか、電源管理回りとか、snap でインストールしたアプリは日本語入力できないとか)

仕事ではメインで mac を使い、少しだけ Windows 10 も使っています。
Windows 10 では WSL2 を利用しているのですが、このデフォルトの Terminal が好きになれませんでした、そこで他に選択肢はないのだろうかと検索してみたら [WezTerm](https://wezfurlong.org/wezterm/) というのが良いらしいというのを見つけました。
軽く試してみたところ非常に良い感じでしたので、家の Inspiron もプリインストールの Windows 11 に戻すことにしました。

以降、Windows 11 のセットアップメモです。

## WSL2 の有効化

デフォルトの distribution (Ubuntu) のままで良ければ次のコマンドを実行するだけ。

```powershell
wsl --install
```

https://learn.microsoft.com/ja-jp/windows/wsl/install

## WezTerm のインストール

https://wezfurlong.org/wezterm/install/windows.html#installing-on-windows

最近の Windows には標準で [winget](https://learn.microsoft.com/ja-jp/windows/package-manager/winget/) っていうコマンドがインストールされているようです、便利。他のアプリも winget でインストールすることにしました。（が、なんか Microsoft Store からインストールすると、そうでない場合とインストール先とかプロファイルの保存先が変わったりする？）

```powershellmd
winget install wez.wezterm
```

設定ファイルは `%USERPROFILE%\.config\wezterm\wezterm.lua` で、[Quick Start](https://wezfurlong.org/wezterm/config/files.html) にあるサンプルは次のようになっています。

```lua
-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- This is where you actually apply your config choices

-- For example, changing the color scheme:
config.color_scheme = 'AdventureTime'

-- and finally, return the configuration to wezterm
return config
```

これにちょっと足して次の設定で利用を始めました。

```lua
local wezterm = require 'wezterm'

local config = {}

if wezterm.config_builder then
  config = wezterm.config_builder()
end

config.default_domain = 'WSL:Ubuntu'
config.hide_tab_bar_if_only_one_tab = true
config.use_ime = true
config.color_scheme = 'Materia (base16)'
config.font_size = 14
config.window_close_confirmation = 'AlwaysPrompt'
config.enable_scroll_bar = true
config.initial_rows = 36
config.initial_cols = 120
config.default_cursor_style = 'BlinkingUnderline'

return config
```

Color Scheme は標準で非常に沢山用意されています。すでにどこかで利用しているものがあれば探すと見つかりそう。
そうでなければ好みのを選ぶのが大変。
https://wezfurlong.org/wezterm/colorschemes/index.html

かなりいろんなことをカスタマイズ可能っぽいです、ググるか[公式ドキュメント](https://wezfurlong.org/wezterm/config/files.html)を参照。

`default_domain = 'WSL:Ubuntu'` を指定しておくことで WezTerm 起動時に WSL 環境にログインしている状態になります。
`Ubuntu` の部分は使っている distribution を指定する。

コピペはカーソルで選択するだけでコピーされ、`Ctrl + Shift + v` でペーストとなる。
ペーストは Gnome Terminal と同じだし Windows の標準のターミナルよりずっと良いですね。

## CapsLock を Ctrl に変更する

キーボードの `A` の左が `Ctrl` じゃないと辛いので変更する。
registry を書き換えれば良いのだとは思うが GUI でできると楽なので [Change Key](https://forest.watch.impress.co.jp/library/software/changekey/) を使った。
今時 LZH ファイルはつらい... 仕方ないので 7-zip をインストールして展開した。

```powershell
winget install 7zip.7zip
```
[Windows 10で「CapsLock」と「Ctrl」を入れ替える方法【PowerToys編】](https://news.mynavi.jp/techplus/article/20210609-1900755/) で紹介されているように PowerToys でも CapsLock キーを Ctrl に変更することはできたのだが、日本語入力の On/Off に `Ctrl + Space` を使うと不具合があるようなのでやめた。

すっかり忘れていたが、前にセットアップした別の Windows PC では Microsoft の Sysinternals でも紹介されている [ctrl2cap](https://learn.microsoft.com/ja-jp/sysinternals/downloads/ctrl2cap) を使ったのでした。
LZH に悩まされることもない。

この環境は Ctrl+Space が期待の動作をしなかったが、今回の件で PowerToys が原因だとわかったので削除して解消された。ヤッタネ！


## Docker のインストール

Windows Container を使う予定はないので Docker Desktop for Windows ではなく、Ubuntu 環境内にインストールする。

https://docs.docker.com/engine/install/ubuntu/

個人的にはこれで十分。

```bash
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

## Ubuntu の設定

### 日本語 locale 追加

ファイル名にマルチバイトの日本語を使用すると ls コマンドでの表示が
`''$'\343\201\202\343\201\204\343\201\206\343\201\210\343\201\212'` のようになってしまうので

日本語 locale を追加して

```
sudo apt install language-pack-ja
```

LANG を指定する

```
export LANG=ja_JP.utf8
```

ただし、`date` コマンドの出力が `2023年  8月 12日 土曜日 21:07:22 JST` とかになったり、エラーメッセージまでもが日本語にならなくても良いので

```
export LC_TIME=C
export LC_MESSAGES=C
```

も設定しておく。

### Zsh への変更

mac が zsh なのでそろえる。

```bash
sudo apt install -y zsh
chsh -s /usr/bin/zsh
```


### Homebrew のインストール

https://brew.sh/

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
必要なものをインストール（他にも必要になったら随時）

```bash
brew install awscli rtx fzf ghq hugo hadolint trivy checkov
```

[rtx](https://github.com/jdxcode/rtx) でインストールするものは rtx で。

gcloud コマンドのインストール

```bash
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-440.0.0-linux-x86_64.tar.gz
tar xv google-cloud-cli-440.0.0-linux-x86_64.tar.gz
./google-cloud-sdk/install.sh
rm google-cloud-cli-440.0.0-linux-x86_64.tar.gz
```

### WSL2 の DNS サーバー問題

VPN を使用していて、接続時には接続先の DNS サーバーを参照しなければならないような環境の場合、WSL 環境の resolv.conf は自動で書き換わってくれたりしないので書き換えてやる必要がある。

https://github.com/jacob-pro/wsl2-dns-agent というツールがこの問題を解決してくれるようだが、まだ使ったことはない。

Ubuntu 内から `/mnt/c/WINDOWS/System32/WindowsPowerShell/v1.0/powershell.exe` を実行可能だと知ったので次のようにして DNS サーバーの IP アドレスを取得して resolv.conf を書き換えるスクリプトを書いた。（家の Laptop の話じゃないけど）

```bash
/mnt/c/WINDOWS/System32/WindowsPowerShell/v1.0/powershell.exe \
'Get-NetAdapter| Where-Object InterfaceDescription -Match "VPN接続の説明にマッチする文字列" | Get-DnsClientServerAddress | Where-Object AddressFamily -eq 2 | ConvertTo-Json' \
  2> /dev/null | jq -r '.ServerAddresses|@csv'
```
