---
title: "Azure DevOps の Git の認証を OAuth にする"
date: 2026-09-09T19:00:24+09:00
draft: false
tags: ['Azure', 'git']
image: cover.png
author: "@yteraoka"
categories:
  - IT
description: |
  Azure DevOps 用の git-credential-manager 設定
---

## 困りごと

Azure DevOps のリポジトリの認証は WebUI から credentials をコピーして使うことも可能ですが、
期限切れでの更新が面倒です。

そこで Entra ID での OAuth で credentials を取得できるようにする方法をメモ。

## 設定方法

[git-credential-manager](https://github.com/git-ecosystem/git-credential-manager) をインストールします

```
brew install git-credential-manager
```

`~/.gitconfig` に次の設定を追加する

```
[credential "https://dev.azure.com"]
        helper =
        helper = manager
        azreposCredentialType = oauth
        useHttpPath = true
```

helper は絶対Pathで指定すればそのコマンドが実行されますが、上記のように設定すると
`PATH` にある `git-credential-manager` というコマンドが実行されます。
先頭に `!` を入れた場合は `git-credential-` が追加されずに `PATH` から実行されます。

通常はホスト名が同じであれば同じ認証情報が使いまわされますが、 `useHttpPath = true`
を指定することで path ごとに別の認証情報が必要なものとして扱われます。

Web Browser の使えない環境ではさらに `msauthFlow = devicecode` を追加することで
device flow での token 取得が行えます。

