---
title: 'play1 の @status endpoing'
date: Sun, 15 Jul 2018 14:20:44 +0000
draft: false
tags: ['PlayFramework', 'Java']
---

[play1](https://github.com/playframework/play1) には `status` というサブコマンドがあります。 [status.py](https://github.com/playframework/play1/blob/master/framework/pym/play/commands/status.py), [PlayStatusPlugin.java](https://github.com/playframework/play1/blob/master/framework/src/play/plugins/PlayStatusPlugin.java) あたりのコード。 コマンドのドキュメント ([cmd-status.txt](https://github.com/playframework/play1/blob/master/documentation/commands/cmd-status.txt))

```
$ play status APPDIR
```

port がデフォルトと違う場合は port を指定

```
$ play status APPDIR --http.port=8080
```

環境ごとの設定を行っている場合は `--%ENV` で指定

```
$ play status APPDIR --%prod
```

JVM のメモリ情報、Thread の状態や、Request と Job を実行する thread pool の情報

```
Java:
~~~~~
Version: 1.8.0_171
Home: /usr/java/jdk1.8.0_171/jre
Max memory: 4294967296
Free memory: 2981053320
Total memory: 4294967296
Available processors: 4
```

```
Requests execution pool:
~~~~~~~~~~~~~~~~~~~~~~~~
Pool size: XX
Active count: XX
Scheduled task count: XXXXX
Queue size: X
```

URL にマップされているメソッドごとの実行回数(hit), 実行時間(avg, min, max)、 DBCP 設定、Job の情報などが確認できます。 status コマンドは内部で `/@status` に HTTP でアクセスしてそのレスポンスをそのまま返しています。 `/@status.json` という URL も用意されており、JSON でレスポンスが返されます。ただし、残念ながら情報量がずっと少ない、バグかな？ ただ、HTTP でアクセスしても 401 Unauthorized となります、認証を通すためには `conf/application.conf` で設定してある `secret` が必要です。 status コマンドは python で次のようになっているので

```python
hm = hmac.new(secret_key, '@status', sha)
authorization = hm.hexdigest()
```

shell では openssl で次のようにして得ることができます

```bash
echo -n '@status' | openssl sha1 -hmac 'secret_key'
```

これを Authorization ヘッダーとして渡せばアクセスできます。
