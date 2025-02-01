---
title: "Tagpr で tag trigger の workflow が実行されなくてハマった話"
description: |
  Tagpr を使った自動化を構築しようとしたが、期待の動作をしなくて調査したが、ドキュメントの読み落としで時間を浪費した件
date: 2024-03-15T09:00:00+09:00
tags: [GitHub]
draft: false
image: cover.jpg
categories:
  - CI/CD
---

最近 [tagpr](https://github.com/Songmu/tagpr) という便利ツールの存在を知って試していたのですが、使い方が悪くてハマったのでメモ。

## tagpr とは

作者さまの記事を参照ください。

[リリース用のpull requestを自動作成し、マージされたら自動でタグを打つtagpr](https://songmu.jp/riji/entry/2022-09-05-tagpr.html)

2022年からあったのに今まで知りませんでした。
[git-pr-release](https://github.com/x-motemen/git-pr-release) を使ったことはありますが、それよりもずっと導入しやすいですね。

## やろうとしたこと

tagpr がリリース用の tag を push したことをトリガーに workflow を実行したいと考えました。
tagpr の実行も GitHub Actions の workflow で行うため、GitHub Actions で自動的に払い出される `secrets.GITHUB_TOKEN` を使ってしまうと、不慮の連鎖を避けるために workflow の trigger として扱われません。
そのため、GitHub App を作成し、次のようにして GitHub App の token を使うようにしました。

```yaml
name: tagpr

on:
  push:
    branches:
      - main

jobs:
  tagpr:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/create-github-app-token@v1
        id: app-token
        with:
          app-id: ${{ vars.APP_ID }}
          private-key: ${{ secrets.APP_PRIVATE_KEY }}
      - uses: actions/checkout@v4
      - uses: Songmu/tagpr@v1
        env:
          GITHUB_TOKEN: ${{ steps.app-token.outputs.token }}
```

tagpr の作成する Pull Request であったり、release が GitHub App の token を使ったものであることは確認できたのですが、なぜか tag の push をトリガーにした workflow は実行されませんでした。

発生している event の情報を確認するためにすべての event を送るように webhook を設定し、その中身を見てみると tag の push は GitHub App では行われていませんでした。

何が違うのか tagpr のソースコードを確認してみると Pull Request や Release を作成するのには github の client library が使われているのに対して push は git コマンドが実行されていました。ここにヒントがありそうだと思い調査を進めると git コマンドで使われる認証情報は [actions/checkout](https://github.com/actions/checkout) で設定されていることがわかりました。

## actions/checkout でも token 指定が必要

なるほどそういうことかと actions/checkout にも with の token で GitHub App の token を指定することで無事解決できました。

```yaml
      - uses: actions/checkout@v4
        with:
          token: ${{ steps.app-token.outputs.token }}
```

実は先の[紹介記事](https://songmu.jp/riji/entry/2022-09-05-tagpr.html)にも書かれていたのですが、ちゃんと読んでいませんでした...
