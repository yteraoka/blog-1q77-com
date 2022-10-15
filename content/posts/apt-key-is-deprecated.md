---
title: 'apt-key is deprecated への対応'
date: 2022-10-15T12:06:00+09:00
draft: false
tags: ['Debian', 'Linux']
---

Debian 系の Linux で古いインストール手順なんかを見てコマンドをコピペしていると出くわすこのメッセージ

```
Warning: apt-key is deprecated. Manage keyring files in trusted.gpg.d instead (see apt-key(8)).
```

package 署名の公開鍵の管理方法が変わったみたいです

リポジトリごとに公開鍵を別に管理する方が安全だということで例えば

[PostgreSQL の debian 向けドキュメント](https://www.postgresql.org/download/linux/debian/)には2022年10月15日時点で次のように記載されています

```bash
# Create the file repository configuration:
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

# Import the repository signing key:
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

# Update the package lists:
sudo apt-get update

# Install the latest version of PostgreSQL.
# If you want a specific version, use 'postgresql-12' or similar instead of 'postgresql':
sudo apt-get -y install postgresql
```

が、[新しい鍵管理方法](https://wiki.debian.org/DebianRepository/UseThirdParty)に従えば次のようにするのが好ましいようです

```bash
test -d /etc/apt/keyrings || sudo mkdir -p /etc/apt/keyrings
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/keyrings/pgdg.gpg
sudo sh -c 'echo "deb [signed-by=/etc/apt/keyrings/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
sudo apt-get update
sudo apt-get -y install postgresql
```

公開鍵はテキストの ASCII Armor のままでも扱えるようですが、公開されているものが apt でサポートされていないフォーマットである可能性があるため
`gpg --dearmor` で OpenPGP のバイナリ形式にしておくのが安全とのこと。

パッケージで管理される公開鍵は `/usr/share/keyrings` に配置し、ローカル管理の公開鍵は `/etc/apt/keyrings` に配置せよと。


[Docker のインストール手順](https://docs.docker.com/engine/install/debian/)は更新されており、現在は次のようになっていました。

```bash
sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```


## 参考資料

- [第675回　apt-keyはなぜ廃止予定となったのか | gihyo.jp](https://gihyo.jp/admin/serial/01/ubuntu-recipe/0675)
- [DebianRepository/UseThirdParty - Debian Wiki](https://wiki.debian.org/DebianRepository/UseThirdParty)
- [apt-key が非推奨になったので](https://zenn.dev/spiegel/articles/20220508-apt-key-is-deprecated)
