---
title: 'CentOS に Git 2.x をインストールする方法'
date: Sun, 12 May 2019 02:06:38 +0000
draft: false
tags: ['CentOS', 'CentOS', 'git']
---

[Remote Development with VS Code](https://code.visualstudio.com/blogs/2019/05/02/remote-development) が発表されました、大変便利そうなので早速試そうと、Vagrant で起動している CentOS 7 へ SSH でアクセスするように設定してみました。が、Git 2.0 以降をインストールしてねと表示されてしまったので、さてどうやってインストールしようかなと確認したメモ。Source から自前で compile して入れるのではなく yum で入れたいなと。

[The Software Collections ( SCL ) Repository](https://wiki.centos.org/AdditionalResources/Repositories/SCL) と [IUS Community Project](https://ius.io/) が候補となるようです。SCL はインストール先がちょっと特殊で使いづらいので IUS かな。

### IUS

IUS の git をインストールするには先に標準 repository から入れている git を削除する必要があります。

#### CentOS 7

```
sudo yum -y install https://centos7.iuscommunity.org/ius-release.rpm
sudo yum -y remove git git-\\\*
sudo yum -y install git2u

```

#### CentOS 6

```
sudo yum -y install https://centos6.iuscommunity.org/ius-release.rpm
sudo yum -y remove git git-\\\*
sudo yum -y install git2u

```

### SCL

SCL の package をインストールするためにはまず centos-release-scl package で repository を追加する。

```
sudo yum -y install centos-release-scl

```

するとインストール可能な複数のバージョンがみつかる。CentOS 7 では `centos-sclo-sclo` repository に `sclo-git25` (git-2.5.0) と `sclo-git212` (git-2.12)、`centos-sclo-rh` repository に `rh-git218` (git-2.18) と `rh-git29` (git-2.9) と `git19` (git-1.9.4) がありました。

しかし、SCL は使い方が面倒。rh-git218 を入れたとすると次のように `scl enable` を使う

```
$ scl -l
httpd24
rh-git218
$ scl enable rh-git218 "git --version"
git version 2.18.1

```

`scl enable rh-git218 bash` とすれば環境変数のセットされた状態の bash が起動するが、あまりやりたくない。セットされる環境変数はこれ。

```
$ cat /opt/rh/rh-git218/enable
export PATH=/opt/rh/rh-git218/root/usr/bin${PATH:+:${PATH}}
export MANPATH=/opt/rh/rh-git218/root/usr/share/man:${MANPATH}
export PERL5LIB=/opt/rh/rh-git218/root/usr/share/perl5/vendor\_perl${PERL5LIB:+:${PERL5LIB}}
export LD\_LIBRARY\_PATH=/opt/rh/httpd24/root/usr/lib64${LD\_LIBRARY\_PATH:+:${LD\_LIBRARY\_PATH}}

```

`source scl_source enable rh-git218` を .bashrc とかに書くこともできるけど、うーむ... (scl\_source には "Don't use this script outside of SCL scriptlets!" とコメントが書いてある)

というわけで、IUS の git を入れるのが便利。

### まとめ

[Visual Studio Code Remote Development](https://code.visualstudio.com/docs/remote/remote-overview) は便利！！