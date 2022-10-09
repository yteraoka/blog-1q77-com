---
title: 'HAProxy の X-Forwarded-For 実装の罠'
date: Thu, 27 Apr 2017 15:26:33 +0000
draft: false
tags: ['HAProxy']
---

ちゃんと公式ドキュメントを読めっていう話なのですが HAProxy にて X-Forwarded-For をセットするという `options forwardfor` 設定は通常期待される動作とは違います。ググって見つけた答えはちゃんと検証しましょう。

```
X-Forwarded-For: xxx.xxx.xxx.xxx
```

がすでにリクエストに入っていた場合、次のように HAProxy の動作するサーバーの IP アドレスがカンマ区切りで追加されることを期待しますが

```
X-Forwarded-For: xxx.xxx.xxx.xxx, yyy.yyy.yyy.yyy
```

実際には次のようにヘッダーの最後に新たに X-Forwarded-For ヘッダーが追加されます。

```
X-Forwarded-For: xxx.xxx.xxx.xxx
その他の Header
X-Forwarded-For: yyy.yyy.yyy.yyy
```

これを受け取ったサーバーがどのように扱うかは実装依存っぽいですね。 Rails 5.0.2 で確認すると

```
HTTP_X_FORWARDED_FOR:xxx.xxx.xxx.xxx, yyy.yyy.yyy.yyy
```

となりました。Flask 0.12.1 では最後の X-Forwarded-For だけになりました。HAProxy のドキュメントには同名ヘッダーを受け取ったサーバーは最後値を使うべきだと書いてあるから Flask の方が正しいのかな。 他のサーバーでどのように処理されるかどうかは不明。後で調べて追記予定。

* * *

[公式ドキュメントの option forwardfor 項](https://cbonte.github.io/haproxy-dconv/1.8/configuration.html#4-option%20forwardfor)

```
option forwardfor [ except ] [ header ] [ if-none ] 
```

という構文なので `except` で X-Forwarded-For を追加しない条件を指定したり、`header` でヘッダー名を X-Forwarded-For ではないものにしたり、`if-none` で X-Forwarded-For が存在しない場合にのみ追加するといった指定が可能です。
