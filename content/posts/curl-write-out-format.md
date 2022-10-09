---
title: 'Curl で時間計測'
date: Wed, 24 Jul 2019 15:03:51 +0000
draft: false
tags: ['curl', 'curl']
---

curl には -w, --write-out というオプションがあり、HTTP のコードやどのフェーズに何秒かかったかなどを出力することができます。ときどき調査で使うのですが、毎回 man curl することになるのでコピペで使えるようにメモっておく

```
curl -so /dev/nul -w "http\_code: %{http\_code}\\ntime\_namelookup: %{time\_namelookup}\\ntime\_connect: %{time\_connect}\\ntime\_appconnect: %{time\_appconnect}\\ntime\_pretransfer: %{time\_pretransfer}\\ntime\_starttransfer: %{time\_starttransfer}\\ntime\_total: %{time\_total}\\n" https://www.google.com/

```

これで次のような出力が得られる

```
http\_code: 200
time\_namelookup: 0.002
time\_connect: 0.005
time\_appconnect: 0.054
time\_pretransfer: 0.054
time\_starttransfer: 0.126
time\_total: 0.126

```

他にも次のような変数が用意されている

content\_type

レスポンスの Content-Type

filename\_effective

curl が書き出すファイル名。`--remote-name` か `--output` とともに使う場合にのみ意味を持つ。`--remote-header-name` と使うのが最も有用 (7.25.1 で追加された)

ftp\_entry\_path

FTP でログインした際の最初のディレクトリ path (7.15.4 で追加された)

http\_code

レスポンスのコード 200 とか 404 とか。最後のレスポンスのコードなので、リダイレクト先へもアクセスする場合はリダイレクト後のレスポンス。7.18.2 で `response_code` という alias が追加された

http\_connect

CONNECT に対するレスポンスのコード (7.12.4 で追加された)

local\_ip

接続時のローカル側のIPアドレス (7.29.0 で追加された)

local\_port

接続時のローカル側のポート番号 (7.29.0 で追加された)

num\_connects

Number of new connects made in the recent transfer. (7.12.3 で追加された)

num\_redirects

リダイレクトされた回数 (7.12.3 で追加された)

redirect\_url

`-L` を使わず、redirect 先にアクセスしない場合に redirect 先が入っている (7.18.2 で追加された)

remote\_ip

接続先のIPアドレス (7.29.0 で追加された)

remote\_port

接続先のポート番号 (7.29.0 で追加された)

size\_download

ダウンロードしたバイト数。ヘッダーを含む

size\_header

レスポンスヘッダーのバイト数

size\_request

リクエストのバイト数

size\_upload

リクエストボディのバイト数

speed\_download

ダウンロードの平均 Bytes per second

speed\_upload

アップロードの平均 Bytes per second

ssl\_verify\_result

証明書の検証結果、0 が成功 (7.19.0 で追加された)

time\_appconnect

TLS ハンドシェイクが完了するまでにかかった時間（秒）

time\_connect

TCP の connect が完了するまでの時間（秒）

time\_namelookup

名前解決が完了するまでにかかった時間（秒）

time\_pretransfer

ファイル転送が始まるまでにかかった時間（秒）

time\_redirect

リダイレクトを辿った最後のリクエストまでの時間（秒）

time\_starttransfer

レスポンスの最初のバイトを受け取るまでの時間（秒）

time\_total

ダウンロードが完了するまでの時間（秒）

url\_effective

最後にリクエストした URL

「時間（秒）」は単位は秒だが制度はミリ秒

毎度長ったらしい引数を指定するのは煩わしいです。そんな場合は `-w @filename` のようにしてファイルで渡すことができます。次の内容のテキストファイルを curl.out という名前（任意）で作成し、

```
content\_type:       %{content\_type}\\n
filename\_effective: %{filename\_effective}\\n
ftp\_entry\_path:     %{ftp\_entry\_path}\\n
http\_code:          %{http\_code}\\n
http\_connect:       %{http\_connect}\\n
local\_ip:           %{local\_ip}\\n
local\_port:         %{local\_port}\\n
num\_connects:       %{num\_connects}\\n
num\_redirects:      %{num\_redirects}\\n
redirect\_url:       %{redirect\_url}\\n
remote\_ip:          %{remote\_ip}\\n
remote\_port:        %{remote\_port}\\n
size\_download:      %{size\_download}\\n
size\_header:        %{size\_header}\\n
size\_request:       %{size\_request}\\n
size\_upload:        %{size\_upload}\\n
speed\_download:     %{speed\_download}\\n
speed\_upload:       %{speed\_upload}\\n
ssl\_verify\_result:  %{ssl\_verify\_result}\\n
time\_appconnect:    %{time\_appconnect}\\n
time\_connect:       %{time\_connect}\\n
time\_namelookup:    %{time\_namelookup}\\n
time\_pretransfer:   %{time\_pretransfer}\\n
time\_redirect:      %{time\_redirect}\\n
time\_starttransfer: %{time\_starttransfer}\\n
time\_total:         %{time\_total}\\n
url\_effective:      %{url\_effective}\\n

```

`-w @curl.out` で指定すれば次のような出力が得られます。`-w @-` と、ファイル名を「`-`」にすれば標準入力から渡すこともできます

```
$ curl -so /dev/null -w @curl.out https://www.google.com/
content\_type:       text/html; charset=ISO-8859-1
filename\_effective: /dev/null
ftp\_entry\_path:
http\_code:          200
http\_connect:       000
local\_ip:           172.26.45.140
local\_port:         43760
num\_connects:       1
num\_redirects:      0
redirect\_url:
remote\_ip:          172.217.25.228
remote\_port:        443
size\_download:      12618
size\_header:        772
size\_request:       78
size\_upload:        0
speed\_download:     98443.000
speed\_upload:       0.000
ssl\_verify\_result:  0
time\_appconnect:    0.052
time\_connect:       0.004
time\_namelookup:    0.001
time\_pretransfer:   0.052
time\_redirect:      0.000
time\_starttransfer: 0.128
time\_total:         0.128
url\_effective:      https://www.google.com/

```

JSON 出力

2020年4月29日リリース予定の 7.70.0 では `--write-out '%{json}'` とすることで全部入りの json を取得できるようになるそうです。「[CURL WRITE-OUT JSON](https://daniel.haxx.se/blog/2020/03/17/curl-write-out-json/)」

```
{
  "url\_effective": "https://example.com/",
  "http\_code": 200,
  "response\_code": 200,
  "http\_connect": 0,
  "time\_total": 0.44054,
  "time\_namelookup": 0.001067,
  "time\_connect": 0.11162,
  "time\_appconnect": 0.336415,
  "time\_pretransfer": 0.336568,
  "time\_starttransfer": 0.440361,
  "size\_header": 347,
  "size\_request": 77,
  "size\_download": 1256,
  "size\_upload": 0,
  "speed\_download": 0.002854,
  "speed\_upload": 0,
  "content\_type": "text/html; charset=UTF-8",
  "num\_connects": 1,
  "time\_redirect": 0,
  "num\_redirects": 0,
  "ssl\_verify\_result": 0,
  "proxy\_ssl\_verify\_result": 0,
  "filename\_effective": "saved",
  "remote\_ip": "93.184.216.34",
  "remote\_port": 443,
  "local\_ip": "192.168.0.1",
  "local\_port": 44832,
  "http\_version": "2",
  "scheme": "HTTPS",
  "curl\_version": "libcurl/7.69.2 GnuTLS/3.6.12 zlib/1.2.11 brotli/1.0.7 c-ares/1.15.0 libidn2/2.3.0 libpsl/0.21.0 (+libidn2/2.3.0) nghttp2/1.40.0 librtmp/2.3"
}

```