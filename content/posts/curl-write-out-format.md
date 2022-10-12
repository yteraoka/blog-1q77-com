---
title: 'Curl で時間計測'
date: Wed, 24 Jul 2019 15:03:51 +0000
draft: false
tags: ['curl']
---

curl には -w, --write-out というオプションがあり、HTTP のコードやどのフェーズに何秒かかったかなどを出力することができます。ときどき調査で使うのですが、毎回 man curl することになるのでコピペで使えるようにメモっておく

```
curl -so /dev/nul -w "http\_code: %{http\_code}\\ntime\_namelookup: %{time\_namelookup}\\ntime\_connect: %{time\_connect}\\ntime\_appconnect: %{time\_appconnect}\\ntime\_pretransfer: %{time\_pretransfer}\\ntime\_starttransfer: %{time\_starttransfer}\\ntime\_total: %{time\_total}\\n" https://www.google.com/
```

これで次のような出力が得られる

```
http_code: 200
time_namelookup: 0.002
time_connect: 0.005
time_appconnect: 0.054
time_pretransfer: 0.054
time_starttransfer: 0.126
time_total: 0.126
```

他にも次のような変数が用意されている

| name | description |
|------|-------------|
| content\_type | レスポンスの Content-Type |
| filename\_effective | curl が書き出すファイル名。`--remote-name` か `--output` とともに使う場合にのみ意味を持つ。`--remote-header-name` と使うのが最も有用 (7.25.1 で追加された) |
| ftp\_entry\_path | FTP でログインした際の最初のディレクトリ path (7.15.4 で追加された) |
| http\_code       | レスポンスのコード 200 とか 404 とか。最後のレスポンスのコードなので、リダイレクト先へもアクセスする場合はリダイレクト後のレスポンス。7.18.2 で `response_code` という alias が追加された |
| http\_connect    | CONNECT に対するレスポンスのコード (7.12.4 で追加された) |
| local\_ip        | 接続時のローカル側のIPアドレス (7.29.0 で追加された) |
| local\_port      | 接続時のローカル側のポート番号 (7.29.0 で追加された) |
| num\_connects    | Number of new connects made in the recent transfer. (7.12.3 で追加された) |
| num\_redirects   | リダイレクトされた回数 (7.12.3 で追加された) |
| redirect\_url    | `-L` を使わず、redirect 先にアクセスしない場合に redirect 先が入っている (7.18.2 で追加された) |
| remote\_ip       | 接続先のIPアドレス (7.29.0 で追加された) |
| remote\_port     | 接続先のポート番号 (7.29.0 で追加された) |
| size\_download   | ダウンロードしたバイト数。ヘッダーを含む |
| size\_header     | レスポンスヘッダーのバイト数 |
| size\_request    | リクエストのバイト数 |
| size\_upload     | リクエストボディのバイト数 |
| speed\_download  | ダウンロードの平均 Bytes per second |
| speed\_upload    | アップロードの平均 Bytes per second |
| ssl\_verify\_result | 証明書の検証結果、0 が成功 (7.19.0 で追加された) |
| time\_appconnect    | TLS ハンドシェイクが完了するまでにかかった時間（秒） |
| time\_connect | TCP の connect が完了するまでの時間（秒） |
| time\_namelookup | 名前解決が完了するまでにかかった時間（秒） |
| time\_pretransfer | ファイル転送が始まるまでにかかった時間（秒）|
| time\_redirect | リダイレクトを辿った最後のリクエストまでの時間（秒） |
| time\_starttransfer | レスポンスの最初のバイトを受け取るまでの時間（秒） |
| time\_total | ダウンロードが完了するまでの時間（秒） |
| url\_effective | 最後にリクエストした URL |

「時間（秒）」は単位は秒だが制度はミリ秒

毎度長ったらしい引数を指定するのは煩わしいです。そんな場合は `-w @filename` のようにしてファイルで渡すことができます。次の内容のテキストファイルを curl.out という名前（任意）で作成し、

```
content_type:       %{content_type}\n
filename_effective: %{filename_effective}\n
ftp_entry_path:     %{ftp_entry_path}\n
http_code:          %{http_code}\n
http_connect:       %{http_connect}\n
local_ip:           %{local_ip}\n
local_port:         %{local_port}\n
num_connects:       %{num_connects}\n
num_redirects:      %{num_redirects}\n
redirect_url:       %{redirect_url}\n
remote_ip:          %{remote_ip}\n
remote_port:        %{remote_port}\n
size_download:      %{size_download}\n
size_header:        %{size_header}\n
size_request:       %{size_request}\n
size_upload:        %{size_upload}\n
speed_download:     %{speed_download}\n
speed_upload:       %{speed_upload}\n
ssl_verify_result:  %{ssl_verify_result}\n
time_appconnect:    %{time_appconnect}\n
time_connect:       %{time_connect}\n
time_namelookup:    %{time_namelookup}\n
time_pretransfer:   %{time_pretransfer}\n
time_redirect:      %{time_redirect}\n
time_starttransfer: %{time_starttransfer}\n
time_total:         %{time_total}\n
url_effective:      %{url_effective}\n
```

`-w @curl.out` で指定すれば次のような出力が得られます。`-w @-` と、ファイル名を「`-`」にすれば標準入力から渡すこともできます

```
$ curl -so /dev/null -w @curl.out https://www.google.com/
content_type:       text/html; charset=ISO-8859-1
filename_effective: /dev/null
ftp_entry_path:
http_code:          200
http_connect:       000
local_ip:           172.26.45.140
local_port:         43760
num_connects:       1
num_redirects:      0
redirect_url:
remote_ip:          172.217.25.228
remote_port:        443
size_download:      12618
size_header:        772
size_request:       78
size_upload:        0
speed_download:     98443.000
speed_upload:       0.000
ssl_verify_result:  0
time_appconnect:    0.052
time_connect:       0.004
time_namelookup:    0.001
time_pretransfer:   0.052
time_redirect:      0.000
time_starttransfer: 0.128
time_total:         0.128
url_effective:      https://www.google.com/
```

JSON 出力

2020年4月29日リリース予定の 7.70.0 では `--write-out '%{json}'` とすることで全部入りの json を取得できるようになるそうです。「[CURL WRITE-OUT JSON](https://daniel.haxx.se/blog/2020/03/17/curl-write-out-json/)」

```json
{
  "url_effective": "https://example.com/",
  "http_code": 200,
  "response_code": 200,
  "http_connect": 0,
  "time_total": 0.44054,
  "time_namelookup": 0.001067,
  "time_connect": 0.11162,
  "time_appconnect": 0.336415,
  "time_pretransfer": 0.336568,
  "time_starttransfer": 0.440361,
  "size_header": 347,
  "size_request": 77,
  "size_download": 1256,
  "size_upload": 0,
  "speed_download": 0.002854,
  "speed_upload": 0,
  "content_type": "text/html; charset=UTF-8",
  "num_connects": 1,
  "time_redirect": 0,
  "num_redirects": 0,
  "ssl_verify_result": 0,
  "proxy_ssl_verify_result": 0,
  "filename_effective": "saved",
  "remote_ip": "93.184.216.34",
  "remote_port": 443,
  "local_ip": "192.168.0.1",
  "local_port": 44832,
  "http_version": "2",
  "scheme": "HTTPS",
  "curl_version": "libcurl/7.69.2 GnuTLS/3.6.12 zlib/1.2.11 brotli/1.0.7 c-ares/1.15.0 libidn2/2.3.0 libpsl/0.21.0 (+libidn2/2.3.0) nghttp2/1.40.0 librtmp/2.3"
}
```
