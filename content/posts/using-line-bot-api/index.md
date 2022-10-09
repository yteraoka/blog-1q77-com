---
title: 'LINE BOT API を試してみた'
date: Sun, 10 Apr 2016 02:23:57 +0000
draft: false
tags: ['Bot', 'Flask', 'LINE', 'Python', 'python']
---

流行りに乗って [LINE BOT API](https://developers.line.me/bot-api/overview) を試してみた。

{{< figure src="borobot-screenshot.jpg" alt="borobot-screenshot" >}}

仕組みとしては誰かが LINE からのアクセスを受ける口 (Callback URL) を準備して待っていれば、「友達登録（ブロック解除）」、「ブロック」、「メッセージ」が送られてくるというもの。

友だち登録してもらえればそのアカウント情報(mid?)が得られるので宛先に指定すればメッセージを送ることが可能。

ブロックされたことがわかるので知らずにメッセージを送り続けるという無駄がなくせます。友達解除のことがブロックと等価なのかな。 メッセージには「テキスト」、「画像」、「動画」、「位置情報」といったパターンがある。

mid からユーザー情報を得るための API もあり、次のような結果が得られるのでメッセージに名前を入れたり友達管理に名前が使えます。

```json
{
  "contacts": [
    {
      "displayName": "浦島太郎",
      "mid": "********************************",
      "pictureUrl": "",
      "statusMessage": "玉手箱開けちゃった"
    }
  ],
  "count": 1,
  "display": 1,
  "pagingRequest": {
    "start": 1,
    "display": 1,
    "sortBy": "MID"
  },
  "start": 1,
  "total": 1
}
```

今は Callback API のタイムアウトが10秒というゆるい設定のようなのですし、友達登録可能な上限が50と少ないのでリクエストを受けた処理の中でそのまま返信することができますが、沢山リクエストが来るようになるとそれでは捌き切れなかったり、エラーハンドリングで困るので Callback で受けたデータはシグネチャの検証だけやって job queue に突っ込むという設計にすべきのようです。

事前共有鍵を使い HMAC SHA256 で X-LINE-ChannelSignature ヘッダーの値と一致することを検証

```python
import hmac, hashlib, base64

if request.headers.get('X-LINE-ChannelSignature') == base64.b64encode(hmac.new(CHANNEL_SECRET, request.get_data(), hashlib.sha256).digest()):
    return True
```

メッセージの送信は white list に登録した IP アドレスからであれば自由に送信できます。

```
curl -X POST https://trialbot-api.line.me/v1/events \
 -H "Content-Type: application/json; charser=UTF-8" \
 -H "X-Line-ChannelID: **********" \
 -H "X-Line-ChannelSecret: ********************************" \
 -H "X-Line-Trusted-User-With-ACL: u********************************" \
 -d '
{
  "to": [
    "u********************************"
  ],
  "toChannel": "1383378250",
  "eventType": "138311608800106203",
  "content": {
    "contentType": "1",
    "toType": "1",
    "text": "おはようございます、月曜日の朝です"
  }
}
'
```

こんな結果が返ってきます。

```json
{
  "failed": [],
  "messageId": "1460327400008",
  "timestamp": 1460327400008,
  "version": 1
}
```

White list に登録されていない IP アドレスから送信しようとすると次のように拒否されます

```json
{
  "statusCode": "427",
  "statusMessage": "Your ip address [xxx.xxx.xxx.xxx] is not allowed to access this API."
}
```

[Flask](http://flask.pocoo.org/) で簡単な返信までするコード書いちゃったけど [Celery](http://www.celeryproject.org/) 使ったジョブキュー方式に書き直そう。Celery の勉強を兼ねて。
