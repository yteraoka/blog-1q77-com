---
title: "AWS Lambda Web Adapter の Function URL を Cloudfront で公開する"
date: 2025-01-31T00:01:24+09:00
draft: false
tags:
  - AWS
  - Lambda
  - CloudFront
image: cover.png
author: "@yteraoka"
categories:
  - Cloud
---

## これまでのおさらい

[前回](/2025/01/aws-lambda-web-adapter/)、AWS Web Adapter を用いた AWS Lambda に Function URL を使って公開することはできた。

今回はこれをカスタムドメインで公開するべく CloudFront と連携させます。

## OAC (Origin Access Control)

2024年4月に CloudFront と Function URL の間を OAC (Origin Access Control) を使って Function URL への直アクセスを防ぐことができるようになっていたのでこれも試します。
[Amazon CloudFront が Lambda 関数 URL オリジンのオリジンアクセスコントロール (OAC) を新たにサポート](https://aws.amazon.com/jp/about-aws/whats-new/2024/04/amazon-cloudfront-oac-lambda-function-url-origins/)

CloudFront + S3 で OAC に対応した時の Blog ([Amazon CloudFront オリジンアクセスコントロール（OAC）のご紹介](https://aws.amazon.com/jp/blogs/news/amazon-cloudfront-introduces-origin-access-control-oac/))

## CloudFront Distribution の作成

Web Console からぽちぽちします。(CLI はダルいのでコード化するなら Terraform かな)

とりあえずはほとんどデフォルトのまま作成します。

- Origin domain には Function URL のドメインを入力する
- Origin access control で Create new OAC ボタンから OAC を作成する

{{< figure src="create-distribution.png" alt="CloudFront distribution の作成" >}}


### OAC 作成 Window

- Name に任意の値を入れる
- Signing behavior はデフォルト (Sign requests) のまま
- Origin type は Lambda を選択

{{< figure src="create-new-oac.png" alt="OAC の作成" >}}


## CloudFront distribution 作成後の warning を確認

OAC を設定したので黄色い枠のメッセージが表示されている

{{< figure src="warning.png" alt="Warning" >}}

Copy CLI command ボタンをクリックすると実行するべき次のようなコマンドラインがコピーできます。
`<YOUR_FUNCTION_NAME>` を Origin に指定している Lambda function の名前にして実行します。

```bash
aws lambda add-permission \
--statement-id "AllowCloudFrontServicePrincipal" \
--action "lambda:InvokeFunctionUrl" \
--principal "cloudfront.amazonaws.com" \
--source-arn "arn:aws:cloudfront::123456789012:distribution/XXXXXXXXXXXXXX" \
--region "ap-northeast-1" \
--function-name <YOUR_FUNCTION_NAME>
```


## Lambda function URL の Auth type 変更

[前回](/2025/01/aws-lambda-web-adapter/) Lambda function URL を作成した時には誰でもアクセスできるように Auth type を `NONE` にしましたが、
今回は CloudFront 経由でのアクセスのみを許可するべく `AWS_IAM` に変更します。

{{< figure src="configure-function-url.png" alt="Function URL の設定" >}}

コレだけで完成です。CloudFront からのアクセスには署名がついておりアクセスが許可されますが、直接 Function URL にアクセスすると status 403 で次のようなレスポンスが返されます。

```json
{"Message":"Forbidden"}
```


## カスタムドメイン対応する

- AWS Certificate Manager の Virginia region で証明書を発行する (Domain の DNS Verification)
- 証明書を CloudFront distribution に紐付けて、Alternative domain name に追加


## Lambda 側で web-adapter から受け取ったリクエストの例

<details>
<summary>Request Header の例 (Function URL 直)</summary>

```
[Request]
Method: GET
Host: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.lambda-url.ap-northeast-1.on.aws
RequestURI: /
Proto: HTTP/1.1
Content-Length: 0
Close: false
RemoteAddr: 127.0.0.1:41592

[Received Headers]
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7
Accept-Encoding: gzip, deflate, br, zstd
Accept-Language: ja-JP,ja;q=0.9,en-US;q=0.8,en;q=0.7
Cache-Control: max-age=0
Content-Length: 0
Cookie: SESSION_ID=2b8f477c-220b-4a30-ac42-b48c6527d306
Sec-Ch-Ua: "Not A(Brand";v="8", "Chromium";v="132", "Google Chrome";v="132"
Sec-Ch-Ua-Mobile: ?0
Sec-Ch-Ua-Platform: "macOS"
Sec-Fetch-Dest: document
Sec-Fetch-Mode: navigate
Sec-Fetch-Site: none
Sec-Fetch-User: ?1
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36
X-Amzn-Lambda-Context: {"request_id":"79718e73-865e-4151-abd3-e7d42569dc4f","deadline":1738247670633,"invoked_function_arn":"arn:aws:lambda:ap-northeast-1:123456789012:function:web-adapter-go","xray_trace_id":"Root=1-679b8dec-5f98456133b04f3d1bb0fa16;Parent=5070df42a4e144f8;Sampled=0;Lineage=1:e101e8e1:0","client_context":null,"identity":null,"env_config":{"function_name":"web-adapter-go","memory":128,"version":"$LATEST","log_stream":"","log_group":""}}
X-Amzn-Request-Context: {"routeKey":"$default","accountId":"anonymous","stage":"$default","requestId":"79718e73-865e-4151-abd3-e7d42569dc4f","apiId":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx","domainName":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.lambda-url.ap-northeast-1.on.aws","domainPrefix":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx","time":"30/Jan/2025:14:34:20 +0000","timeEpoch":1738247660626,"http":{"method":"GET","path":"/","protocol":"HTTP/1.1","sourceIp":"111.222.333.444","userAgent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36"}}
X-Amzn-Tls-Cipher-Suite: TLS_AES_128_GCM_SHA256
X-Amzn-Tls-Version: TLSv1.3
X-Amzn-Trace-Id: Root=1-679b8dec-5f98456133b04f3d1bb0fa16;Parent=5070df42a4e144f8;Sampled=0;Lineage=1:e101e8e1:0
X-Forwarded-For: 111.222.333.444
X-Forwarded-Port: 443
X-Forwarded-Proto: https

[Server Generated]
uuid: d63fde4a-30bc-44f7-93f8-40f74177fd44
time: 2025-01-30 14:34:20.633872716 +0000 UTC m=+3.588196966
```

</details>

<details>
<summary>Request Header の例 (CloudFront + OAC 経由)</summary>

```
[Request]
Method: GET
Host: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.lambda-url.ap-northeast-1.on.aws
RequestURI: /
Proto: HTTP/1.1
Content-Length: 0
Close: false
RemoteAddr: 127.0.0.1:39942

[Received Headers]
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7
Accept-Encoding: gzip, deflate, br, zstd
Accept-Language: ja-JP,ja;q=0.9,en-US;q=0.8,en;q=0.7
Cloudfront-Forwarded-Proto: https
Cloudfront-Is-Android-Viewer: false
Cloudfront-Is-Desktop-Viewer: true
Cloudfront-Is-Ios-Viewer: false
Cloudfront-Is-Mobile-Viewer: false
Cloudfront-Is-Smarttv-Viewer: false
Cloudfront-Is-Tablet-Viewer: false
Cloudfront-Viewer-Address: 111.222.333.444:61820
Cloudfront-Viewer-Asn: 2516
Cloudfront-Viewer-City: Yanaka
Cloudfront-Viewer-Country: JP
Cloudfront-Viewer-Country-Name: Japan
Cloudfront-Viewer-Country-Region: 13
Cloudfront-Viewer-Country-Region-Name: Tokyo
Cloudfront-Viewer-Http-Version: 2.0
Cloudfront-Viewer-Latitude: 35.00000
Cloudfront-Viewer-Longitude: 139.99999
Cloudfront-Viewer-Postal-Code: 120-0006
Cloudfront-Viewer-Time-Zone: Asia/Tokyo
Cloudfront-Viewer-Tls: TLSv1.3:TLS_AES_128_GCM_SHA256:fullHandshake
Content-Length: 0
Priority: u=0, i
Sec-Ch-Ua: "Not A(Brand";v="8", "Chromium";v="132", "Google Chrome";v="132"
Sec-Ch-Ua-Mobile: ?0
Sec-Ch-Ua-Platform: "macOS"
Sec-Fetch-Dest: document
Sec-Fetch-Mode: navigate
Sec-Fetch-Site: none
Sec-Fetch-User: ?1
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36
Via: 2.0 xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.cloudfront.net (CloudFront)
X-Amz-Cf-Id: I4dTycKJLRkZu38qc81iCUKwe4Sn1ZfpdiHZnPUpQs6NZzwb3t24qw==
X-Amz-Content-Sha256: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
X-Amz-Date: 20250130T145853Z
X-Amz-Security-Token: (snip)
X-Amz-Source-Account: 123456789012
X-Amz-Source-Arn: arn:aws:cloudfront::123456789012:distribution/XXXXXXXXXXXXXX
X-Amzn-Lambda-Context: {"request_id":"dae7c3d6-59f4-4deb-b6fd-4b46cbf04324","deadline":1738249143518,"invoked_function_arn":"arn:aws:lambda:ap-northeast-1:123456789012:function:web-adapter-go","xray_trace_id":"Root=1-679b93ad-5040e3877b2fec4a1b06b137;Parent=6e08ce732aa02dc0;Sampled=0;Lineage=1:e101e8e1:0","client_context":null,"identity":null,"env_config":{"function_name":"web-adapter-go","memory":128,"version":"$LATEST","log_stream":"","log_group":""}}
X-Amzn-Request-Context: {"routeKey":"$default","accountId":"111122223333","stage":"$default","requestId":"dae7c3d6-59f4-4deb-b6fd-4b46cbf04324","authorizer":{"iam":{"accessKey":"(snip)","accountId":"111122223333","callerId":"AROXXXXXXXXXXXXXXXXXX:EdgeCredentialsProxy+EdgeHostAuthenticationClient-NRT12-P2","principalOrgId":null,"userArn":"arn:aws:sts::111122223333:assumed-role/OriginAccessControlRole/EdgeCredentialsProxy+EdgeHostAuthenticationClient-NRT12-P2","userId":"AROXXXXXXXXXXXXXXXXXX:EdgeCredentialsProxy+EdgeHostAuthenticationClient-NRT12-P2"}},"apiId":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx","domainName":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.lambda-url.ap-northeast-1.on.aws","domainPrefix":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx","time":"30/Jan/2025:14:58:53 +0000","timeEpoch":1738249133299,"http":{"method":"GET","path":"/","protocol":"HTTP/1.1","sourceIp":"3.172.8.69","userAgent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36"}}
X-Amzn-Tls-Cipher-Suite: ECDHE-RSA-AES128-GCM-SHA256
X-Amzn-Tls-Version: TLSv1.2
X-Amzn-Trace-Id: Root=1-679b93ad-5040e3877b2fec4a1b06b137;Parent=6e08ce732aa02dc0;Sampled=0;Lineage=1:e101e8e1:0
X-Forwarded-For: 111.222.333.444
X-Forwarded-Port: 443
X-Forwarded-Proto: https

[Server Generated]
uuid: fb5ff0cb-03f0-444e-93b4-e7b7399c5ce0
time: 2025-01-30 14:58:53.538004229 +0000 UTC m=+0.046553638
```

</details>
