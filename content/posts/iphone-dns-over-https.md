---
title: "DNS over HTTPS 通信の中身を確認する"
date: 2022-10-16T00:11:55+09:00
draft: false
tags: ['DNS', 'DOH', 'Python']
---

iPhone の HTTP(S) 通信を OWASP ZAP で覗いてみたたら 8.8.8.8, 8.8.4.4 に対して DNS over HTTPS の通信を見つけたのでどんなやり取りをしているのか確認してみた。


## DNS over HTTPS でのリクエスト

リクエストは HTTP の GET メソッドで `/dns-query` に `dns` という QUERY STRING で送られていました。

```
GET /dns-query?dns=AAABAAABAAAAAAABCjQ3LWNvdXJpZXIEcHVzaAVhcHBsZQNjb20AAEEAAQAAKQIAAAAAAABKAAwARgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA HTTP/1.1
Host: 8.8.4.4
Content-Type: application/dns-message
Connection: keep-alive
Accept: application/dns-message
```

`dns` パラメータの値は UDP で使われているのと同じバイナリメッセージを Base64 でエンコードしたものでした。
base64 の padding は省略されるようです。

ではこの `dns` パラメータの中身を確認してみます。

[dnspython](https://pypi.org/project/dnspython/) を使うと便利でした。

```python
import base64
import sys
import dns.message

payload = sys.argv[1]

# padding を補完
payload += "=" * (len(payload) % 4)

raw = base64.b64decode(payload)
msg = dns.message.from_wire(raw)

print(msg)
```

上のコードを `decode-dns-query.py` として保存したとして

```bash
python3 -m venv venv
source venv/bin/activate
pip install dnspython
python decode-dns-query.py AAABAAABAAAAAAABCjQ3LWNvdXJpZXIEcHVzaAVhcHBsZQNjb20AAEEAAQAAKQIAAAAAAABKAAwARgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
```

と実行すると次のように出力されます

```
id 0
opcode QUERY
rcode NOERROR
flags RD
edns 0
payload 512
option Generic 12
;QUESTION
47-courier.push.apple.com. IN HTTPS
;ANSWER
;AUTHORITY
;ADDITIONAL
```

おぉ！ `47-courier.push.apple.com` の `HTTPS` レコードを問い合わせてますね。Apple はもう `HTTPS` レコードを使っているとは聞いていたけど。
早速出くわすとは。


## DNS over HTTPS でのレスポンス

次にレスポンスを確認します。レスポンスはバイナリなので curl ではファイルに出力しないと確認できません。

```bash
curl -o response "https://8.8.4.4/dns-query?dns=AAABAAABAAAAAAABCjQ3LWNvdXJpZXIEcHVzaAVhcHBsZQNjb20AAEEAAQAAKQIAAAAAAABKAAwARgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
```

```
$ file response
response: data
```

このレスポンスも UDP でやり取りするのと同じフォーマットらしいのでリクエストと同様に dnspython で decode してみます。

次のコードを用意しました。

```python
import base64
import sys
import dns.message

file = sys.argv[1]

f = open(file, "rb")
data = f.read()

msg = dns.message.from_wire(data)

print(msg)
```

```bash
python decode-dns-response.py ./response
```

実行結果です

```
id 0
opcode QUERY
rcode NOERROR
flags QR RD RA
edns 0
payload 512
option Generic 12
;QUESTION
47-courier.push.apple.com. IN HTTPS
;ANSWER
47-courier.push.apple.com. 7107 IN CNAME 47.courier-push-apple.com.akadns.net.
47.courier-push-apple.com.akadns.net. 60 IN CNAME apac-asia-courier-4.push-apple.com.akadns.net.
;AUTHORITY
akadns.net. 38 IN SOA internal.akadns.net. hostmaster.akamai.com. 1629813934 90000 90000 90000 180
;ADDITIONAL
```

HTTPS レコードはまだよく知らないので、ふーん、こんなのが返ってくるんだ... としか。


## dns.google.com/resolve で確認

dig コマンドが HTTPS レコードに対応してないので https:/dns.google.com/resolve で確認した結果も貼っておく。

```bash
curl -s "https://dns.google.com/resolve?name=47-courier.push.apple.com&type=HTTPS" | jq
```

```json
{
  "Status": 0,
  "TC": false,
  "RD": true,
  "RA": true,
  "AD": false,
  "CD": false,
  "Question": [
    {
      "name": "47-courier.push.apple.com.",
      "type": 65
    }
  ],
  "Answer": [
    {
      "name": "47-courier.push.apple.com.",
      "type": 5,
      "TTL": 6697,
      "data": "47.courier-push-apple.com.akadns.net."
    },
    {
      "name": "47.courier-push-apple.com.akadns.net.",
      "type": 5,
      "TTL": 60,
      "data": "apac-asia-courier-4.push-apple.com.akadns.net."
    }
  ],
  "Authority": [
    {
      "name": "akadns.net.",
      "type": 6,
      "TTL": 12,
      "data": "internal.akadns.net. hostmaster.akamai.com. 1629813934 90000 90000 90000 180"
    }
  ]
}
```


## dig では type65 と指定すれば良いらしい

その後 dig でも `type65` と指定すれば良いと知った

```
$ dig 47-courier.push.apple.com type65

; <<>> DiG 9.10.6 <<>> 47-courier.push.apple.com type65
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 65301
;; flags: qr rd ra; QUERY: 1, ANSWER: 2, AUTHORITY: 1, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 512
;; QUESTION SECTION:
;47-courier.push.apple.com.	IN	TYPE65

;; ANSWER SECTION:
47-courier.push.apple.com. 18413 IN	CNAME	47.courier-push-apple.com.akadns.net.
47.courier-push-apple.com.akadns.net. 60 IN CNAME apac-asia-courier-4.push-apple.com.akadns.net.

;; AUTHORITY SECTION:
akadns.net.		179	IN	SOA	internal.akadns.net. hostmaster.akamai.com. 1629813934 90000 90000 90000 180

;; Query time: 37 msec
;; SERVER: 192.168.210.100#53(192.168.210.100)
;; WHEN: Sun Oct 16 00:48:47 JST 2022
;; MSG SIZE  rcvd: 212
```


## Cloudflare の HTTPS レコードを引いてみる

47-courier.push.apple.com は CNAME が返ってきており、全然 HTTPS っぽさがないので HTTPS レコードが使われているという
www.cloudflare.com で試してみる。

```
$ dig www.cloudflare.com type65

; <<>> DiG 9.10.6 <<>> www.cloudflare.com type65
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 3173
;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 512
;; QUESTION SECTION:
;www.cloudflare.com.		IN	TYPE65

;; ANSWER SECTION:
www.cloudflare.com.	300	IN	TYPE65	\# 67 0001000001000C0268330568332D32390268320004000868107B6068 107C600006002026064700000000000000000068107B602606470000 0000000000000068107C60

;; Query time: 92 msec
;; SERVER: 192.168.210.100#53(192.168.210.100)
;; WHEN: Sun Oct 16 00:49:28 JST 2022
;; MSG SIZE  rcvd: 126
```

うーむ、読めないじゃん...

https://dns.google.com/resolve でも試してみる

```bash
curl -s "https://dns.google.com/resolve?name=www.cloudflare.com&type=HTTPS" | jq
```

```json
{
  "Status": 0,
  "TC": false,
  "RD": true,
  "RA": true,
  "AD": true,
  "CD": false,
  "Question": [
    {
      "name": "www.cloudflare.com.",
      "type": 65
    }
  ],
  "Answer": [
    {
      "name": "www.cloudflare.com.",
      "type": 65,
      "TTL": 300,
      "data": "1 . alpn=h3,h3-29,h2 ipv4hint=104.16.123.96,104.16.124.96 ipv6hint=2606:4700::6810:7b60,2606:4700::6810:7c60"
    }
  ],
  "Comment": "Response from 162.159.2.9."
}
```

わかりやすーい！！

## www.google.com の HTTPS レコード

www.google.com でも確認してみた

```bash
curl -s "https://dns.google.com/resolve?name=www.google.com&type=HTTPS" | jq
```

```
{
  "Status": 0,
  "TC": false,
  "RD": true,
  "RA": true,
  "AD": false,
  "CD": false,
  "Question": [
    {
      "name": "www.google.com.",
      "type": 65
    }
  ],
  "Answer": [
    {
      "name": "www.google.com.",
      "type": 65,
      "TTL": 5820,
      "data": "1 . alpn=h2,h3"
    }
  ]
}
```


## HTTPS レコードが存在しない場合

先の `47-courier.push.apple.com` では CNAME が返ってきていたけど HTTPS レコードが存在しない場合は
CNAME レコードがあればそれを返してくるっぽい。

思いがけず HTTPS レコードについても親しくなった。


## 参考資料

- [RFC 8484 DNS Queries over HTTPS (DoH)](https://www.rfc-editor.org/info/rfc8484)
- [【図解】DNSのHTTPSレコード(type65)とECH(ESNI)の仕組み | SEの道標](https://milestone-of-se.nesuke.com/nw-basic/tls/dns-rr-type65-https-and-ech/)
- [DNSでHTTPS](https://dnsops.jp/event/20210625/11-yamaguchi.pdf) (pdf)
