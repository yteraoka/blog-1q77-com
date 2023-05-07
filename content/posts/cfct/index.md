---
title: "Customizations for AWS Control Tower (CfCT)"
date: 2023-05-07T20:57:41+09:00
tags: ["AWS"]
draft: false
---

## Control Tower を有効にする

ap-northeast-1 を Home Region として有効化済みの状態からはじめる。

## Prerequisites

SRA 設定を使用する場合は [SRA Prerequisites](https://github.com/aws-samples/aws-security-reference-architecture-examples/tree/main/aws_sra_examples/solutions/common/common_prerequisites#15-aws-ssm-parameter-store) が deploy 済みでなければならない。

- Trusted Access for AWS CloudFormation StackSets を有効にする ([AWS Docs](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacksets-orgs-enable-trusted-access.html))
  - CloudFormation Console で StackSets にアクセスして、上部に `Activate trusted access with AWS Organizations to use service-managed permissions.` と表示され `Activate trusted access` というボタンがあればクリックする
  - AWS Organizations console page から `Services` を開き `CloudFormation StackSets` が `Access enabled` になっていることを確認する
- [Download and Stage the AWS SRA Solutions](https://github.com/aws-samples/aws-security-reference-architecture-examples/blob/main/aws_sra_examples/docs/DOWNLOAD-AND-STAGE-SOLUTIONS.md)
  - awscli をインストールし、`sra-management` という名前の profile でアクセス可能にする (`aws configure --profile sra-management`)


```
git clone https://github.com/aws-samples/aws-security-reference-architecture-examples.git $HOME/aws-sra-examples
cd $HOME/aws-sra-examples
```

```
aws cloudformation deploy \
  --template-file $HOME/aws-sra-examples/aws_sra_examples/solutions/common/common_prerequisites/templates/sra-common-prerequisites-staging-s3-bucket.yaml \
  --stack-name sra-common-prerequisites-staging-s3-bucket \
  --capabilities CAPABILITY_NAMED_IAM
```

<details>
<summary>実行ログ</summary>

```
Waiting for changeset to be created..
Waiting for stack create/update to complete
Successfully created/updated stack - sra-common-prerequisites-staging-s3-bucket
```

</details>

```
bash $HOME/aws-sra-examples/aws_sra_examples/utils/packaging_scripts/stage_solution.sh
```

(ドキュメントでは bash ではなく sh となっていたが、手元の Ubuntu 22.04 では /usr/bin/sh が dash なので bash の構文は解釈できずにコケた)

<details>
<summary>実行ログ</summary>

```
$ bash $HOME/aws-sra-examples/aws_sra_examples/utils/packaging_scripts/stage_solution.sh
...Creating the sra_staging_manual_upload folder
------------------------------------------------------------
-- Solution: sra-account-alternate-contacts
------------------------------------------------------------
...Stage CloudFormation Templates
...Package and Stage Lambda Code
...Creating the temporary packaging folder (tmp_sra_lambda_src_XXXX)
...Creating zip file from the temp folder contents
...Removing Temporary Folder /home/teraoka/temp_sra_lambda_src_xIR4
...CloudFormation templates uploaded to sra-staging-614212495865-ap-northeast-1/sra-account-alternate-contacts/templates/
...Lambda zip files uploaded to sra-staging-614212495865-ap-northeast-1/sra-account-alternate-contacts/lambda_code/
...Lambda function sra-account-alternate-contacts not found to update
------------------------------------------------------------
-- Solution: sra-cloudtrail-org
------------------------------------------------------------
...Stage CloudFormation Templates
...Package and Stage Lambda Code
...Creating the temporary packaging folder (tmp_sra_lambda_src_XXXX)
...Creating zip file from the temp folder contents
...Removing Temporary Folder /home/teraoka/temp_sra_lambda_src_esK6
...CloudFormation templates uploaded to sra-staging-614212495865-ap-northeast-1/sra-cloudtrail-org/templates/
...Lambda zip files uploaded to sra-staging-614212495865-ap-northeast-1/sra-cloudtrail-org/lambda_code/
...Lambda function sra-cloudtrail-org not found to update
------------------------------------------------------------
-- Solution: sra-common-cfct-setup
------------------------------------------------------------
...Stage CloudFormation Templates
...CloudFormation templates uploaded to sra-staging-614212495865-ap-northeast-1/sra-common-cfct-setup/templates/
------------------------------------------------------------
-- Solution: sra-common-prerequisites
------------------------------------------------------------
...Stage CloudFormation Templates
...Package and Stage Lambda Code
...Creating the temporary packaging folder (tmp_sra_lambda_src_XXXX)
...Creating zip file from the temp folder contents
...Removing Temporary Folder /home/teraoka/temp_sra_lambda_src_psKd
...CloudFormation templates uploaded to sra-staging-614212495865-ap-northeast-1/sra-common-prerequisites/templates/
...Lambda zip files uploaded to sra-staging-614212495865-ap-northeast-1/sra-common-prerequisites/lambda_code/
...Lambda function sra-common-prerequisites not found to update
------------------------------------------------------------
-- Solution: sra-common-register-delegated-administrator
------------------------------------------------------------
...Stage CloudFormation Templates
...Package and Stage Lambda Code
...Creating the temporary packaging folder (tmp_sra_lambda_src_XXXX)
...Creating zip file from the temp folder contents
...Removing Temporary Folder /home/teraoka/temp_sra_lambda_src_f41x
...CloudFormation templates uploaded to sra-staging-614212495865-ap-northeast-1/sra-common-register-delegated-administrator/templates/
...Lambda zip files uploaded to sra-staging-614212495865-ap-northeast-1/sra-common-register-delegated-administrator/lambda_code/
...Lambda function sra-common-register-delegated-administrator not found to update
------------------------------------------------------------
-- Solution: sra-config-aggregator-org
------------------------------------------------------------
...Stage CloudFormation Templates
...CloudFormation templates uploaded to sra-staging-614212495865-ap-northeast-1/sra-config-aggregator-org/templates/
------------------------------------------------------------
-- Solution: sra-config-conformance-pack-org
------------------------------------------------------------
...Stage CloudFormation Templates
...CloudFormation templates uploaded to sra-staging-614212495865-ap-northeast-1/sra-config-conformance-pack-org/templates/
------------------------------------------------------------
-- Solution: sra-config-management-account
------------------------------------------------------------
...Stage CloudFormation Templates
...Package and Stage Lambda Code
...Creating the temporary packaging folder (tmp_sra_lambda_src_XXXX)
...Creating zip file from the temp folder contents
...Removing Temporary Folder /home/teraoka/temp_sra_lambda_src_UrE9
...CloudFormation templates uploaded to sra-staging-614212495865-ap-northeast-1/sra-config-management-account/templates/
...Lambda zip files uploaded to sra-staging-614212495865-ap-northeast-1/sra-config-management-account/lambda_code/
...Lambda function sra-config-management-account not found to update
------------------------------------------------------------
-- Solution: sra-ec2-default-ebs-encryption
------------------------------------------------------------
...Stage CloudFormation Templates
...Package and Stage Lambda Code
...Creating the temporary packaging folder (tmp_sra_lambda_src_XXXX)
...Creating zip file from the temp folder contents
...Removing Temporary Folder /home/teraoka/temp_sra_lambda_src_cPyB
...CloudFormation templates uploaded to sra-staging-614212495865-ap-northeast-1/sra-ec2-default-ebs-encryption/templates/
...Lambda zip files uploaded to sra-staging-614212495865-ap-northeast-1/sra-ec2-default-ebs-encryption/lambda_code/
...Lambda function sra-ec2-default-ebs-encryption not found to update
------------------------------------------------------------
-- Solution: sra-firewall-manager-org
------------------------------------------------------------
...Stage CloudFormation Templates
...Package and Stage Lambda Code
...Creating the temporary packaging folder (tmp_sra_lambda_src_XXXX)
...Creating zip file from the temp folder contents
...Removing Temporary Folder /home/teraoka/temp_sra_lambda_src_KUJ4
...CloudFormation templates uploaded to sra-staging-614212495865-ap-northeast-1/sra-firewall-manager-org/templates/
...Lambda zip files uploaded to sra-staging-614212495865-ap-northeast-1/sra-firewall-manager-org/lambda_code/
...Lambda function sra-firewall-manager-org not found to update
------------------------------------------------------------
-- Solution: sra-guardduty-org
------------------------------------------------------------
...Stage CloudFormation Templates
...Package and Stage Lambda Code
...Creating the temporary packaging folder (tmp_sra_lambda_src_XXXX)
...Creating zip file from the temp folder contents
...Removing Temporary Folder /home/teraoka/temp_sra_lambda_src_hk3z
...CloudFormation templates uploaded to sra-staging-614212495865-ap-northeast-1/sra-guardduty-org/templates/
...Lambda zip files uploaded to sra-staging-614212495865-ap-northeast-1/sra-guardduty-org/lambda_code/
...Lambda function sra-guardduty-org not found to update
------------------------------------------------------------
-- Solution: sra-iam-access-analyzer
------------------------------------------------------------
...Stage CloudFormation Templates
...CloudFormation templates uploaded to sra-staging-614212495865-ap-northeast-1/sra-iam-access-analyzer/templates/
------------------------------------------------------------
-- Solution: sra-iam-password-policy
------------------------------------------------------------
...Stage CloudFormation Templates
...Package and Stage Lambda Code
...Creating the temporary packaging folder (tmp_sra_lambda_src_XXXX)
...Creating zip file from the temp folder contents
...Removing Temporary Folder /home/teraoka/temp_sra_lambda_src_Rmah
...CloudFormation templates uploaded to sra-staging-614212495865-ap-northeast-1/sra-iam-password-policy/templates/
...Lambda zip files uploaded to sra-staging-614212495865-ap-northeast-1/sra-iam-password-policy/lambda_code/
...Lambda function sra-iam-password-policy not found to update
------------------------------------------------------------
-- Solution: sra-inspector-org
------------------------------------------------------------
...Stage CloudFormation Templates
...Package and Stage Lambda Code
...Creating the temporary packaging folder (tmp_sra_lambda_src_XXXX)
...Creating zip file from the temp folder contents
...Removing Temporary Folder /home/teraoka/temp_sra_lambda_src_PABx
...Package and Stage Layer (lambda layers) Code
...Preparing lambda layer code
...Using pip version 23.0.1
...Package to download: boto3 (latest version in pip)
...Downloading boto3 to /home/teraoka/aws-sra-examples/sra_staging_manual_upload/sra-inspector-org/layer_code/tmp_boto3/python target folder
...Zip file to create from downloaded package: /home/teraoka/aws-sra-examples/sra_staging_manual_upload/sra-inspector-org/layer_code/sra-inspector-org-layer.zip
...Creating layer code zip file
...CloudFormation templates uploaded to sra-staging-614212495865-ap-northeast-1/sra-inspector-org/templates/
...Lambda zip files uploaded to sra-staging-614212495865-ap-northeast-1/sra-inspector-org/lambda_code/
...Layer zip files uploaded to sra-staging-614212495865-ap-northeast-1/sra-inspector-org/layer_code/
...Lambda function sra-inspector-org not found to update
------------------------------------------------------------
-- Solution: sra-macie-org
------------------------------------------------------------
...Stage CloudFormation Templates
...Package and Stage Lambda Code
...Creating the temporary packaging folder (tmp_sra_lambda_src_XXXX)
...Creating zip file from the temp folder contents
...Removing Temporary Folder /home/teraoka/temp_sra_lambda_src_yz9n
...CloudFormation templates uploaded to sra-staging-614212495865-ap-northeast-1/sra-macie-org/templates/
...Lambda zip files uploaded to sra-staging-614212495865-ap-northeast-1/sra-macie-org/lambda_code/
...Lambda function sra-macie-org not found to update
------------------------------------------------------------
-- Solution: sra-s3-block-account-public-access
------------------------------------------------------------
...Stage CloudFormation Templates
...Package and Stage Lambda Code
...Creating the temporary packaging folder (tmp_sra_lambda_src_XXXX)
...Creating zip file from the temp folder contents
...Removing Temporary Folder /home/teraoka/temp_sra_lambda_src_SFSb
...CloudFormation templates uploaded to sra-staging-614212495865-ap-northeast-1/sra-s3-block-account-public-access/templates/
...Lambda zip files uploaded to sra-staging-614212495865-ap-northeast-1/sra-s3-block-account-public-access/lambda_code/
...Lambda function sra-s3-block-account-public-access not found to update
------------------------------------------------------------
-- Solution: sra-securityhub-org
------------------------------------------------------------
...Stage CloudFormation Templates
...Package and Stage Lambda Code
...Creating the temporary packaging folder (tmp_sra_lambda_src_XXXX)
...Creating zip file from the temp folder contents
...Removing Temporary Folder /home/teraoka/temp_sra_lambda_src_YqUd
...CloudFormation templates uploaded to sra-staging-614212495865-ap-northeast-1/sra-securityhub-org/templates/
...Lambda zip files uploaded to sra-staging-614212495865-ap-northeast-1/sra-securityhub-org/lambda_code/
...Lambda function sra-securityhub-org not found to update

------------------------------------------------------------
-- Staging Folder and S3 Bucket
------------------------------------------------------------
SRA STAGING UPLOADS FOLDER: /home/teraoka/aws-sra-examples/sra_staging_manual_upload
SRA STAGING S3 BUCKET NAME: sra-staging-614212495865-ap-northeast-1
```

</details>

## CloudFormation の deploy

```
aws cloudformation deploy \
  --template-file $HOME/aws-sra-examples/aws_sra_examples/solutions/common/common_cfct_setup/templates/sra-common-cfct-setup-main.yaml \
  --stack-name sra-common-cfct-setup-main \
  --capabilities CAPABILITY_NAMED_IAM
```

<details>
<summary>実行ログ</summary>

```
Waiting for changeset to be created..
Waiting for stack create/update to complete

Failed to create/update the stack. Run the following command
to fetch the list of events leading up to the failure
aws cloudformation describe-stack-events --stack-name sra-common-cfct-setup-main
```

</details>

コケた...

```
Embedded stack arn:aws:cloudformation:ap-northeast-1:614212495865:stack/sra-common-cfct-setup-main-rCFCTStack-1GH52PC2EL0DE/2ce55590-ece0-11ed-998e-0e815a04ed53 was not successfully created: The following resource(s) failed to create: [CustomControlTowerS3AccessLogsBucket].
```

```
Bucket cannot have ACLs set with ObjectOwnership's BucketOwnerEnforced setting (Service: Amazon S3; Status Code: 400; Error Code: InvalidBucketAclWithObjectOwnership; Request ID: ABRKXE1M7R3S2CTR; S3 Extended Request ID: +M4L2UYDMCsYUqFC3BSk+afcumZh0pZhBGpJfK8LSQbHyjyfCD5CF7Pwq4UZs1Cew5JMC7y0xFc=; Proxy: null)
```

https://stackoverflow.com/questions/76097031/aws-s3-bucket-cannot-have-acls-set-with-objectownerships-bucketownerenforced-s

https://github.com/aws-solutions/aws-control-tower-customizations/commit/fabefd83d08e2e56731211eff2dcc7f12534d06e

https://github.com/aws-solutions/aws-control-tower-customizations/releases/tag/v2.5.3

くっそ


## CloudFormation の template を取得

CloudFormation の stack を作成するための template が GitHub にあるので git clone する

```
ghq get https://github.com/aws-samples/aws-security-reference-architecture-examples.git
```

[AWS Security Reference Architecture Examples](https://github.com/aws-samples/aws-security-reference-architecture-examples) の手順 ([Customizations for AWS Control Tower (CFCT) Setup](https://github.com/aws-samples/aws-security-reference-architecture-examples/tree/main/aws_sra_examples/solutions/common/common_cfct_setup)) で進める

[customizations-for-aws-control-tower.template](https://github.com/aws-solutions/aws-control-tower-customizations/blob/main/customizations-for-aws-control-tower.template) では `AWS CodePipeline Source` が `Amazon S3` と `AWS CodeCommit` から選択可能で、`Amazon S3` がデフォルトだがこれを `AWS CodeCommit` にする、`Failure Tolerance Percentage` がデフォルトでは `10` だが `0` にする。

```
aws cloudformation deploy \
  --template-file $(ghq root)/aws-sra-examples/aws_sra_examples/solutions/common/common_cfct_setup/templates/sra-common-cfct-setup-main.yaml \
  --stack-name sra-common-cfct-setup-main \
  --capabilities CAPABILITY_NAMED_IAM
```

## 参考


- [Customizations for AWS Control Tower (CfCT) overview](https://docs.aws.amazon.com/controltower/latest/userguide/cfct-overview.html)
- [github.com/aws-solutions/aws-control-tower-customizations](https://github.com/aws-solutions/aws-control-tower-customizations)
- [AWS CONTROL TOWERのカスタマイズ (CFCT)](https://controltower.aws-management.tools/ja/automation/cfct/)
- [Control Towerカスタマイズソリューション(CfCT)を使ってガードレールとCloudFormationを自動展開してみた](https://dev.classmethod.jp/articles/customizations-for-control-tower/)
- [Deploy consistent DNS with AWS Service Catalog and AWS Control Tower customizations](https://aws.amazon.com/jp/blogs/architecture/deploy-consistent-dns-with-aws-service-catalog-and-aws-control-tower-customizations/)
- https://github.com/aws-samples/aws-security-reference-architecture-examples/tree/main/aws_sra_examples/solutions/common/common_cfct_setup


