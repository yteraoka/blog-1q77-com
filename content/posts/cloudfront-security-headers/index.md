---
title: 'CloudFront のレスポンスに Security Headers を追加する'
date: Fri, 31 Dec 2021 16:28:54 +0900
draft: false
tags: ['AWS']
---

「[Amazon CloudFront が設定可能な CORS、セキュリティ、およびカスタム HTTP レスポンスヘッダーをサポート](https://aws.amazon.com/jp/about-aws/whats-new/2021/11/amazon-cloudfront-supports-cors-security-custom-http-response-headers/)」で Lambda@Edge なしで Response にカスタムヘッダーを追加することが可能になりました。 これを使って、このサイトにも Security Headers を追加してみます。

CloudFront のコンソールで、**Policies** → **Response headers** にアクセスすると **Managed policies** があり、次のポリシーが存在します。

* CORS-and-SecurityHeadersPolicy
* CORS-With-Preflight
* CORS-with-preflight-and-SecurityHeadersPolicy
* SecurityHeadersPolicy
* SimpleCORS

SecurityHeaders と CORS の組み合わせパターンですね。

{{< figure src="cloudfront-policies-1.png" >}}

SecurityHeadersPolicy ではレスポンスに次の Header がセットされます。

```
Strict-Transport-Security: max-age=31536000
X-Content-Type-Options:    nosniff
X-Frame-Options:           SAMEORIGIN
X-XSS-Protection:          1; mode=block
Referrer-Policy:           strict-origin-when-cross-origin
```

{{< figure src="cloudfront-policies-2.png" >}}

これを **Distributions** → **Behaviors** の Response headers policy で選択します。

{{< figure src="cloudfront-policies-3.png" >}}
