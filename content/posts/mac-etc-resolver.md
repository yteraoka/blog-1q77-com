---
title: "/etc/hosts で wildcard や CNAME 対応させたい"
date: 2022-10-30T23:56:34+09:00
draft: false
tags: ['DNS', 'macOS']
---

macOS での話です。(macOS Ventura でも機能することを確認しました)

`/etc/hosts` で `203.0.113.2 *.example.com` みたいに wildcard に対応させたいことが稀にあります。
また、AWS の Application Load Balancer のように IP アドレスの固定されないものに独自ドメインを割り当てて、実際の切り替え前に手元からアクセスしたいこととか。

残念ながら hosts ではできないのですが、mac には `/etc/resolver` というディレクトリに配置するファイルでドメイン単位で DNS サーバーを指定可能な機能があります。([telepresence](/tags/telepresence/) を調べていて知った機能です) (`man 5 resolver` でマニュアルが確認できます)

ということで `/etc/resolver/example.com` というファイルに次の2行を書いておくと example.com の場合は 127.0.0.1 の 8053/udp に転送してくれます。(tcp にする方法は見つけられなかった)

```
# /etc/resolver/example.com
nameserver 127.0.0.1
port 8053
```

8053/udp port で listen する DNS サーバーとして dnsmasq を使います。
Docker で起動させたいところですが、Docker on Lima では UDP の転送ができなかったので Homebrew で dnsmasq をインストールします。

```
brew install dnsmasq
```

dnsmasq を foreground で起動させる。設定ファイルを用意しなくてもコマンドラインオプションでレコードも指定できます。

```
$(brew --prefix)/opt/dnsmasq/sbin/dnsmasq \
  --port=8053 --keep-in-foreground --no-daemon --no-hosts --log-queries \
  --address=/example.com/203.0.113.2 \
  --address=/example.com/203.0.113.129 \
  --host-record=example.com,198.51.100.111 \
  --host-record=host.example.com,198.51.100.222 \
  --cname=alias.example.com,host.example.com \
  --cname=alias2.example.com,www.google.com \
```

これで `ping hogehoge.example.com` とすると `203.0.113.129` に ping を送ろうとします。(dig とか host コマンドでは `/etc/resolver` は参照されません)

`curl -k https://alias2.example.com/` すると google の IP アドレスに `alias2.example.com` としてアクセスに行きます。

`--address` はサブドメインも含めて一致したら A レコードを返します。同じドメインで複数回指定すれば複数のアドレスを返すことができますが、毎回同じ順序で返します。ラウンドロビンになったりはしない。

`--host-record` はドメインの完全一致で A レコードを返します。`--address` よりも優先されます。

`--cname` は CNAME を返します。

上には書きませんでしたが、 `--dns-rr=<name>,<RR-number>,[<data>]` というものもあり、任意の DNS レスポンスを返すことができます。HTTPS レコードや CAA などにも使えます。

が、設定はちょっと面倒です。

```python
import dns.rdata
import binascii

name = "cname.example.com"
rclass = dns.rdataclass.IN
rtype = dns.rdatatype.CAA
rdata = 'www.google.com.'

rd = dns.rdata.from_text(rclass, rtype, rdata)
print("--dns-rr={},{},{}".format(name, dns.rdatatype.to_text(rtype),
                                 bytes.decode(binascii.hexlify(rd.to_wire()))))
```

これで出力される次のような値を引数で指定します。

```
--dns-rr=cname.example.com,5,0377777706676f6f676c6503636f6d00
```
