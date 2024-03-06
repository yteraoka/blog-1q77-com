---
title: Azure Container Apps Jobs を Self-hosted GitHub Actions Runner として使う
date: 2024-02-23T19:05:41+09:00
draft: false
tags: [Azure, GitHub]
---
GitHub Actions の Self-hosted Runner を安く用意する方法を探していたところ、
Azure の Container Apps Jobs というのが便利に使えるらしいというのを見つけたので試してみる。

[チュートリアル:Azure Container Apps ジョブを使用してセルフホスト型 CI/CD ランナーとエージェントをデプロイする](https://learn.microsoft.com/ja-jp/azure/container-apps/tutorial-ci-cd-runners-jobs?tabs=bash&pivots=container-apps-jobs-self-hosted-ci-cd-github-actions)
をなぞるだけです。

## 準備

Azure のアカウントは作成済みとする（[無料で作成できる](https://azure.microsoft.com/free/)）

環境は Windows 11 の WSL

### Azure CLI のインストール

[Azure CLI](https://learn.microsoft.com/ja-jp/cli/azure/)

```bash
brew install azure-cli
```

### Azure にログイン

```bash
az login
```

Windows の場合は[Web アカウント マネージャー](https://learn.microsoft.com/ja-jp/windows/uwp/security/web-account-manager)を使うと便利らしい。

### Azure Container Apps 拡張機能をインストール

```bash
az extension add --name containerapp --upgrade
```

### Azure サブスクリプションに Microsoft.App と Microsoft.OperationalInsights 名前空間を登録

ちょっとなんのことだかわからないけどコピペ

```bash
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights
```

```bash
az provider show -n Microsoft.App | jq '{namespace: .namespace, registrationState: .registrationState}'
```

```bash
az provider show -n Microsoft.OperationalInsights | jq '{namespace: .namespace, registrationState: .registrationState}'
```

`registrationState` が `Registering` から `Registered` に変わったら OK

```json
{
  "namespace": "Microsoft.App",
  "registrationState": "Registered"
}
```

```json
{
  "namespace": "Microsoft.OperationalInsights",
  "registrationState": "Registered"
}
```

### 変数設定

後の作業で使う変数を定義しておく

```bash
RESOURCE_GROUP="github-actions-runner"
LOCATION="japaneast"
ENVIRONMENT="env-github-actions-runner"
JOB_NAME="github-actions-runner-job"
```

## Azure のリソース作成

### リソースグループの作成

リソースグループを分けておくことで不要になったときに丸っと削除することができる

```bash
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION"
```

<details>
<summary>response</summary>

```json
{
  "id": "/subscriptions/*****/resourceGroups/github-actions-runner",
  "location": "japaneast",
  "managedBy": null,
  "name": "github-actions-runner",
  "properties": {
    "provisioningState": "Succeeded"
  },
  "tags": null,
  "type": "Microsoft.Resources/resourceGroups"
}
```
</details>

### Container Apps 環境の作成

```bash
az containerapp env create \
    --name "$ENVIRONMENT" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION"
```

> The behavior of this command has been altered by the following extension: containerapp
> No Log Analytics workspace provided.
> Generating a Log Analytics workspace with name "workspace-githubactionsrunnereINU"

Log Analytics workspace も自動で作成されたっぽい。これがなんだかわからないけど。

```bash
$ az containerapp env list \
  | jq '.[] | {name: .name, endpoint: .properties.eventStreamEndpoint}'
```

で、こんな出力が得られる。

```json
{
  "name": "env-github-actions-runner",
  "endpoint": "https://japaneast.azurecontainerapps.dev/subscriptions/*****/resourceGroups/github-actions-runner/managedEnvironments/env-github-actions-runner/eventstream"
}
```

GitHub からの webhook event をこの endpoint に送るのかな？って思ったけど違うらしい。

## GitHub 側の作業

Self-hosted Runner を使いたいリポジトリはすでに存在するものとする

### GitHub の Personal Access Token (PAT) を取得する

GitHub App じゃなくて個人の PAT じゃなきゃダメなのか？ (GitHub App でもできることは後でわかった)

[Fine-grained tokens](https://github.com/settings/tokens?type=beta) で Generate new token をクリック

Repository access は Only select repositories で self-hosted runner の必要なリポジトリを選択

Permissions は Repository permissions で

- Actions: Read-only
- Administration: Read and write
- Metadata: Read-only (mandatory)

作成された token をメモしておく

後で使うので変数に値を入れておく

```bash
GITHUB_PAT="<GITHUB_PAT>"
REPO_OWNER="<REPO_OWNER>"
REPO_NAME="<REPO_NAME>"
```


## Runner 用の Container Image を build する

### Container Image の名前を決める

```bash
CONTAINER_IMAGE_NAME="github-actions-runner:1.0"
CONTAINER_REGISTRY_NAME="<CONTAINER_REGISTRY_NAME>"
```

> `<CONTAINER_REGISTRY_NAME>` を、コンテナー レジストリを作成するための一意の名前に置き換えます。
> コンテナー レジストリ名は、"Azure 内で一意" であり、数字と小文字のみを含む 5 文字から 50 文字の長さにする必要があります。

registry server が `<CONTAINER_REGISTRY_NAME>.azurecr.io` になる。

### Container Registry の作成

```bash
az acr create \
    --name "$CONTAINER_REGISTRY_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku Basic \
    --admin-enabled true
```

### Image の build と push

Azure Container Registry ってこうやって build できるのか、ちょっと便利そう

```bash
az acr build \
    --registry "$CONTAINER_REGISTRY_NAME" \
    --image "$CONTAINER_IMAGE_NAME" \
    --file "Dockerfile.github" \
    "https://github.com/Azure-Samples/container-apps-ci-cd-runner-tutorial.git"
```

### Self-hosted runner を Job として deploy する

```bash
az containerapp job create -n "$JOB_NAME" -g "$RESOURCE_GROUP" --environment "$ENVIRONMENT" \
    --trigger-type Event \
    --replica-timeout 1800 \
    --replica-retry-limit 0 \
    --replica-completion-count 1 \
    --parallelism 1 \
    --image "$CONTAINER_REGISTRY_NAME.azurecr.io/$CONTAINER_IMAGE_NAME" \
    --min-executions 0 \
    --max-executions 10 \
    --polling-interval 30 \
    --scale-rule-name "github-runner" \
    --scale-rule-type "github-runner" \
    --scale-rule-metadata \
        "githubAPIURL=https://api.github.com" \
        "owner=$REPO_OWNER" \
        "runnerScope=repo" \
        "repos=$REPO_NAME" \
        "targetWorkflowQueueLength=1" \
    --scale-rule-auth "personalAccessToken=personal-access-token" \
    --cpu "2.0" \
    --memory "4Gi" \
    --secrets "personal-access-token=$GITHUB_PAT" \
    --env-vars \
        "GITHUB_PAT=secretref:personal-access-token" \
        "REPO_URL=https://github.com/$REPO_OWNER/$REPO_NAME" \
        "REGISTRATION_TOKEN_API_URL=https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/actions/runners/registration-token" \
    --registry-server "$CONTAINER_REGISTRY_NAME.azurecr.io"
```

KEDA の [Github Runner Scaler](https://keda.sh/docs/2.13/scalers/github-runner/) というのが使われているようで
`--polling-interval 30` (30秒) 間隔で GitHub の API にアクセスして実行待ちの Job が無いかを探す。
GitHub App を使う方法も書いてあった。

Polling から実行が必要だと判断されてコンテナが起動されると [entrypoint.sh](https://github.com/Azure-Samples/container-apps-ci-cd-runner-tutorial/blob/d9175f4c0fe094736677640f0867dc88f0ccfc3d/github-actions-runner/entrypoint.sh) の中で runner の登録と実行が行われるようになっている。
Runner 登録のための token 取得処理が Personal Access Token 前提になっているため GitHub App を使う場合はここの処理を書き換える必要がある。

GitHub App の場合は JWT を作ったりする必要があるのですが、先人が公開してくれていました。
[Github ActionsのセルフホステッドランナーにAzure Container Apps(ACA) jobsを活用する](https://qiita.com/kazu_yasu/items/4fd578b35752968a3bb4#github-app%E3%82%92%E4%BD%BF%E7%94%A8%E3%81%99%E3%82%8B) (Qiita)

### actions/setup-python が機能しない問題（解決済み）

Workflow の Job の中で python script を実行したかったので actions/setup-python を使っていたのですが、次の出力でコケてしまっていました。
前半の cache に無いというメッセージは良いのですが、インストールにも失敗しているのに理由が不明で困りました。
実行環境は Linux で x64 なので 3.12.2 はリストに存在するバージョンです。

```
Version 3.12.2 was not found in the local cache
Error: The version '3.12.2' with architecture 'x64' was not found for this operating system.
The list of all available versions can be found here: https://raw.githubusercontent.com/actions/python-versions/main/versions-manifest.json
```

調べていてたどり着いたのが [actions/setup-python #401](https://github.com/actions/setup-python/issues/401#issuecomment-1150563156) でした。
「Debian はサポートしていません」え...

Container Image は [github.com/Azure-Samples/container-apps-ci-cd-runner-tutorial](https://github.com/Azure-Samples/container-apps-ci-cd-runner-tutorial) にある [Dockerfile.github](https://github.com/Azure-Samples/container-apps-ci-cd-runner-tutorial/blob/d9175f4c0fe094736677640f0867dc88f0ccfc3d/Dockerfile.github) を使って build したもので Base image は [ghcr.io/actions/actions-runner:2.304.0](https://github.com/actions/runner/pkgs/container/actions-runner/95489409?tag=2.304.0) で、これが Debian だったのです。
この [actions/runner](https://github.com/actions/runner) リポジトリで公開されている image なのに?! と思いましたが、最新の image を確認したら Ubuntu に変わってました。
[v2.305.0](https://github.com/actions/runner/releases/tag/v2.305.0) で変わったようです、Base image として使われていたやつの次のリリースですね...

Dockerfile を編集して build したら手元から push しました。この場合、`az acr build` コマンドではないので `az acr login --name $CONTAINER_REGISTRY_NAME` でログインして docker push しました。
Container Apps Job は delete して再作成しました。update コマンド調べるの面倒だったので。

```bash
az containerapp job delete -n "$JOB_NAME" -g "$RESOURCE_GROUP"
```


### Azure リソースの削除

不要になったらリソースグループごとまるっと削除です。

```bash
az group delete \
    --resource-group $RESOURCE_GROUP
```

以上、引き出しに入れておこう。
