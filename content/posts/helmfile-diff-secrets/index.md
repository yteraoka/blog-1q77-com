---
title: "helm, helmfile で secrets の diff を確認する方法"
date: 2026-09-10T22:20:21+09:00
draft: false
tags: ['Kubernetes', 'Helm', 'helmfile']
image: cover.png
author: "@yteraoka"
categories:
  - IT
description: |
  helm diff, helmfile diff では Secret の値がマスクされて変更内容がわからない。
  マスクされた値の差分を確認する方法をまとめる。
---

## 困りごと

`helm diff` / `helmfile diff` はデフォルトでは Secret の値はマスクされてどんな値がどんな値に変わるのかがわからない。
マスクされる理由はわかるが確認する方法も知りたい。


## helm diff で確認する

[helm-diff plugin](https://github.com/databus23/helm-diff) v3.12.1 以降をインストールしていれば `--show-secrets-decoded` オプションを指定することで base64 decode した状態での差分を確認することができます。
`--show-secrets` の場合は base64 encode された状態で表示されます。


## helmfile diff で確認する

[helmfile](https://github.com/helmfile/helmfile) であれば `helmfile diff` に `--diff-args="--show-secrets-decoded"` を指定します。

