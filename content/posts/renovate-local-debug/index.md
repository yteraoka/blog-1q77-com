---
title: "Renovate を手元の repository に対して debug 実行する"
date: 2025-01-28T19:45:08+09:00
draft: false
tags: [renovate]
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

`full` を指定すると Pull Request (Merge Request) の作成内容もログに出力します。

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

ついでなのでメモ

Self-hosted な GitLab の repository を対象に実行する方法

`--platform` で gitlab を指定する。GitLab で Merge Request を作成可能な権限の Personal Access Token (scopes: api, read_user, write_repository) を作成し、`RENOVATE_TOKEN` 環境変数にセットする。

対象の branch がデフォルト branch 以外の場合に `RENOVATE_BRANCH_NAME` で指定可能。

dry-run で確認

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

実際に実行

```bash
RENOVATE_BRANCH_NAME="feature/renovate-config" \
npx renovate \
  --platform=gitlab \
  --endpoint=https://gitlab.example.com/api/v4 \
  --schedule="" \
  mygroup/myrepo
```

対象の repository に renovate.json が存在しない場合は、renovate.json を作成する onboarding Merge Request が作成されるだけで、それを Merge した後は更新の Merge Request が作成されるようになる。
設定にもよるが。

