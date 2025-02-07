---
title: "Renovate を手元の repository に対して debug 実行する"
description: |
  renovate のカスタマイズをする際に手元で動作確認する方法
date: 2025-01-28T19:45:08+09:00
draft: false
tags: [renovate]
image: cover.png
author: "@yteraoka"
categories:
  - CI/CD
---

[renovate](https://docs.renovatebot.com/) の設定を手元で試行錯誤したい時のメモです。

## Local Platform

`--platform=local` を指定して実行すると local filesystem を対象として renovate を実行することができます。

https://docs.renovatebot.com/modules/platform/local/

手元の working copy の root directory で実行します。(npx は使わなくても良いが install からやってくれるので)

```bash
npx renovate --platform=local
```

log level を debug にすることでより詳細なログを確認することができる。(デフォルトは info)

```bash
LOG_LEVEL=debug npx renovate --platform=local
```

local platform の場合、[dryRun](https://docs.renovatebot.com/self-hosted-configuration/#dryrun) (`--dry-run`) オプションがデフォルトで `lookup` となります。

`lookup` では依存関係を調べて更新があるかどうかを見つけるためにパッケージのスキャンを行います。

`full` を指定すると Pull Request (Merge Request) の作成に関するログに出力します。しかし、local では機能しないため、これは remote repository を対象として実行する必要があります。

`extract` では依存関係を抽出するだけのスキャンに留めます。

## GitHub Token

GitHub から version や release の情報を取得する必要のあるものについては GitHub の token を指定する必要があります。

指定していない場合、例えば次のような出力が確認できます。

```
 WARN: GitHub token is required for some dependencies (repository=local)
       "githubDeps": [
         "terraform",
         "golang",
         "python",
         "actions/checkout",
         "hashicorp/terraform"
       ]
```

public な repository への依存だけであれば [Fine-grained personal access token](https://github.com/settings/personal-access-tokens) で Repository access の __Public Repositories (read-only)__ にチェックを入れるだけの token で良いです。
`GITHUB_COM_TOKEN` という環境変数に設定します。

## 手元から Self-hosted な GitLab 上の repository に対して実行する方法

Pull Request / Merge Request に関する情報は `--platform=local` では確認できず、GitLab や GitHub のサーバーを指定して `--dry-run=full` を付けて実行する必要がありました。

### Self-hosted な GitLab の repository を対象に実行する方法

`--platform=gitlab` を指定する。GitLab で Merge Request を作成可能な権限の Personal Access Token (scopes: api, read_user, write_repository) を作成し、`RENOVATE_TOKEN` 環境変数にセットする。

対象の branch がデフォルト branch 以外の場合には `RENOVATE_BRANCH_NAME` で指定可能。

remote repository を指定する場合は renovate が ${TMPDIR}/renovate に git clone して実行してくれるので current working directory には何も必要がありません。

**dry-run で確認**

```bash
LOG_LEVEL=debug \
RENOVATE_BRANCH_NAME="feature/renovate-config" \
npx renovate \
  --platform=gitlab \
  --endpoint=https://gitlab.example.com/api/v4 \
  --schedule="" \
  --dry-run=full \
  mygroup/myrepo
```

`--schedule=""` は利用する renovate.json などで指定されている schedule をデフォルトの　`at any time` で上書きするための指定なので必須ではありません。

**実際に実行**

```bash
RENOVATE_BRANCH_NAME="feature/renovate-config" \
npx renovate \
  --platform=gitlab \
  --endpoint=https://gitlab.example.com/api/v4 \
  --schedule="" \
  mygroup/myrepo
```

対象の repository に renovate.json が存在しない場合は、renovate.json を作成する onboarding Merge Request が作成されるだけで、それを Merge した後は更新の Merge Request が作成されるようになる。

### 手元の renovate.json を使ってテストする

手元に用意した renovate.json を使った動作確認をしたいことが多いと思うが、そのためには `RENOVATE_CONFIG_FILE` に手元のファイルを指定し、 `--require-config=ignored` を追加する必要がありました。

renovate の設定はその意図をコメントで残せるように renovate.[json5](https://json5.org/) を利用する方が良いかもしれない。

```bash
LOG_LEVEL=debug \
RENOVATE_CONFIG_FILE=renovate.json5 \
npx renovate \
  --platform=gitlab \
  --endpoint=https://gitlab.example.com/api/v4 \
  --schedule="" \
  --dry-run=full \
  --require-config=ignored \
  mygroup/myrepo
```
