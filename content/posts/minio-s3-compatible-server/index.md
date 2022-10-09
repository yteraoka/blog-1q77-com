---
title: 'minio で s3 互換サーバーを構築する'
date: 
draft: true
tags: ['minio']
---

[Minio Cloud Storage](https://www.minio.io/) という S3 互換サーバーがあります。 docker で簡単に試せます。

```
$ docker run -p 9000:9000 minio/minio server /export
Created minio configuration file successfully at /root/.minio

Endpoint:  http://172.17.0.2:9000  http://127.0.0.1:9000
AccessKey: AK1X87AJOHI35MA1TWZL 
SecretKey: sF1n7s0s7vK++ef/0xxkjr8aI9NgCPle9h8e0VGj 
Region:    us-east-1
SQS ARNs:  <none>

Browser Access:
   http://172.17.0.2:9000  http://127.0.0.1:9000

Command-line Access: https://docs.minio.io/docs/minio-client-quickstart-guide
   $ mc config host add myminio http://172.17.0.2:9000 AK1X87AJOHI35MA1TWZL sF1n7s0s7vK++ef/0xxkjr8aI9NgCPle9h8e0VGj

Object API (Amazon S3 compatible):
   Go:         https://docs.minio.io/docs/golang-client-quickstart-guide
   Java:       https://docs.minio.io/docs/java-client-quickstart-guide
   Python:     https://docs.minio.io/docs/python-client-quickstart-guide
   JavaScript: https://docs.minio.io/docs/javascript-client-quickstart-guide

Drive Capacity: 1.4 GiB Free, 109 GiB Total
```

AccessKey, SecretKey は環境変数で指定することもできます。
[https://docs.minio.io/docs/minio-docker-quickstart-guide](https://docs.minio.io/docs/minio-docker-quickstart-guide) ブラウザでアクセスすれば Web UI もあります。

{{< figure src="Minio_Browser.png" >}}

AccessKey, SecretKey でログインします。

{{< figure src="Minio_Bucket.png" >}}

### mc コマンド

[mc](https://github.com/minio/mc) (Minio Client) というツールがあります。[https://minio.io/downloads/#minio-client](https://minio.io/downloads/#minio-client) からダウンロードできます。 Minio Client という名前ですが s3 のクライアントとしても使えます。

```
$ mc config host ls
mc: Configuration written to `/home/ytera/.mc/config.json`. Please update your access credentials.
mc: Successfully created `/home/ytera/.mc/share`.
mc: Initialized share uploads `/home/ytera/.mc/share/uploads.json` file.
mc: Initialized share downloads `/home/ytera/.mc/share/downloads.json` file.
gcs  : https://storage.googleapis.com  YOUR-ACCESS-KEY-HERE  YOUR-SECRET-KEY-HERE                      S3v2
local: http://localhost:9000         
play : https://play.minio.io:9000      ********************  ****************************************  S3v4
s3   : https://s3.amazonaws.com        YOUR-ACCESS-KEY-HERE  YOUR-SECRET-KEY-HERE                      S3v4
```

s3 に対応してはいるものの `~/.aws/credentials` を見てくれなくって `~/.mc/config.json` に書く必要があります。

```
$ cat .mc/config.json 
{
	"version": "8",
	"hosts": {
		"gcs": {
			"url": "https://storage.googleapis.com",
			"accessKey": "YOUR-ACCESS-KEY-HERE",
			"secretKey": "YOUR-SECRET-KEY-HERE",
			"api": "S3v2"
		},
		"local": {
			"url": "http://localhost:9000",
			"accessKey": "",
			"secretKey": "",
			"api": "S3v4"
		},
		"play": {
			"url": "https://play.minio.io:9000",
			"accessKey": "********************",
			"secretKey": "****************************************",
			"api": "S3v4"
		},
		"s3": {
			"url": "https://s3.amazonaws.com",
			"accessKey": "YOUR-ACCESS-KEY-HERE",
			"secretKey": "YOUR-SECRET-KEY-HERE",
			"api": "S3v4"
		}
	}
}
```

GCS にも対応してますね。 AWS S3 にアクセスしてみます。まずは `aws` コマンドで。

```
$ aws s3 ls 
2013-02-19 02:10:39 yteraoka-bucket1
2016-02-07 12:37:05 yteraoka-bucket2
2016-02-08 23:54:04 yteraoka-bucket3
2017-04-19 22:35:29 yteraoka-mc-test
```

次に `mc` コマンド。

```
$ mc ls s3
[2013-02-18 23:53:39 JST]     0B yteraoka-bucket1/
[2016-02-07 12:37:05 JST]     0B yteraoka-bucket2/
[2016-02-08 23:54:04 JST]     0B yteraoka-bucket3/
[2017-04-19 22:35:29 JST]     0B yteraoka-mc-test/
```

```
$ mc cp /etc/hosts s3/yteraoka-mc-test
$ mc ls s3/yteraoka-mc-test/hosts
$ mc rm s3/yteraoka-mc-test/hosts
```

### mc コマンドで minio にアクセスする

minio にアクセスするためには `local` のところに minio 起動時に表示された `AccessKey` と `SecretKey` を書きます。host や port も違えば編集が必要です。 `local` でなくても任意の名前で定義が可能です。

```
$ mc ls local
[2017-04-10 23:41:39 JST]     0B bucket1/
$ mc ls local/bucket1/
[2017-04-10 23:40:39 JST]  20KiB Minio Browser.png
[2017-04-10 23:41:39 JST]     9B test.txt
$ mc cp /etc/hosts local/bucket1/
$ mc ls local/bucket1/
[2017-04-10 23:40:39 JST]  20KiB Minio Browser.png
[2017-04-20 00:05:22 JST]   219B hosts
[2017-04-10 23:41:39 JST]     9B test.txt
$ mc rm local/bucket1/hosts
Removing `local/bucket1/hosts`.
$ mc ls local/bucket1/
[2017-04-10 23:40:39 JST]  20KiB Minio Browser.png
[2017-04-10 23:41:39 JST]     9B test.txt
$ mc mb local/bucket2
Bucket created successfully `local/bucket2`.
$ mc ls local
[2017-04-20 00:05:33 JST]     0B bucket1/
[2017-04-20 00:06:44 JST]     0B bucket2/
$ mc rm local/bucket2
Removing `local/bucket2`.
$ mc ls local
[2017-04-20 00:05:33 JST]     0B bucket1/
```

### aws コマンドで minio にアクセスする

まず credentials を設定。region は us-east-1 か未指定で。

```
$ aws configure --profile=minio
```

```
$ aws --profile=minio --endpoint-url http://localhost:9000 s3 ls
2017-04-10 23:41:39 bucket1

$ aws --profile=minio --endpoint-url http://localhost:9000 s3 ls bucket1/
2017-04-10 23:40:39      20159 Minio Browser.png
2017-04-10 23:41:39          9 test.txt
```

`--profile=minio` は環境変数 AWS\_PROFILE で指定も可能。 [https://docs.minio.io/docs/aws-cli-with-minio](https://docs.minio.io/docs/aws-cli-with-minio)

### 分散Minio

[Distributed Minio Quickstart Guide](https://docs.minio.io/docs/distributed-minio-quickstart-guide)

### 消失訂正符号 (Erasure Code)

[Minio Erasure Code QuickStart Guide](https://docs.minio.io/docs/minio-erasure-code-quickstart-guide) [リード・ソロモン符号](https://ja.wikipedia.org/wiki/%E3%83%AA%E3%83%BC%E3%83%89%E3%83%BB%E3%82%BD%E3%83%AD%E3%83%A2%E3%83%B3%E7%AC%A6%E5%8F%B7)
