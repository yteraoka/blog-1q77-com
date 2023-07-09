---
title: "Amazon SES から Lambda を起動して Cloud PubSub に Publish する"
date: 2023-07-07T23:42:54+09:00
draft: false
---

以前、「[LINE に送ったメッセージを Google Home に読み上げさせる](/2023/02/line-bot-tts/)」という記事を書きました。
その時に作ったものに家にあるラズパイで Cloud PubSub を subscribe してメッセージが届いたらその内容を Text-to-Speach で音声化して Google Home で再生する仕組みが存在します。

## やりたいこと

今回はメール受信をトリガーにして Google Home に喋らせたいと思いました。
塾側のシステムで息子が塾に行った時と帰る時にメールを送ってくれるようにはなっているのですが、家に着くであろう時刻を知るのにメールをわざわざ見なくてもよくしたかったのです。

## 構成を考える

メール受信をトリガーにしてなにかを実行するのに使えるサービスには何があるだろうかと考えたのですが Amazon SES しか思いつきませんでした。

Amazon SES には[受信機能](https://docs.aws.amazon.com/ses/latest/dg/receiving-email.html)があり、[受信をトリガーに Lambda を実行する](https://docs.aws.amazon.com/ses/latest/dg/receiving-email-action-lambda.html)ことができます。
この Lambda でメッセージを前回作った Cloud PubSub Topic に送ることでやりたいことはできそうです。

マルチクラウドになって面倒ですが、今は AWS の IAM Role でも private key 無しで Google Cloud の ServiceAccount を使えるようになっているのでこれも活用してみます。

- [AWS または Azure との Workload Identity 連携を構成する](https://cloud.google.com/iam/docs/workload-identity-federation-with-other-clouds)

## Amazon SES でメール受信できるようにする

SES での受信は東京リージョンでは提供されていないためバージニアリージョン (us-east-1) を使用することにしました。

受信したメールは S3 に保存した後、Lambda を実行することにします。
受信のためのルールを設定するためには依存する S3 Bucket と Lambda が先に存在する必要があったので次の順番でリソースを作成します。

- S3 Bucket 作成
- Lambda Function 作成
- SES 受信設定

S3 に保存しなくてもメールのヘッダー情報は Lambda に渡されます。私の今回の要件でも Subject さえ受信できれば良かったので、Lambda では S3 の object にはアクセスしていませんが、Gmail からの転送先としてメールアドレスを登録する際にそのアドレス宛のメールが受信できることを確認できる必要があり、そのためには届いたメールの本文にある URL にアクセスする必要があります。
このために S3 からメールを取り出して対処しました。

次から terraform の設定例を書いてみます。

### 変数定義

依存関係の問題でリソース参照ができないところがあるので変数として定義しておく

```hcl
locals {
  receipt_rule_set_name                 = "ルールセット名"
  receipt_rule_name                     = "ルール名"
  function_name                         = "Lambda function 名"
  lambda_role_name                      = "Lambda 用 IAM Role 名"
  pubsub_topic_name                     = "Cloud PubSub Topic 名"
  google_project_id                     = "Google Project ID"
  google_project_number                 = "Google Project Number"
  email_address                         = "受信用メールアドレス"
  google_workload_identity_pool_name    = "aws-pool"
  google_workload_identity_provder_name = "my-aws-provider"
}
```

### provider 設定

東京リージョンのリソースをすでに管理している terraform リポジトリに追加するのでバージニア用のエイリアスを定義します。

```hcl
provider "aws" {
  alias  = "virginia"
  region = "us-east-1"
}
```

### S3 Bucket 作成

S3 Bucket の作成

```hcl
resource "aws_s3_bucket" "mail_received" {
  provider = aws.virginia
  bucket   = "バケット名"
}
```

SES サービスが Object を保存することができるように bucket policy を設定する

```hcl
data "aws_iam_policy_document" "ses_writable" {
  statement {
    sid       = "AllowSESPuts"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.mail_received.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      # 依存関係の問題で aws_ses_receipt_rule の arn を使えない
      values   = ["arn:aws:ses:us-east-1:${data.aws_caller_identity.current.account_id}:receipt-rule-set/${receipt_rule_set_name}:receipt-rule/${local.receipt_rule_name}"]
    }
  }
}

resource "aws_s3_bucket_policy" "mail_received" {
  provider = aws.virginia
  bucket   = aws_s3_bucket.mail_received.id
  policy   = data.aws_iam_policy_document.ses_writable.json
}
```

### Lambda Function 作成

Go言語で実装しました。Container でデプロイしようかとも考えたのですが無駄に image が大きくなるので [zip ファイルでデプロイする](https://docs.aws.amazon.com/lambda/latest/dg/golang-package.html)ことにしました。

Go の場合、次の package を使うと非常に簡単に実装できました。

- [github.com/aws/aws-lambda-go/events](https://github.com/aws/aws-lambda-go/blob/main/events/README_SES.md)
- [github.com/aws/aws-lambda-go/lambda](https://docs.aws.amazon.com/lambda/latest/dg/golang-handler.html) ([GitHub](https://github.com/aws/aws-lambda-go/tree/main/lambda))

### zip ファイルの作成

`main` というファイル名で実行ファイルを build して `main.zip` という zip ファイルとして保存します。

```bash
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o main
zip main.zip main
```

zip ファイルの hash 値を得るために `local_file` の data resource で指定します。

```hcl
data "local_file" "lambda_zip" {
  filename = "${path.module}/main.zip"
}
```

### LogGroup 作成

保持期間を指定したいので Log Group も terraform で作成する。

```hcl
resource "aws_cloudwatch_log_group" "lambda" {
  provider          = aws.virginia
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 14
}
```

### Lambda 用 IAM Role 作成

Lambda Function の実行用 IAM Role 作成

```hcl
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = local.lambda_role_name
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

# CloudWatch Logs へのログ出力と lambda 関連の許可
data "aws_iam_policy_document" "lambda" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    effect    = "Allow"
    resources = ["*"]
  }
  statement {
    actions   = ["lambda:*"]
    effect    = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lambda" {
  name   = "{Lambda 用 IAM Policy 名}"
  policy = data.aws_iam_policy_document.lambda.json
}

# Policy を Role に紐付ける
resource "aws_iam_role_policy_attachment" "ses_to_cloud_pubsub" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda.arn
}
```

### Google Cloud で identity provider 設定

Lambda 関数の環境変数で設定するために Google の Workload Identity Federation 設定を行う

(aws 用の terraform と一緒に管理するかどうかわからないけど一緒になってる前提で変数を使っている)

```hcl
resource "google_iam_workload_identity_pool" "aws" {
  workload_identity_pool_id = local.google_workload_identity_pool_name
  display_name              = local.google_workload_identity_pool_name
}

resource "google_iam_workload_identity_pool_provider" "aws_main" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.aws.workload_identity_pool_id
  workload_identity_pool_provider_id = local.google_workload_identity_provder_name
  display_name                       = local.google_workload_identity_provder_name
  attribute_mapping = {
    "google.subject"     = "assertion.arn"
    "attribute.aws_role" = "assertion.arn.extract('assumed-role/{role}/')"
  }
  aws {
    account_id = data.aws_caller_identity.current.account_id
  }
}
```

### Google Cloud で Service Account の設定

ServiceAccount の作成

```hcl
resource "google_service_account" "aws_ses_to_pubsub" {
  project      = local.project_id
  account_id   = "ses-to-pubsub"
  display_name = "AWS SES to Cloud PubSub Lambda"
}
```

ServiceAccount に対して Topic への Publish を許可する

```hcl
resource "google_pubsub_topic_iam_member" "aws_ses_to_pubsub" {
  project = google_pubsub_topic.topic.project
  topic   = google_pubsub_topic.topic.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.aws_ses_to_pubsub.email}"
}
```

ServiceAccount を AWS の特定の IAM Role から利用可能にする

```hcl
resource "google_service_account_iam_member" "aws_ses_to_pubsub" {
  service_account_id = google_service_account.aws_ses_to_pubsub.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.aws.name}/attribute.aws_role/${local.lambda_role_name}"
}
```

### Lambda Function 作成

Workload Identity 連携させる場合、`GOOGLE_APPLICATION_CREDENTIALS` で指定するファイルに
Google から提供される JSON を保存しておく必要がある。この JSON に秘密鍵は入っていない。

この JSON は Google Cloud の Console で `IAM & Admin` → `Workload Identity Federation` にアクセスし、AWS 用の pool を選択すると右側に `PROVIDERS`、`CONNECTED SERVICE ACCOUNTS` タブがあり、`CONNECTED SERVICE ACCOUNTS` で今回作成したアカウントの右 (Client Library Config 列) にある `DOWNLOAD` リンクから JSON ファイルをダウンロードする。

- [ID 連携により有効期間の短い認証情報を取得する](https://cloud.google.com/iam/docs/using-workload-identity-federation?hl=ja#generate-automatic)
- [External Account Credentials (Workload Identity Federation)](https://google.aip.dev/auth/4117)

今回の Go のコードでは `init()` の中で `GOOGLE_APPLICATION_CREDENTIALS_VALUE` で指定された値を
`GOOGLE_APPLICATION_CREDENTIALS` ファイルに保存するようにした。

```hcl
resource "aws_lambda_function" "ses_to_cloud_pubsub" {
  provider         = aws.virginia
  function_name    = local.function_name
  filename         = "${path.module}/main.zip"
  role             = aws_iam_role.lambda.arn
  handler          = "main"
  source_code_hash = data.local_file.lambda_zip.content_sha256
  runtime          = "go1.x"
  timeout          = 10

  environment {
    variables = {
      PUBSUB_TOPIC_NAME                    = local.pubsub_topic_name
      GOOGLE_PROJECT_ID                    = local.google_project_id
      GOOGLE_APPLICATION_CREDENTIALS       = "/tmp/google.json"
      GOOGLE_APPLICATION_CREDENTIALS_VALUE = <<EOT
{
  "type": "external_account",
  "audience": "//iam.googleapis.com/projects/${local.google_project_number}/locations/global/workloadIdentityPools/${local.google_workload_identity_pool_name}/providers/${local.google_workload_identity_provder_name}",
  "subject_token_type": "urn:ietf:params:aws:token-type:aws4_request",
  "service_account_impersonation_url": "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${local.google_service_account_email}:generateAccessToken",
  "token_url": "https://sts.googleapis.com/v1/token",
  "credential_source": {
    "environment_id": "aws1",
    "region_url": "http://169.254.169.254/latest/meta-data/placement/availability-zone",
    "url": "http://169.254.169.254/latest/meta-data/iam/security-credentials",
    "regional_cred_verification_url": "https://sts.{region}.amazonaws.com?Action=GetCallerIdentity&Version=2011-06-15"
  }
}
EOT
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
  ]
}
```

### SES が Lambda を実行できるようにする

```hcl
resource "aws_lambda_permission" "ses_to_cloud_pubsub" {
  provider       = aws.virginia
  action         = "lambda:InvokeFunction"
  function_name  = local.function_name
  principal      = "ses.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
  source_arn     = ["arn:aws:ses:us-east-1:${data.aws_caller_identity.current.account_id}:receipt-rule-set/${receipt_rule_set_name}:receipt-rule/${local.receipt_rule_name}"]
}
```

### SES の受信設定

過去にすでに設定したことがあったのでもうドメインは使えるようになっていました。

以前の設定ですでに `default-rule-set` というルールセットが存在しました。

```hcl
resource "aws_ses_receipt_rule_set" "rule_set" {
  rule_set_name = local.receipt_rule_set_name
}
```

```hcl
resource "aws_ses_receipt_rule" "rule" {
  provider      = aws.virginia
  name          = local.receipt_rule_name
  rule_set_name = local.receipt_rule_set_name
  recipients    = [local.email_address]
  enabled       = true
  scan_enabled  = true
  tls_policy    = "Require"

  s3_action {
    position          = 1
    bucket_name       = aws_s3_bucket.mail_received.id
    object_key_prefix = ""
  }

  lambda_action {
    function_arn    = aws_lambda_function.ses_to_cloud_pubsub.arn
    invocation_type = "Event"
    position        = 2
  }

  depends_on = [
    aws_s3_bucket.mail_received,
    aws_s3_bucket_policy.mail_received,
    aws_lambda_permission.ses_to_cloud_pubsub,
  ]
}
```

