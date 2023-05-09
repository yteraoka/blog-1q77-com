---
title: "Customizations for AWS Control Tower (CfCT)"
date: 2023-05-07T20:57:41+09:00
tags: ["AWS"]
draft: false
---

Customizations for AWS Control Tower (CfCT) を試す。

[AWS Security Reference Architecture Examples](https://github.com/aws-samples/aws-security-reference-architecture-examples) を参考にする。

[aws_sra_examples/solutions/common/common_cfct_setup](https://github.com/aws-samples/aws-security-reference-architecture-examples/tree/main/aws_sra_examples/solutions/common/common_cfct_setup) というディレクトリにある。

## Prerequisites

### Control Tower

Control Tower は有効化済みであること。

### SRA Prerequisites

SRA 設定を使用する場合は [SRA Prerequisites](https://github.com/aws-samples/aws-security-reference-architecture-examples/tree/main/aws_sra_examples/solutions/common/common_prerequisites#15-aws-ssm-parameter-store) が deploy 済みでなければならない。

これを deploy するための準備として次のことを実施する

- Trusted Access for AWS CloudFormation StackSets を有効にする ([AWS Docs](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacksets-orgs-enable-trusted-access.html))
  - CloudFormation Console で StackSets にアクセスして、上部に `Activate trusted access with AWS Organizations to use service-managed permissions.` と表示され `Activate trusted access` というボタンがあればクリックする
  - AWS Organizations console page から `Services` を開き `CloudFormation StackSets` が `Access enabled` になっていることを確認する
- [Download and Stage the AWS SRA Solutions](https://github.com/aws-samples/aws-security-reference-architecture-examples/blob/main/aws_sra_examples/docs/DOWNLOAD-AND-STAGE-SOLUTIONS.md)
  - awscli をインストールし、`sra-management` という名前の profile でアクセス可能にする (`aws configure --profile sra-management`)
  - (後から思ったけど必須ではなかった気がする)

clone 先は任意だけど、手順をコピペできるのでドキュメント通りの `$HOME/aws-sra-examples` にしておく

```bash
git clone https://github.com/aws-samples/aws-security-reference-architecture-examples.git $HOME/aws-sra-examples
cd $HOME/aws-sra-examples
```

```bash
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

ここで deploy された CloudFormation では OrganizationId を返すだけの Lambda と S3 Bucket と ParameterStore が作成される程度。この後の操作で必要なものたち。

次に、この後の CloudFormation の deploy に必要なデータを先の S3 Bucket にコピーするスクリプトを実行する。
ただし、この後 CfCT 用の deploy がコケたのでその対策を先に行っておく。(2023-05-08 時点)

エラーの原因は [S3 の ACL がデフォルトで無効化されたこと](https://aws.amazon.com/about-aws/whats-new/2022/12/amazon-s3-automatically-enable-block-public-access-disable-access-control-lists-buckets-april-2023/)によるもので、[aws-solutions/aws-control-tower-customizations](https://github.com/aws-solutions/aws-control-tower-customizations/) の [v2.5.3](https://github.com/aws-solutions/aws-control-tower-customizations/releases/tag/v2.5.3) ではこれに対応済みということなので `stage_solution.sh` によるセットアップの中でこのバージョンが使われるようにします。


<details>
<summary>修正箇所 (diff)</summary>

```diff
diff --git a/aws_sra_examples/solutions/common/common_cfct_setup/templates/customizations-for-aws-control-tower.template b/aws_sra_examples/solutions/common/common_cfct_setup/templates/customizations-for-aws-control-tower.template
index 19763e2..96fbcfb 100644
--- a/aws_sra_examples/solutions/common/common_cfct_setup/templates/customizations-for-aws-control-tower.template
+++ b/aws_sra_examples/solutions/common/common_cfct_setup/templates/customizations-for-aws-control-tower.template
@@ -12,7 +12,7 @@
 # permissions and limitations under the License.

 AWSTemplateFormatVersion: '2010-09-09'
-Description: '(SO0089) - customizations-for-aws-control-tower Solution. Version: v2.5.2'
+Description: '(SO0089) - customizations-for-aws-control-tower Solution. Version: v2.5.3'

 Parameters:
   PipelineApprovalStage:
@@ -127,7 +127,7 @@ Mappings:
     SourceBucketName:
       Name: control-tower-cfct-assets-prod
     SourceKeyName:
-      Name: customizations-for-aws-control-tower/v2.5.2/custom-control-tower-configuration.zip
+      Name: customizations-for-aws-control-tower/v2.5.3/custom-control-tower-configuration.zip
     CustomControlTowerPipelineS3TriggerKey:
       Name: custom-control-tower-configuration.zip
     CustomControlTowerPipelineS3NonTriggerKey:
@@ -145,7 +145,7 @@ Mappings:
       SolutionID: 'SO0089'
       MetricsURL: 'https://metrics.awssolutionsbuilder.com/generic'
     Data:
-      AddonTemplate: 'https://s3.amazonaws.com/control-tower-cfct-assets-prod/customizations-for-aws-control-tower/v2.5.2/custom-control-tower-initiation.template'
+      AddonTemplate: 'https://s3.amazonaws.com/control-tower-cfct-assets-prod/customizations-for-aws-control-tower/v2.5.3/custom-control-tower-initiation.template'
   AWSControlTower:
     ExecutionRole:
       Name: "AWSControlTowerExecution"
@@ -260,7 +260,6 @@ Resources:
           - id: CKV_AWS_18
             comment: S3 access logging is not enabled.
     Properties:
-      AccessControl: LogDeliveryWrite
       VersioningConfiguration:
         Status: Enabled
       BucketEncryption:
@@ -283,7 +282,31 @@ Resources:
             Effect: Deny
             Principal: "*"
             Action: s3:DeleteBucket
-            Resource: !Sub arn:${AWS::Partition}:s3:::${CustomControlTowerS3AccessLogsBucket}
+            Resource: !Sub "arn:${AWS::Partition}:s3:::${CustomControlTowerS3AccessLogsBucket}"
+          - Sid: EnableS3AccessLoggingForPipelineS3Bucket
+            Effect: Allow
+            Principal:
+              Service: logging.s3.amazonaws.com
+            Action:
+              - s3:PutObject
+            Resource: !Sub "arn:${AWS::Partition}:s3:::${CustomControlTowerS3AccessLogsBucket}/*"
+            Condition:
+              ArnLike:
+                "aws:SourceArn": !Sub "arn:${AWS::Partition}:s3:::${CustomControlTowerPipelineS3Bucket}"
+              StringEquals:
+                "aws:SourceAccount": !Ref AWS::AccountId
+          - Sid: EnableS3AccessLoggingForPipelineArtifactS3Bucket
+            Effect: Allow
+            Principal:
+              Service: logging.s3.amazonaws.com
+            Action:
+              - s3:PutObject
+            Resource: !Sub "arn:${AWS::Partition}:s3:::${CustomControlTowerS3AccessLogsBucket}/*"
+            Condition:
+              ArnLike:
+                "aws:SourceArn": !Sub "arn:${AWS::Partition}:s3:::${CustomControlTowerPipelineArtifactS3Bucket}"
+              StringEquals:
+                "aws:SourceAccount": !Ref AWS::AccountId

   CustomControlTowerCodeCommit:
     Type: AWS::CodeCommit::Repository
@@ -296,7 +319,7 @@ Resources:
       Code:
         S3:
           Bucket: control-tower-cfct-assets-prod
-          Key: !Sub customizations-for-aws-control-tower/v2.5.2/custom-control-tower-configuration-${AWS::Region}.zip
+          Key: !Sub customizations-for-aws-control-tower/v2.5.3/custom-control-tower-configuration-${AWS::Region}.zip

  # SSM Parameter to store the git repository name
   CustomControlTowerRepoNameParameter:
@@ -559,7 +582,7 @@ Resources:
             - {KMSKeyName: !FindInMap [KMS, Alias, Name]}
           Source:
               Type: CODEPIPELINE
-              BuildSpec: "version: 0.2\nphases:\n  install:\n    runtime-versions:\n      python: 3.8\n      ruby: 2.6\n    commands:\n      - export current=$(pwd)\n      - if [ -f manifest.yaml ];then export current=$(pwd);else if [ -f custom-control-tower-configuration/manifest.yaml ]; then export current=$(pwd)/custom-control-tower-configuration;	else echo 'manifest.yaml does not exist at the root level of custom-control-tower-configuration.zip or inside custom-control-tower-configuration folder, please check the ZIP file'; exit 1;	fi; fi;\n      - apt-get -q update 1> /dev/null\n      - apt-get -q install zip wget python3-pip libyaml-dev -y 1>/dev/null\n      - export LC_ALL='en_US.UTF-8'\n      - locale-gen en_US en_US.UTF-8\n      - dpkg-reconfigure locales --frontend noninteractive\n  pre_build:\n    commands:\n      - cd $current\n      - echo 'Download CustomControlTower Scripts'\n      - aws s3 cp --quiet s3://control-tower-cfct-assets-prod/customizations-for-aws-control-tower/v2.5.2/custom-control-tower-scripts.zip $current\n      - unzip -q -o $current/custom-control-tower-scripts.zip -d $current\n      - cp codebuild_scripts/* .\n      - bash install_stage_dependencies.sh $STAGE_NAME\n  build:\n    commands:\n      - echo 'Starting build $(date) in $(pwd)'\n      - echo 'bash execute_stage_scripts.sh $STAGE_NAME $LOG_LEVEL $WAIT_TIME $SM_ARN $ARTIFACT_BUCKET $KMS_KEY_ALIAS_NAME $BOOL_VALUES $NONE_TYPE_VALUES'\n      - bash execute_stage_scripts.sh $STAGE_NAME $LOG_LEVEL $WAIT_TIME $SM_ARN $ARTIFACT_BUCKET $KMS_KEY_ALIAS_NAME $BOOL_VALUES $NONE_TYPE_VALUES \n      - echo 'Running build scripts completed $(date)'\n  post_build:\n    commands:\n      - echo 'Starting post build $(date) in $(pwd)'\n      - echo 'build completed on $(date)'\n\nartifacts:\n  files:\n      - '**/*'\n\n"
+              BuildSpec: "version: 0.2\nphases:\n  install:\n    runtime-versions:\n      python: 3.8\n      ruby: 2.6\n    commands:\n      - export current=$(pwd)\n      - if [ -f manifest.yaml ];then export current=$(pwd);else if [ -f custom-control-tower-configuration/manifest.yaml ]; then export current=$(pwd)/custom-control-tower-configuration;	else echo 'manifest.yaml does not exist at the root level of custom-control-tower-configuration.zip or inside custom-control-tower-configuration folder, please check the ZIP file'; exit 1;	fi; fi;\n      - apt-get -q update 1> /dev/null\n      - apt-get -q install zip wget python3-pip libyaml-dev -y 1>/dev/null\n      - export LC_ALL='en_US.UTF-8'\n      - locale-gen en_US en_US.UTF-8\n      - dpkg-reconfigure locales --frontend noninteractive\n  pre_build:\n    commands:\n      - cd $current\n      - echo 'Download CustomControlTower Scripts'\n      - aws s3 cp --quiet s3://control-tower-cfct-assets-prod/customizations-for-aws-control-tower/v2.5.3/custom-control-tower-scripts.zip $current\n      - unzip -q -o $current/custom-control-tower-scripts.zip -d $current\n      - cp codebuild_scripts/* .\n      - bash install_stage_dependencies.sh $STAGE_NAME\n  build:\n    commands:\n      - echo 'Starting build $(date) in $(pwd)'\n      - echo 'bash execute_stage_scripts.sh $STAGE_NAME $LOG_LEVEL $WAIT_TIME $SM_ARN $ARTIFACT_BUCKET $KMS_KEY_ALIAS_NAME $BOOL_VALUES $NONE_TYPE_VALUES'\n      - bash execute_stage_scripts.sh $STAGE_NAME $LOG_LEVEL $WAIT_TIME $SM_ARN $ARTIFACT_BUCKET $KMS_KEY_ALIAS_NAME $BOOL_VALUES $NONE_TYPE_VALUES \n      - echo 'Running build scripts completed $(date)'\n  post_build:\n    commands:\n      - echo 'Starting post build $(date) in $(pwd)'\n      - echo 'build completed on $(date)'\n\nartifacts:\n  files:\n      - '**/*'\n\n"
           Environment:
               ComputeType: BUILD_GENERAL1_SMALL
               Image: "aws/codebuild/standard:5.0"
@@ -584,7 +607,7 @@ Resources:
                   - Name: SOLUTION_ID
                     Value: !FindInMap [ Solution, Metrics, SolutionID ]
                   - Name: SOLUTION_VERSION
-                    Value: v2.5.2
+                    Value: v2.5.3
           Artifacts:
               Name: !Sub ${CustomControlTowerPipelineArtifactS3Bucket}-Built
               Type: CODEPIPELINE
@@ -687,7 +710,7 @@ Resources:
             - {KMSKeyName: !FindInMap [KMS, Alias, Name]}
           Source:
               Type: CODEPIPELINE
-              BuildSpec: "version: 0.2\nphases:\n  install:\n    runtime-versions:\n      python: 3.8\n      ruby: 2.6\n    commands:\n      - export current=$(pwd)\n      - if [ -f manifest.yaml ];then export current=$(pwd);else if [ -f custom-control-tower-configuration/manifest.yaml ]; then export current=$(pwd)/custom-control-tower-configuration;	else echo 'manifest.yaml does not exist at the root level of custom-control-tower-configuration.zip or inside custom-control-tower-configuration folder, please check the ZIP file'; exit 1;	fi; fi;\n      - apt-get -q update 1> /dev/null\n      - apt-get -q install zip wget python3-pip libyaml-dev -y 1> /dev/null \n  pre_build:\n    commands:\n      - cd $current\n      - echo 'Download CustomControlTower Scripts'\n      - aws s3 cp --quiet s3://control-tower-cfct-assets-prod/customizations-for-aws-control-tower/v2.5.2/custom-control-tower-scripts.zip $current\n      - unzip -q -o $current/custom-control-tower-scripts.zip -d $current\n      - cp codebuild_scripts/* .\n      - bash install_stage_dependencies.sh $STAGE_NAME\n  build:\n    commands:\n      - echo 'Starting build $(date) in $(pwd)'\n      - echo 'bash execute_stage_scripts.sh $STAGE_NAME $LOG_LEVEL $WAIT_TIME $SM_ARN $ARTIFACT_BUCKET $KMS_KEY_ALIAS_NAME $BOOL_VALUES $NONE_TYPE_VALUES'\n      - bash execute_stage_scripts.sh $STAGE_NAME $LOG_LEVEL $WAIT_TIME $SM_ARN $ARTIFACT_BUCKET $KMS_KEY_ALIAS_NAME $BOOL_VALUES $NONE_TYPE_VALUES\n      - echo 'Running build scripts completed $(date)'\n  post_build:\n    commands:\n      - echo 'Starting post build $(date) in $(pwd)'\n      - echo 'build completed on $(date)'\n\nartifacts:\n  files:\n      - '**/*'\n"
+              BuildSpec: "version: 0.2\nphases:\n  install:\n    runtime-versions:\n      python: 3.8\n      ruby: 2.6\n    commands:\n      - export current=$(pwd)\n      - if [ -f manifest.yaml ];then export current=$(pwd);else if [ -f custom-control-tower-configuration/manifest.yaml ]; then export current=$(pwd)/custom-control-tower-configuration;	else echo 'manifest.yaml does not exist at the root level of custom-control-tower-configuration.zip or inside custom-control-tower-configuration folder, please check the ZIP file'; exit 1;	fi; fi;\n      - apt-get -q update 1> /dev/null\n      - apt-get -q install zip wget python3-pip libyaml-dev -y 1> /dev/null \n  pre_build:\n    commands:\n      - cd $current\n      - echo 'Download CustomControlTower Scripts'\n      - aws s3 cp --quiet s3://control-tower-cfct-assets-prod/customizations-for-aws-control-tower/v2.5.3/custom-control-tower-scripts.zip $current\n      - unzip -q -o $current/custom-control-tower-scripts.zip -d $current\n      - cp codebuild_scripts/* .\n      - bash install_stage_dependencies.sh $STAGE_NAME\n  build:\n    commands:\n      - echo 'Starting build $(date) in $(pwd)'\n      - echo 'bash execute_stage_scripts.sh $STAGE_NAME $LOG_LEVEL $WAIT_TIME $SM_ARN $ARTIFACT_BUCKET $KMS_KEY_ALIAS_NAME $BOOL_VALUES $NONE_TYPE_VALUES'\n      - bash execute_stage_scripts.sh $STAGE_NAME $LOG_LEVEL $WAIT_TIME $SM_ARN $ARTIFACT_BUCKET $KMS_KEY_ALIAS_NAME $BOOL_VALUES $NONE_TYPE_VALUES\n      - echo 'Running build scripts completed $(date)'\n  post_build:\n    commands:\n      - echo 'Starting post build $(date) in $(pwd)'\n      - echo 'build completed on $(date)'\n\nartifacts:\n  files:\n      - '**/*'\n"
           Environment:
               ComputeType: BUILD_GENERAL1_SMALL
               Image: "aws/codebuild/standard:5.0"
@@ -708,7 +731,7 @@ Resources:
                   - Name: SOLUTION_ID
                     Value: !FindInMap [ Solution, Metrics, SolutionID ]
                   - Name: SOLUTION_VERSION
-                    Value: v2.5.2
+                    Value: v2.5.3
           Artifacts:
               Name: !Sub ${CustomControlTowerPipelineArtifactS3Bucket}-Built
               Type: CODEPIPELINE
@@ -863,7 +886,7 @@ Resources:
             - {KMSKeyName: !FindInMap [KMS, Alias, Name]}
           Source:
               Type: CODEPIPELINE
-              BuildSpec: "version: 0.2\nphases:\n  install:\n    runtime-versions:\n      python: 3.8\n      ruby: 2.6\n    commands:\n      - export current=$(pwd)\n      - if [ -f manifest.yaml ];then export current=$(pwd);else if [ -f custom-control-tower-configuration/manifest.yaml ]; then export current=$(pwd)/custom-control-tower-configuration;	else echo 'manifest.yaml does not exist at the root level of custom-control-tower-configuration.zip or inside custom-control-tower-configuration folder, please check the ZIP file'; exit 1;	fi; fi;\n      - apt-get -q update 1> /dev/null\n      - apt-get -q install zip wget python3-pip libyaml-dev -y 1> /dev/null\n  pre_build:\n    commands:\n      - cd $current\n      - echo 'Download CustomControlTower Scripts'\n      - aws s3 cp --quiet s3://control-tower-cfct-assets-prod/customizations-for-aws-control-tower/v2.5.2/custom-control-tower-scripts.zip $current\n      - unzip -q -o $current/custom-control-tower-scripts.zip -d $current\n      - cp codebuild_scripts/* .\n      - bash install_stage_dependencies.sh $STAGE_NAME\n  build:\n    commands:\n      - echo 'Starting build $(date) in $(pwd)'\n      - echo 'bash execute_stage_scripts.sh $STAGE_NAME $LOG_LEVEL $WAIT_TIME $SM_ARN $ARTIFACT_BUCKET $KMS_KEY_ALIAS_NAME $BOOL_VALUES $NONE_TYPE_VALUES'\n      - bash execute_stage_scripts.sh $STAGE_NAME $LOG_LEVEL $WAIT_TIME $SM_ARN $ARTIFACT_BUCKET $KMS_KEY_ALIAS_NAME $BOOL_VALUES $NONE_TYPE_VALUES\n      - echo 'Running build scripts completed $(date)'\n  post_build:\n    commands:\n      - echo 'Starting post build $(date) in $(pwd)'\n      - echo 'build completed on $(date)'\n\nartifacts:\n  files:\n      - '**/*'\n"
+              BuildSpec: "version: 0.2\nphases:\n  install:\n    runtime-versions:\n      python: 3.8\n      ruby: 2.6\n    commands:\n      - export current=$(pwd)\n      - if [ -f manifest.yaml ];then export current=$(pwd);else if [ -f custom-control-tower-configuration/manifest.yaml ]; then export current=$(pwd)/custom-control-tower-configuration;	else echo 'manifest.yaml does not exist at the root level of custom-control-tower-configuration.zip or inside custom-control-tower-configuration folder, please check the ZIP file'; exit 1;	fi; fi;\n      - apt-get -q update 1> /dev/null\n      - apt-get -q install zip wget python3-pip libyaml-dev -y 1> /dev/null\n  pre_build:\n    commands:\n      - cd $current\n      - echo 'Download CustomControlTower Scripts'\n      - aws s3 cp --quiet s3://control-tower-cfct-assets-prod/customizations-for-aws-control-tower/v2.5.3/custom-control-tower-scripts.zip $current\n      - unzip -q -o $current/custom-control-tower-scripts.zip -d $current\n      - cp codebuild_scripts/* .\n      - bash install_stage_dependencies.sh $STAGE_NAME\n  build:\n    commands:\n      - echo 'Starting build $(date) in $(pwd)'\n      - echo 'bash execute_stage_scripts.sh $STAGE_NAME $LOG_LEVEL $WAIT_TIME $SM_ARN $ARTIFACT_BUCKET $KMS_KEY_ALIAS_NAME $BOOL_VALUES $NONE_TYPE_VALUES'\n      - bash execute_stage_scripts.sh $STAGE_NAME $LOG_LEVEL $WAIT_TIME $SM_ARN $ARTIFACT_BUCKET $KMS_KEY_ALIAS_NAME $BOOL_VALUES $NONE_TYPE_VALUES\n      - echo 'Running build scripts completed $(date)'\n  post_build:\n    commands:\n      - echo 'Starting post build $(date) in $(pwd)'\n      - echo 'build completed on $(date)'\n\nartifacts:\n  files:\n      - '**/*'\n"
           Environment:
               ComputeType: BUILD_GENERAL1_SMALL
               Image: "aws/codebuild/standard:5.0"
@@ -888,7 +911,7 @@ Resources:
                   - Name: SOLUTION_ID
                     Value: !FindInMap [Solution, Metrics, SolutionID]
                   - Name: SOLUTION_VERSION
-                    Value: v2.5.2
+                    Value: v2.5.3
                   - Name: METRICS_URL
                     Value: !FindInMap [Solution, Metrics, MetricsURL]
                   - Name: CONTROL_TOWER_BASELINE_CONFIG_STACKSET
@@ -1021,10 +1044,10 @@ Resources:
         Variables:
           LOG_LEVEL: !FindInMap [LambdaFunction, Logging, Level]
           SOLUTION_ID: !FindInMap [Solution, Metrics, SolutionID]
-          SOLUTION_VERSION: v2.5.2
+          SOLUTION_VERSION: v2.5.3
       Code:
         S3Bucket: !Sub "control-tower-cfct-assets-prod-${AWS::Region}"
-        S3Key: customizations-for-aws-control-tower/v2.5.2/custom-control-tower-config-deployer.zip
+        S3Key: customizations-for-aws-control-tower/v2.5.3/custom-control-tower-config-deployer.zip
       FunctionName: CustomControlTowerDeploymentLambda
       Description: Custom Control Tower Deployment Lambda
       Handler: config_deployer.lambda_handler
@@ -1309,14 +1332,14 @@ Resources:
           ADMINISTRATION_ROLE_ARN: !Sub arn:${AWS::Partition}:iam::${AWS::AccountId}:role/service-role/AWSControlTowerStackSetRole
           EXECUTION_ROLE_NAME: !FindInMap [AWSControlTower, ExecutionRole, Name]
           SOLUTION_ID: !FindInMap [Solution, Metrics, SolutionID]
-          SOLUTION_VERSION: v2.5.2
+          SOLUTION_VERSION: v2.5.3
           METRICS_URL: !FindInMap [Solution, Metrics, MetricsURL]
           MAX_CONCURRENT_PERCENT: !Ref MaxConcurrentPercentage
           FAILED_TOLERANCE_PERCENT: !Ref FailureTolerancePercentage
           REGION_CONCURRENCY_TYPE: !Ref RegionConcurrencyType
       Code:
         S3Bucket: !Sub "control-tower-cfct-assets-prod-${AWS::Region}"
-        S3Key: customizations-for-aws-control-tower/v2.5.2/custom-control-tower-state-machine.zip
+        S3Key: customizations-for-aws-control-tower/v2.5.3/custom-control-tower-state-machine.zip
       FunctionName: CustomControlTowerStateMachineLambda
       Description: Custom Control Tower State Machine Handler
       Handler: state_machine_router.lambda_handler
@@ -2934,10 +2957,10 @@ Resources:
           LOG_LEVEL: !FindInMap [LambdaFunction, Logging, Level]
           CODE_PIPELINE_NAME: !Ref CustomControlTowerCodePipeline
           SOLUTION_ID: !FindInMap [ Solution, Metrics, SolutionID ]
-          SOLUTION_VERSION: v2.5.2
+          SOLUTION_VERSION: v2.5.3
       Code:
         S3Bucket: !Sub "control-tower-cfct-assets-prod-${AWS::Region}"
-        S3Key: customizations-for-aws-control-tower/v2.5.2/custom-control-tower-lifecycle-event-handler.zip
+        S3Key: customizations-for-aws-control-tower/v2.5.3/custom-control-tower-lifecycle-event-handler.zip
       Description: Custom Control Tower Lifecyle event Lambda to handle lifecycle events
       Handler: lifecycle_event_handler.lambda_handler
       MemorySize: 512
@@ -3108,6 +3131,6 @@ Outputs:
     Value: !Ref CustomControlTowerPipelineS3Bucket
   CustomControlTowerSolutionVersion:
     Description: Version Number
-    Value: "v2.5.2"
+    Value: "v2.5.3"
     Export:
       Name: Custom-Control-Tower-Version
diff --git a/aws_sra_examples/solutions/common/common_cfct_setup/templates/sra-common-cfct-setup-main.yaml b/aws_sra_examples/solutions/common/common_cfct_setup/templates/sra-common-cfct-setup-main.yaml
index d307208..de2522c 100644
--- a/aws_sra_examples/solutions/common/common_cfct_setup/templates/sra-common-cfct-setup-main.yaml
+++ b/aws_sra_examples/solutions/common/common_cfct_setup/templates/sra-common-cfct-setup-main.yaml
@@ -162,4 +162,4 @@ Resources:
 Outputs:
   CustomControlTowerSolutionVersion:
     Description: Version Number
-    Value: 'v2.5.2'
+    Value: 'v2.5.3'
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

## CfCT 用 CloudFormation の deploy

次のコマンドで CloudFormation の `sra-common-cfct-setup-main` Stack を deploy すると、子 Stack が作成されて [github.com/aws-solutions/aws-control-tower-customizations](https://github.com/aws-solutions/aws-control-tower-customizations) が deploy される。

次の2つのデフォルト値が変更されている

- `AWS CodePipeline Source` が `Amazon S3` から `AWS CodeCommit` に変更
- `Failure Tolerance Percentage` が `10` から `0` に変更

```
aws cloudformation deploy \
  --template-file $HOME/aws-sra-examples/aws_sra_examples/solutions/common/common_cfct_setup/templates/sra-common-cfct-setup-main.yaml \
  --stack-name sra-common-cfct-setup-main \
  --capabilities CAPABILITY_NAMED_IAM
```

### 作成されるリソース

IAM Role とか Policy とか Event Rule とかは省略

- CodeCommit Repository
  - custom-control-tower-configuration
- CodeBuild
  - Custom-Control-Tower-StackSet-CodeBuild
  - Custom-Control-Tower-SCP-CodeBuild
  - Custom-Control-Tower-CodeBuild
- Lambda
  - CustomControlTowerDeploymentLambda
  - sra-common-cfct-setup-mai-CustomControlTowerLELamb-\*
  - CustomControlTowerStateMachineLambda
- S3 Bucket
  - sra-common-cfct-setup-ma-customcontroltowerpipeli-\* (Pipeline Artifacts)
  - custom-control-tower-configuration-\*
  - sra-common-cfct-setup-ma-customcontroltowers3acce-\* (S3 AccessLog)
- Step Functions
  - CustomControlTowerServiceControlPolicyMachine
  - CustomControlTowerStackSetStateMachine
- SQS
  - CustomControlTowerLEFIFODLQueue.fifo
  - CustomControlTowerLEFIFOQueue.fifo


## CfCT を用いた Control Tower の Customize

https://github.com/aws-solutions/aws-control-tower-customizations/tree/main/deployment/custom_control_tower_configuration から生成されたファイルが CodeCommit Repository に登録されているので clone して編集し、main branch に push すると Custom-Control-Tower-CodePipeline が実行される (中で上記の3つの CodeBuild が実行される)

```
$ tree .
.
├── example-configuration
│   ├── manifest.yaml
│   ├── parameters
│   │   ├── create-ssm-parameter-keys-1.json
│   │   └── create-ssm-parameter-keys-2.json
│   ├── policies
│   │   └── preventive-guardrails.json
│   └── templates
│       ├── create-ssm-parameter-keys-1.template
│       └── create-ssm-parameter-keys-2.template
└── manifest.yaml
```

`manifest.yaml` は初期状態では resources が空っぽなので何も起こらない。

```yaml
#Default region for deploying Custom Control Tower: Code Pipeline, Step functions, Lambda, SSM parameters, and StackSets
region: ap-northeast-1
version: 2021-03-15

# Control Tower Custom Resources (Service Control Policies or CloudFormation)
resources: []
```


## 参考


- [Customizations for AWS Control Tower (CfCT) overview](https://docs.aws.amazon.com/controltower/latest/userguide/cfct-overview.html)
- [github.com/aws-solutions/aws-control-tower-customizations](https://github.com/aws-solutions/aws-control-tower-customizations)
- [AWS CONTROL TOWERのカスタマイズ (CFCT)](https://controltower.aws-management.tools/ja/automation/cfct/)
- [Control Towerカスタマイズソリューション(CfCT)を使ってガードレールとCloudFormationを自動展開してみた](https://dev.classmethod.jp/articles/customizations-for-control-tower/)
- [Deploy consistent DNS with AWS Service Catalog and AWS Control Tower customizations](https://aws.amazon.com/jp/blogs/architecture/deploy-consistent-dns-with-aws-service-catalog-and-aws-control-tower-customizations/)
- https://github.com/aws-samples/aws-security-reference-architecture-examples/tree/main/aws_sra_examples/solutions/common/common_cfct_setup


