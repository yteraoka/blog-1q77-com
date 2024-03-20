---
title: Mac に Homebrew で docker pluings をインストールする
date: 2024-01-26T21:36:56+09:00
tags: [macOS, docker]
draft: false
image: cover.jpg
---

Docker Desktop for Mac であれば何もしなくても `docker compose` コマンドは使えるようになっているのですが、Lima で docker を使っている場合などで Homebrew で docker をインストールしていると `docker compose` や `docker buildx` を使えるようにするためには追加でのインストールが必要でした。

```bash
brew install docker-compose
brew install docker-buildx
```

どちらもインストール後に表示されるコマンドを実行するだけですが、`~/.docker/cli-plugins/` に symbolic link を作成する必要があります。

```bash
mkdir -p ~/.docker/cli-plugins
ln -sfn /opt/homebrew/opt/docker-compose/bin/docker-compose ~/.docker/cli-plugins/docker-compose
ln -sfn /opt/homebrew/opt/docker-buildx/bin/docker-buildx ~/.docker/cli-plugins/docker-buildx
```

Orbstack を入れたことのある端末では Orbstack のファイルへの symbolic link があったのですが、Orbstack 削除後も link だけが残っていました。

それぞれ GitHub の releases ページからバイナリをダウンロードして配置しても良い

- https://github.com/docker/buildx/releases
- https://github.com/docker/compose/releases
