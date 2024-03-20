---
title: "MinIO Client で Amazon S3 や Cloudflare R2 を利用する"
date: 2023-11-12T20:13:31+09:00
draft: false
tags: ["AWS", "S3", "Cloudflare", "R2"]
image: cover.jpg
---

Cloudflare R2 は egress の費用がかからないということで手元のファイルのバックアップに使ってみようかなと思ったときにクライアントとして何を使おうかな aws cli 使うほどじゃないしなということで [MinIO Client (mc)](https://github.com/minio/mc) を使ってみたメモ。

## mc コマンドの Install

Mac で Homebrew が使えれば `brew install minio/stable/mc` でインストール可能ですし、Go 言語で書かれたプログラムで Linux と Windows 用のバイナリも提供されているので curl や wget で取ってくるだけです。

例えば

```bash
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
./mc --help
```


## Amazon S3 で使う場合

これは shell script の中で loop で何度も `aws s3 ...` コマンドを実行すると遅いってのがあって前に使ったことがありました。

まず認証情報を設定します。

```bash
mc alias set s3 https://s3.amazonaws.com ${AWS_ACCESS_KEY_ID} ${AWS_SECRET_ACCESS_KEY}
```

`s3` 部分は任意の文字列を指定可能で、`s4` でも `s5` でもなんでも良い。クレデンシャルと紐づくのでクレデンシャルごとに意味のある値にするのが良い。
Endpoint URL は `https://s3.ap-northeast-1.amazonaws.com` のような regional な endpoint を指定することも可能ですが、その場合、他の region にある bucket にアクセスできませんでした。

この alias 設定は `~/.mc/config.json` に保存されますし、`mc alias ls` で確認することも可能。

`mc ls s3` で `aws s3 ls` と似た bucket のリストが表示されます。

`mc ls s3/${BUCKET_NAME}` で `aws s3 ls s3://${BUCKET_NAME}` と似たような path を `/` で区切った表示がされます。

`mc ls s3/${BUCKET_NAME}/${OBJECT_PATH}` もまた同様。

大抵の操作を行うことができます。

```
NAME:
  mc - MinIO Client for object storage and filesystems.

USAGE:
  mc [FLAGS] COMMAND [COMMAND FLAGS | -h] [ARGUMENTS...]

COMMANDS:
  alias      manage server credentials in configuration file
  ls         list buckets and objects
  mb         make a bucket
  rb         remove a bucket
  cp         copy objects
  mv         move objects
  rm         remove object(s)
  mirror     synchronize object(s) to a remote site
  cat        display object contents
  head       display first 'n' lines of an object
  pipe       stream STDIN to an object
  find       search for objects
  sql        run sql queries on objects
  stat       show object metadata
  tree       list buckets and objects in a tree format
  du         summarize disk usage recursively
  retention  set retention for object(s)
  legalhold  manage legal hold for object(s)
  support    support related commands
  license    license related commands
  share      generate URL for temporary access to an object
  version    manage bucket versioning
  ilm        manage bucket lifecycle
  quota      manage bucket quota
  encrypt    manage bucket encryption config
  event      manage object notifications
  watch      listen for object notification events
  undo       undo PUT/DELETE operations
  anonymous  manage anonymous access to buckets and objects
  tag        manage tags for bucket and object(s)
  diff       list differences in object name, size, and date between two buckets
  replicate  configure server side bucket replication
  admin      manage MinIO servers
  idp        manage MinIO IDentity Provider server configuration
  update     update mc to latest release
  ready      checks if the cluster is ready or not
  ping       perform liveness check
  od         measure single stream upload and download
  batch      manage batch jobs
```

### SESSION\_TOKEN を使う場合

`~/.mc/config.json` には次のような JSON になっています。ここに `sessionToken` という field を追加してやるとアクセス可能になります。sessionToken は永続的なものではなく、短命なものなので更新が面倒ですが方法がないわけではない程度で。

```json
{
  "version": "10",
  "aliases": {
    "s3": {
      "url": "https://s3.amazonaws.com",
      "accessKey": "(省略)",
      "secretKey": "(省略)",
      "api": "s3v4",
      "path": "auth"
    }
  }
}
```

## Cloudflare R2 で使う場合

Cloudflare R2 では次のように endpoint に Account ID が入りますが、あとは Cloudflare の Console から API token を作成してやれば Access Key ID と Secret Access Key で S3 と同じように操作が可能です。


```
https://${ACCOUNT_ID}.r2.cloudflarestorage.com
```

## Cloudflare R2 vs Google One

ところで、Cloudflare R2 のお値段ですが、GB あたり $0.015 です。
例えば 500GB 置くとすると $7.5 です。
2023年11月12日の1ドル151.53円では1136.475円。

{{< figure src="cloudflare-r2-pricing.png" alt="Cloudflare R2 Pricing" >}}

現在、Google One のスタンダードで200GBを380円で利用中です。
これをプレミアムで2TBにアップグレードした場合、月額1,300円です。
おやおや？こっちの方がリーズナブルですね。

{{< figure src="google-one-plans.png" alt="Google One Plans" >}}
