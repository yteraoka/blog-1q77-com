---
title: 'httpbin.org で X-Forwarded-For ヘッダーを確認する方法'
date: Wed, 05 Aug 2020 15:09:08 +0000
draft: false
tags: ['Uncategorized']
---

[https://httpbin.org/](https://httpbin.org/) は HTTP クライアントや Reverse Proxy のテストなどで非常に便利なサイトです。[Docker Image](https://hub.docker.com/r/kennethreitz/httpbin/) も公開されているのでローカルでも使えます。大変お世話になっております。

でもなぜか [/headers](https://httpbin.org/headers) などにアクセスしても X-Forwarded-For や X-Forwarded-Proto などが表示されません。

それを確認するために HTTP サーバーを書いたりもしていたのですが、**show\_env** というパラメータを渡すことで確認できることを知ったのでメモ。

[https://httpbin.org/get?show\_env=1](https://httpbin.org/get?show_env=1) や [https://httpbin.org/headers?show\_env=1](https://httpbin.org/headers?show_env=1)

[https://httpbin.org/legacy](https://httpbin.org/legacy) には例が載っていました。

```
❯ curl -s http://httpbin.org/headers\?show_env=1
{
  "headers": {
    "Accept": "*/*", 
    "Host": "httpbin.org", 
    "User-Agent": "curl/7.64.1", 
    "X-Amzn-Trace-Id": "Root=1-5f2ac9c1-43a9f7d5cf1b714ad7798979", 
    "X-Forwarded-For": "203.0.113.123", 
    "X-Forwarded-Port": "80", 
    "X-Forwarded-Proto": "http"
  }
}
```

```
❯ curl -s http://httpbin.org/headers            
{
  "headers": {
    "Accept": "*/*", 
    "Host": "httpbin.org", 
    "User-Agent": "curl/7.64.1", 
    "X-Amzn-Trace-Id": "Root=1-5f2ac9c5-d01ecd74ee650c947ce36d6c"
  }
}
```

ちなみに 203.0.113.0/24 は例示用 IP アドレスらしいです。\[[RFC6890](https://tools.ietf.org/html/rfc6890)\]

参考サイト: [例示専用のIPアドレスとドメインを使いこなす | ギークを目指して](http://equj65.net/tech/documentationip/)
