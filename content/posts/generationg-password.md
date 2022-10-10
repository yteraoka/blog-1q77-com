---
title: 'bash でパスワード生成'
date: Tue, 24 Dec 2019 11:20:39 +0000
draft: false
tags: ['Bash']
---

ちょいちょいランダムな文字列が欲しくなるので Perl で書いたスクリプト使ってたのだけど Bash で出来そうだなということで書いてみたのだが (記号の有無オプションとか追加しても良い)

```bash
#!/bin/bash

CHARS='23456789abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ'
#CHARS='23456789abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ_-=+%#'

LEN=${1:-16}

i=0
while [ $i -le $LEN ] ; do
    pos=$(( $RANDOM % ${#CHARS} ))
    echo -n ${CHARS:$pos:1}
    i=$(( $i + 1 ))
done

echo
```

わざわざスクリプト書かなくても pwgen ってコマンドがあるらしい（そりゃそうだ）。apt や yum でも入るらしい。mac なら brew で。16文字を4個生成する例（`-B` は見分けづらい文字を除く、`-s` は厳密に random にする）

```
$ pwgen -Bs 16 4
CgoTwgbJTpw9nCsg zRpWKdboyY7yFhEF Ajn4RTVpPVxyWaEq Hos9XNJfAkJfhjbX
```

`/dev/random`, `/dev/urandom` から読み出して base64 とかもあるけど openssl コマンドでもできる

```
$ openssl rand -base64 32 | head -c 16
EfU893c//rqfnMJS

```
