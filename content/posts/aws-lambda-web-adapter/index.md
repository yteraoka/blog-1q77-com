---
title: "AWS Lambda Web Adapter でお手軽 Web Service 公開"
date: 2025-01-30T00:40:00+09:00
draft: false
tags: [AWS, Lambda]
image: cover.png
author: "@yteraoka"
categories:
  - Cloud
---

ずっと AWS にも Cloud Run が欲しいなあと思っていました。AppRunner はコレじゃない...

そんなある日、あれ？ AWS Lambda でいけんじゃね？と思い検索すると

[Lambda Web Adapter でウェブアプリを (ほぼ) そのままサーバーレス化する](https://aws.amazon.com/jp/builders-flash/202301/lambda-web-adapter/)

という記事が見つかりました。いけそうじゃん！

ということで、Lambda Web Adapter を試してみます。

https://github.com/awslabs/aws-lambda-web-adapter に多くのサンプルが用意されているので参考になります。

## AWS SAM を用いて example を deploy してみる

ひとまず AWS SAM で [examples/gin-zip](https://github.com/awslabs/aws-lambda-web-adapter/tree/main/examples/gin-zip) を deploy してみましたが、API Gateway を使った公開でちょっとコレジャナイ感...

一応手順とログをメモって置くが、これはここでおしまい。

SAM CLI のインストール

```
brew install aws-sam-cli
```

deploy

```
cd examples/gin-zip
sam build
```

<details>
<summary>sam build</summary>

```
$ sam build

    SAM CLI now collects telemetry to better understand customer needs.

    You can OPT OUT and disable telemetry collection by setting the
    environment variable SAM_CLI_TELEMETRY=0 in your shell.
    Thanks for your help!

    Learn More: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-telemetry.html

Building codeuri: /Users/teraoka/ghq/github.com/awslabs/aws-lambda-web-adapter/examples/gin-zip/app runtime:
provided.al2023 architecture: x86_64 functions: GinFunction
Workflow GoModulesBuilder does not support value "False" for building in source. Using default value "True".
 Running GoModulesBuilder:Build

Build Succeeded

Built Artifacts  : .aws-sam/build
Built Template   : .aws-sam/build/template.yaml

Commands you can use next
=========================
[*] Validate SAM template: sam validate
[*] Invoke Function: sam local invoke
[*] Test Function in the Cloud: sam sync --stack-name {{stack-name}} --watch
[*] Deploy: sam deploy --guided
```

</details>


<details>
<summary>sam deploy -g</summary>

```
$ sam deploy -g

Configuring SAM deploy
======================

    Looking for config file [samconfig.toml] :  Not found

    Setting default arguments for 'sam deploy'
    =========================================
    Stack Name [sam-app]:
    AWS Region [ap-northeast-1]:
    #Shows you resources changes to be deployed and require a 'Y' to initiate deploy
    Confirm changes before deploy [y/N]:
    #SAM needs permission to be able to create roles to connect to the resources in your template
    Allow SAM CLI IAM role creation [Y/n]:
    #Preserves the state of previously provisioned resources when an operation fails
    Disable rollback [y/N]:
    GinFunction has no authentication. Is this okay? [y/N]: y
    Save arguments to configuration file [Y/n]:
    SAM configuration file [samconfig.toml]:
    SAM configuration environment [default]:

    Looking for resources needed for deployment:
    Creating the required resources...
    Successfully created!

    Managed S3 bucket: aws-sam-cli-managed-default-samclisourcebucket-xxxxxxxxxxxx
    A different default S3 bucket can be set in samconfig.toml and auto resolution of buckets turned off by setting resolve_s3=False

    Saved arguments to config file
    Running 'sam deploy' for future deployments will use the parameters saved above.
    The above parameters can be changed by modifying samconfig.toml
    Learn more about samconfig.toml syntax at 
    https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-config.html

    Uploading to sam-app/bd836bbe749f524e048b2c99dc382d9d  6103417 / 6103417  (100.00%)

    Deploying with following values
    ===============================
    Stack name                   : sam-app
    Region                       : ap-northeast-1
    Confirm changeset            : False
    Disable rollback             : False
    Deployment s3 bucket         : aws-sam-cli-managed-default-samclisourcebucket-xxxxxxxxxxxx
    Capabilities                 : ["CAPABILITY_IAM"]
    Parameter overrides          : {}
    Signing Profiles             : {}

Initiating deployment
=====================

    Uploading to sam-app/19f48e89fb16275307a6f0a22802a201.template  973 / 973  (100.00%)


Waiting for changeset to be created..

CloudFormation stack changeset
---------------------------------------------------------------------------------------------------------------------
Operation                     LogicalResourceId             ResourceType                  Replacement                 
---------------------------------------------------------------------------------------------------------------------
+ Add                         GinFunctionAPIEventPermissi   AWS::Lambda::Permission       N/A                         
                              on                                                                                      
+ Add                         GinFunctionRole               AWS::IAM::Role                N/A                         
+ Add                         GinFunction                   AWS::Lambda::Function         N/A                         
+ Add                         ServerlessHttpApiApiGateway   AWS::ApiGatewayV2::Stage      N/A                         
                              DefaultStage                                                                            
+ Add                         ServerlessHttpApi             AWS::ApiGatewayV2::Api        N/A                         
---------------------------------------------------------------------------------------------------------------------


Changeset created successfully. arn:aws:cloudformation:ap-northeast-1:123456789012:changeSet/samcli-deploy1738079940/1b5321d5-7752-4eca-b62f-1a961ec02cf3


2025-01-29 00:59:12 - Waiting for stack create/update to complete

CloudFormation events from stack operations (refresh every 5.0 seconds)
---------------------------------------------------------------------------------------------------------------------
ResourceStatus                ResourceType                  LogicalResourceId             ResourceStatusReason        
---------------------------------------------------------------------------------------------------------------------
CREATE_IN_PROGRESS            AWS::CloudFormation::Stack    sam-app                       User Initiated              
CREATE_IN_PROGRESS            AWS::IAM::Role                GinFunctionRole               -                           
CREATE_IN_PROGRESS            AWS::IAM::Role                GinFunctionRole               Resource creation Initiated 
CREATE_COMPLETE               AWS::IAM::Role                GinFunctionRole               -                           
CREATE_IN_PROGRESS            AWS::Lambda::Function         GinFunction                   -                           
CREATE_IN_PROGRESS            AWS::Lambda::Function         GinFunction                   Resource creation Initiated 
CREATE_IN_PROGRESS -          AWS::Lambda::Function         GinFunction                   Eventual consistency check  
CONFIGURATION_COMPLETE                                                                    initiated                   
CREATE_IN_PROGRESS            AWS::ApiGatewayV2::Api        ServerlessHttpApi             -                           
CREATE_IN_PROGRESS            AWS::ApiGatewayV2::Api        ServerlessHttpApi             Resource creation Initiated 
CREATE_COMPLETE               AWS::ApiGatewayV2::Api        ServerlessHttpApi             -                           
CREATE_IN_PROGRESS            AWS::Lambda::Permission       GinFunctionAPIEventPermissi   -                           
                                                            on                                                        
CREATE_COMPLETE               AWS::Lambda::Function         GinFunction                   -                           
CREATE_IN_PROGRESS            AWS::Lambda::Permission       GinFunctionAPIEventPermissi   Resource creation Initiated 
                                                            on                                                        
CREATE_IN_PROGRESS            AWS::ApiGatewayV2::Stage      ServerlessHttpApiApiGateway   -                           
                                                            DefaultStage                                              
CREATE_COMPLETE               AWS::Lambda::Permission       GinFunctionAPIEventPermissi   -                           
                                                            on                                                        
CREATE_IN_PROGRESS            AWS::ApiGatewayV2::Stage      ServerlessHttpApiApiGateway   Resource creation Initiated 
                                                            DefaultStage                                              
CREATE_COMPLETE               AWS::ApiGatewayV2::Stage      ServerlessHttpApiApiGateway   -                           
                                                            DefaultStage                                              
CREATE_COMPLETE               AWS::CloudFormation::Stack    sam-app                       -                           
---------------------------------------------------------------------------------------------------------------------

CloudFormation outputs from deployed stack
---------------------------------------------------------------------------------------------------------------------
Outputs                                                                                                             
---------------------------------------------------------------------------------------------------------------------
Key                 GinApi                                                                                          
Description         API Gateway endpoint URL for Prod stage for Gin function                                        
Value               https://xxxxxxxxxx.execute-api.ap-northeast-1.amazonaws.com/                                    
---------------------------------------------------------------------------------------------------------------------


Successfully created/updated stack - sam-app in ap-northeast-1
```

</details>


## AWS Lamdba Web Adapter (LWA) とは

AWS Lambda は API Gateway や Lambda Function URL、Applicatio Load Balancer 経由でも呼び出すことが可能ですが、通常は Lambda 専用の interface 経由でメッセージを受け取って処理を行います。

これでは通常の HTTP サーバープログラムをそのまま Lambda で使うことができません。
そこでこの Web Adapter は Extention として先に起動し、HTTP サービスの起動を待ち、そこに対して HTTP でリクエストを転送し、結果を受け取って Lambda Function の結果に変換してくれます。

HTTP サービスのヘルスチェック機能も持っており、起動待ちにも使われます。

Web Adapter が HTTP クライアントとなるため、接続元の IP アドレスは 127.0.0.1 となり、Function URL にアクセスしたクライアントの IP アドレスは X-Forwarded-For ヘッダーを確認する必要があります。X-Forwarded-Port, X-Forwarded-Proto もあります。

他のヘッダーとして X-Amzn-Lambda-Context に次のような JSON が

```json
{
  "request_id": "cccf72de-fba1-4100-8663-6d8d15843433",
  "deadline": 1738160544142,
  "invoked_function_arn": "arn:aws:lambda:ap-northeast-1:123456789012:function:web-adapter-go",
  "xray_trace_id": "Root=1-679a399d-45e514a62640536d2ab4ae86;Parent=7b451ed232a4090f;Sampled=0;Lineage=1:a875347b:0",
  "client_context": null,
  "identity": null,
  "env_config": {
    "function_name": "web-adapter-go",
    "memory": 128,
    "version": "$LATEST",
    "log_stream": "",
    "log_group": ""
  }
}
```

X-Amzn-Request-Context に次のような JSON が入っています。

```json
{
  "routeKey": "$default",
  "accountId": "anonymous",
  "stage": "$default",
  "requestId": "cccf72de-fba1-4100-8663-6d8d15843433",
  "apiId": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "domainName": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.lambda-url.ap-northeast-1.on.aws",
  "domainPrefix": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "time": "29/Jan/2025:14:22:21 +0000",
  "timeEpoch": 1738160541135,
  "http": {
    "method": "GET",
    "path": "/",
    "protocol": "HTTP/1.1",
    "sourceIp": "123.123.123.123",
    "userAgent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
  }
}
```

## Go の net/http で書いた HTTP サーバーをコンテナで deploy してみる

時々動作検証などで使っている自作の HTTP サーバー ([test-http-server](https://github.com/yteraoka/test-http-server)) を使って試してみます。

Dockerfile に lambda-adapter をコピーする一行を追加して build & push します。

```
FROM golang:1.23.5 AS build
WORKDIR /app
COPY server.go go.mod go.sum ./
RUN go mod download \
 && CGO_ENABLED=0 GOOS=linux go build -o test-http-server

# hadolint ignore=DL3007
FROM gcr.io/distroless/static-debian11:latest
WORKDIR /
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.9.0 /lambda-adapter /opt/extensions/lambda-adapter
COPY --from=build /app/test-http-server ./
USER nonroot
EXPOSE 8080
ENTRYPOINT ["/test-http-server"]
```

コレだけで Lambda で動くようになります。


## Lambda Function を deploy する

ここでは Web UI からポチポチっと作ってしまいます。

### Container image を使った Lambda Function の作成

一番上の3つの選択肢から Container image を選んで、名前とコンテナのイメージの URI (ECR) を指定したら、後はデフォルトのままで Create function ボタンをクリック。

{{< figure src="create-function.png" alt="Lambda Function の作成" >}}


### Function URL の作成

Configuration →  Function URL で Create function URL をクリック。

{{< figure src="create-function-url.png" alt="Function URL の作成" >}}


### Function URL の設定

今回は認証なし (Auth type → NONE) での公開とする。

{{< figure src="configure-function-url.png" alt="Function URL の設定" >}}


### 環境変数設定

Lambda Adapter からの転送先 port を指定する。

Configuration →  Environment Variables で `PORT` に 8080 を指定する。

これだけなら Dockerfile に書いておいても良い。

### 動作確認

ここまででもう Function URL にアクセスすると HTTP サーバーのレスポンスが返ってくる。
任意の Path にアクセスできるし、QUERY\_STRING も渡せる。POST でデータを送ることも可能。

## カスタムドメイン

Function URL はお手軽だが、公開には向かないので次回は Cloud Front との組み合わせでカスタムドメインでの公開にチャレンジ。
