---
title: 'mac のセットアップ'
date: Sun, 22 Dec 2019 15:40:17 +0000
draft: false
tags: ['macOS']
---

初めての Mac を手にいれました。macOS は Catalina (10.15.2) でした。Control と Command キーの使い分けに慣れない。

```
$ sw_vers 
ProductName:	Mac OS X
ProductVersion:	10.15.2
BuildVersion:	19C57
```

Google Chrome のインストール
---------------------

Safari で Chrome (googlechrome.dmg) をダウンロードし、アプリケーションフォルダにコピーする。

`brew cask` でインストールするのとどっちが良いのかな？

Homebrew のインストール
----------------

個人で入れるものはホームディレクトリ配下に入れるのが良いのかなと思い、[Homebrew をホームディレクトリ以下にインストール](https://qiita.com/hm0429/items/abf6acd3e797fa85c00e) を参考にインストール。

```
mkdir $HOME/.homebrew \
  && curl -L https://github.com/Homebrew/brew/tarball/master \
  | tar xz --strip 1 -C $HOME/.homebrew
```

```
PATH=$HOME/.homebrew/bin:$PATH
export HOMEBREW_CACHE=$HOME/.homebrew/cache
```

```
brew update
```

### Homebrew cask

[homebrew-cask](https://github.com/Homebrew/homebrew-cask) で GUI アプリのインストール（管理）もできるらしい。

```
brew cask install visual-studio-code
```

`~/Applications/` ではなく `/Applications/` にインストールされました。

### Brew でいくつかインストール

#### Google Cloud SDK

```
brew cask install google-cloud-sdk
```

- `bq`
- `docker-credential-gcloud`
- `gcloud`
- `git-credential-gcloud.sh`
- `gsutil`

が homebrew の bin/ に symlink される

#### jq

```
brew install jq
```

#### tfenv

```
brew install tfenv
```

#### goenv

```
brew install goenv
```

が、古くて 1.11 までしか出てこないので手動でインストールすることにした...

#### kubectl

```
brew install kubernetes-cli
```

```
$ kubectl version --short --client
Client Version: v1.14.8
```

古っ！と思ったらこれは docker といっしょにインストールされた `/usr/local/bin/kubectl` だった... 邪魔だな。brew で入れたのはこの時点 (2019-12-23) では 1.17.0 だった。

#### GNU tools

Linux のつもりで使ってるとハマるので Gnu のツールを入れる。通常の path には `gsed` などと `g` prefix のついたものが置かれる。`$(brew --prefix)/opt/gnu-sed/libexec/gnubin` を `PATH` の手前の方に入れておけば `g` 無しで使える。

```
brew install coreutils
brew install gnu-sed
brew install gawk
brew install gnu-tar
```

#### direnv

[github.com/direnv/direnv](https://github.com/direnv/direnv)

```
brew install direnv
```

`~/.zshrc` に次の行を追加して hook を設定する

```
eval "$(direnv hook zsh)"
```

#### wakeonlan

家の別の PC を起こすため

```
brew install wakeonlan
```

Terminal の設定
------------

[Iceberge](https://cocopon.github.io/iceberg.vim/) プロファイルをインストール

プロファイルをダウンロードして、ターミナルアプリの環境設定からそれを読み込んで、自分好みにちょっといじる。フォントサイズとかウインドウサイズとか背景の透過とか。

Docker のインストール
--------------

Homebrew でインストールする

```
brew install docker
brew cask install docker
```

```
open /Applications/Docker.app
```

[DockerをHomebrewでMac OSに導入する方法](https://qiita.com/nemui_/items/ed753f6b2eb9960845f7)

Zsh
---

デフォルトの Login Shell は zsh でした。使ったことない。`~/.zlogin`, `~/.zshrc` を書けば良いようだ。

### zplug

Zsh のプラグインマネージャーとして [github.com/zplug/zplug](https://github.com/zplug/zplug) をインストール

```
brew install zplug
```

```zsh
export ZPLUG_HOME=/Users/teraoka/.homebrew/opt/zplug
source $ZPLUG_HOME/init.zsh

# pure prompt 設定
zplug mafredri/zsh-async, from:github
zplug sindresorhus/pure, use:pure.zsh, from:github, as:theme

if ! zplug check --verbose; then
    printf "Install? [y/N]: "
    if read -q ; then
        echo; zplug install
    fi
fi

#zplug load --verbose
zplug load
```

### pure-prompt

プロンプトは Powerline を入れようかと思ったけれども面倒だから [github.com/sindresorhus/pure](https://github.com/sindresorhus/pure) を使うことにしました。

README には npm で入れる方法が書いてあったのですが、インストールに npm を使うだけで prompt としての動作には不要っぽいのでマニュアルインストールを選択... したんだけど、その後 zplug で入れられることがわかった

#### マニュアルインストール

```
mkdir -p "$HOME/.zsh"
git clone https://github.com/sindresorhus/pure.git "$HOME/.zsh/pure"
```

`.zshrc` への追加

```
fpath+=("$HOME/.zsh/pure")
autoload -U promptinit; promptinit
prompt pure
```

#### zplug でのインストール

マニュアルインストールのやつは全部不要

`.zshrc` に入れる

```
zplug mafredri/zsh-async, from:github
zplug sindresorhus/pure, use:pure.zsh, from:github, as:theme
```

### Zsh の補完

Homebrew でインストールしたコマンドの補完用スクリプトは `$(brew --prefix)/share/zsh/site-functions/` 配下に symbolic link が張られるため、`.zshrc` でここを fpath に追加するなどする

```zsh
fpath+=($(brew --prefix)/share/zsh/site-functions)
autoload -U compinit
compinit -u
```

Git
---

### システムワイドな .gitignore 設定

```
git config --global core.excludesfile ~/.gitignore_global
```

[グローバルで.gitignoreを適用する](https://qiita.com/katsew/items/5cade12fa743a2f31f25)  
[github.com/github/gitignore](https://github.com/github/gitignore)

### git-secrets

```
brew install git-secrets
git secrets --register-aws --global
```

[クラウド破産しないように git-secrets を使う](https://qiita.com/pottava/items/4c602c97aacf10c058f1)

Remote Desktop クライアント
---------------------

[Microsoft Remote Desktop 10](https://apps.apple.com/jp/app/microsoft-remote-desktop-10/id1295203466)
