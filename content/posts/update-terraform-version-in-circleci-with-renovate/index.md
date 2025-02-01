---
title: renovate で CircleCI の terraform_version を更新する
description: |
  renovate の config をカスタマイズする
date: 2024-02-04T19:37:36+09:00
tags: [renovate, CircleCI, Terraform]
draft: false
image: cover.png
author: "@yteraoka"
categories:
  - CI/CD
---

## 課題

Circle CI の [terraform Orb](https://circleci.com/developer/orbs/orb/circleci/terraform) で
terraform の version を指定するには次のようにしますが、この `terraform_version` の値に変数を
使うことが出来ず、tf ファイルや `.tool-versions` から読み出した値を使うことが出来ませんでした。

```yaml
- terraform/install:
    terraform_version: 1.7.2
```

## Workaround

GitHub Actions では他の step の output などを使うことができるので [hashicorp/setup-terraform](https://github.com/hashicorp/setup-terraform) では `.tool-versions` から取り出した値を渡すことにしました。

```yaml
- name: Get terraform version from .tool-versions
  id: tfversion
  run: echo tfversion=$(grep '^terraform ' .tool-versions | awk '{print $2}') >> $GITHUB_OUTPUT

# https://github.com/hashicorp/setup-terraform
- name: Download Terraform
  uses: hashicorp/setup-terraform@v3
  with:
    terraform_version:  ${{ steps.tfversion.outputs.tfversion }}
```

tf ファイル内の `required_version` や `.tool-versions` は [renovate](https://github.com/renovatebot/renovate) がサポートしているので更新の Pull Request を作ってくれます。

## .circleci/config.yml に対応するためのカスタマイズ

Circle CI も renovate がサポートしてくれれば良いのですが、renovate.json を[カスタマイズ](https://docs.renovatebot.com/configuration-options/)することで `.circleci/config.yml` 内の上記の `terraform_version` を更新できるようにしてみた。

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "assignees": ["yteraoka"],
  "extends": [
    "config:base"
  ],
  "packageRules": [
    {
      "matchManagers": ["terraform"],
      "matchDepTypes": ["required_version"],
      "groupName": "Terraform",
      "addLabels": ["terraform-version"]
    },
    {
      "matchManagers": ["asdf"],
      "matchPackageNames": ["hashicorp/terraform"],
      "groupName": "Terraform",
      "addLabels": ["terraform-version"]
    },
    {
      "matchManagers": ["regex"],
      "matchDepPatterns": ["terraform"],
      "groupName": "Terraform",
      "addLabels": ["terraform-version"]
    }
  ],
  "customManagers": [
    {
      "customType": "regex",
      "fileMatch": ["\\.circleci/config\\.ya?ml"],
      "matchStrings": [
        "terraform_version: *(?<currentValue>\\d+\\.\\d+\\.\\d+)"
      ],
      "datasourceTemplate": "github-releases",
      "depNameTemplate": "hashicorp/terraform",
      "extractVersionTemplate": "^v(?<version>.*)$"
    }
  ]
}
```

renovate の設定ファイルはとっつきづら過ぎて全然理解できてないけど一応更新された。

[Renovate config の変更が想定通りか確認する 〜真の dry-run を求めて〜](https://zenn.dev/cybozu_ept/articles/compare-renovate-dry-run) で紹介されている dry-run 方法を見てエラーになってる箇所を見つけることが出来ました。

```bash
#!/bin/bash

export LOG_LEVEL=debug

owner=$(basename $(dirname $(pwd)))
repo=$(basename $(pwd))

renovate \
  --token $(gh auth token) \
  --dry-run \
  --schedule= \
  --require-config=renovate.json \
  ${owner}/${repo}
```

もしかすると issue に作られている dashboard でも確認できたのだろうか？


