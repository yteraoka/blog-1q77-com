---
title: 'Nginx + mod_lua で認証フィルタを作ってみる'
date: Mon, 07 Oct 2013 15:16:43 +0000
draft: false
tags: ['nginx', 'lua']
---

画像サーバーなどでログインチェックを Apache + mod\_perl で実装していましたが、古代のクライアントへの対応はもう不要だろうということで、mod\_perl やめたいし、もっとシンプルな実装にできそうだから nginx + mod\_lua を試してみようとやってみました。

キャッシュとして memcached を使いたかったので [https://github.com/agentzh/lua-resty-memcached](https://github.com/agentzh/lua-resty-memcached) も込で全部入れてくれる [OpenResty](http://openresty.org/) をインストールしました。

### OpenResty のインストール

```
$ tar xvf ngx\_openresty-1.4.2.9.tar.gz
$ cd ngx\_openresty-1.4.2.9
$ ./configure --prefix=/opt/ngx\_openresty-1.4.2.9 --with-luagit
$ make
$ sudo make install

```

Lua モジュールについては [HttpLuaModule ( http://wiki.nginx.org/HttpLuaModule )](http://wiki.nginx.org/HttpLuaModule) にドキュメントがあります。Lua でコンテンツを返す場合は [content\_by\_lua](http://wiki.nginx.org/HttpLuaModule#content_by_lua), [content\_by\_lua\_file](http://wiki.nginx.org/HttpLuaModule#content_by_lua_file) を使いますが、認証処理を行うには [access\_by\_lua](http://wiki.nginx.org/HttpLuaModule#access_by_lua), [access\_by\_lua\_file](http://wiki.nginx.org/HttpLuaModule#access_by_lua_file) を使います。他にも header\_filter\_by... や rewrite\_by..., body\_filter\_by... があります。 \*\_file の方は Lua を別ファイルとして読み込みます、compile 済みのファイルを指定することも可能です。 \*\_file でない方は Nginx の設定ファイルに直接コードを書きます。

今回は認証フィルタの話なので access\_by\_lua\* についてのみ。

### 簡単な例

例えば、IE からのアクセスを拒否したい（403 Forbidden を返したい）という場合は次のように書けます（これだけなら Lua 不要ですよね、たぶん。Nginxはまだ詳しく知らない）。途中で ngx.exit せずに最後までいくか、途中で ngx.exit(ngx.OK) で終了すればアクセスは許可されます。

```
location / {
    access\_by\_lua '
        ngx.log(ngx.DEBUG, "User-Agent: ", ngx.var.http\_user\_agent)
        if string.match(ngx.var.http\_user\_agent, "MSIE") then
            ngx.exit(ngx.HTTP\_FORBIDDEN)
        end
    ';
}

```

### 別サーバーへ問い合わせる

ログイン済みかどうかを確認するためには cookie を確認すると思います。LuaModule で Foo という名前の cookie の値を取得するには ngx.var.cookie\_Foo とします。変数に入れるには

```
local cookie\_value = ngx.var.cookie\_Foo

```

とします。Cookie 名が変数に入っている場合は次のようにすることで取り出せます。

```
local cookie\_name = "Foo"
local cookie\_value = ngx.var\["cookie\_" .. cookie\_name\]

```

取り出した cookie の値からそのリクエストが有効かどうかを判定するために、別のサーバーに問い合わせる必要があります。memcached に入ってるなら直接そのサーバーに問い合わせるという方法もありますね。でもアプリで Consistent Hashing とかしてると困りますね。[twemproxy](https://github.com/twitter/twemproxy) 使ってれば大丈夫ですかね。 でも今回は Web サーバーに GET で問い合わせる方法を説明します。

ngx.location.capture() を使うことで、別の URI へリクエストを出すことができます。が、ngx.location.capture("http://example.com/auth?session=XXXX") などと直接別のサーバーを指定することはできません。 これをどうするかというと [lua-nginx-module の紹介 ならびに Nginx+Lua+Redisによる動的なリバースプロキシの実装案 - hibomaのはてなダイアリー](http://d.hatena.ne.jp/hiboma/20120205/1328448746) で紹介されているように

```
upstream \_session\_server {
    server session.example.com:80;
}
server {
    listen 80;
    server\_name localhost;
    location / {
        access\_by\_lua '
            local sessid = ngx.var.cookir\_SESSION\_COOKIE
            if sessid then
                local res = ngx.location.capture("/\_auth/session?sessid=" .. sessid)
                if res.status == 200 and string.match(res.body, "OK") then
                    ngx.exit(ngx.OK)
                end
            end
            ngx.exit(ngx.HTTP\_FORBIDDEN)            
        ';
    }
    location /\_auth {
        internal;
        rewrite ^/\[^/\]\*/(.\*) /$1 break;
        proxy\_pass http://\_session\_server;
    }
}

```

てな感じで、/\_auth などを経由して proxy させることができます。internal 指定しておくことで直接ブラウザからアクセスされないようにできます。ngx.location.capture() は subrequest として /\_auth へアクセスするため、これへは access\_by\_lua が適用されません。

/ へアクセスしたら2回の問い合わせが発生してなんだろう？って悩んだが / でチェックした後に、内部的に /index.html へアクセスし直すのでした。

Nginx ほぼ初めてだから location / で access\_by\_lua 設定したら、他の location で認証が効かなくてハマった。全体に適用するなら location の外に設定すべきですね。

### memcached を使う

毎回別のサーバーに問い合わせるのはよろしくないので、ローカルの memcached にキャッシュさせたいと思います。/aaa へのアクセスに memcached からの GET aaa の結果をそのまま返すという利用法であれば [MemcachdModule](http://wiki.nginx.org/HttpMemcachedModule) でできるようですが、今回の用途では [https://github.com/agentzh/lua-resty-memcached](https://github.com/agentzh/lua-resty-memcached) の方がマッチしそうでした。

使い方はドキュメントに書いてあるとおりで、

```
local memcached = require "resty.memcached"
local memc, err = memcached:new()
memc:set\_timeout(1000) -- 1 sec
memc:connect("127.0.0.1", 11211)
memc:set("dog", 32)
local res, flags, err = memc:get("dog")
memc:set\_keepalive(10000, 100)
-- memc:close()

```

な感じです、エラー処理を端折ってますが、使うときにはちゃんと書きましょう。 set() は3番目の引数に expire (秒) を、4番目に flag を指定できます。 close() の代わりに set\_keepalive() を使うことでその connection を connection pool に入れることができます。毎度毎度接続・切断を繰り返すのはよろしくないので pool しましょう。1番目の引数が idle timeout (ミリ秒) で2番目の引数が pool の最大値です。

### コンパイル

Lua のコンパイルは OpenResty で一緒にインストールされた luajit を使います。

```
$ luajit/bin/luajit -b auth-filter.lua auth-filter.luac

```

この .luac を access\_by\_lua\_file で指定することが可能です。

### Lua の文法

ちょっとだけ。今のところ Nginx でサポートされているのは Lua 5.1 のようです。 [http://www.lua.org/manual/5.1/manual.html](http://www.lua.org/manual/5.1/manual.html)

コメントは SQL と同じかな？「--」から行末までがコメントとなります。

配列は PHP と似ていて、連想配列だけみたいです。table と呼ぶみたいです。添字は0ではなく1から始まります。#table で要素数が得られます、ただし、欠番や値がnullの要素があると、その前まででの数が返ります。ipairs(), pairs() というイテレータがあります。ipairs() が配列用のようです。1から#table まで loop させられます。pairs() は key と value が返ります。ipairs では欠番以降を処理できませんが、pairs() であれば全部処理できます。

文字列連結は「..」です。

変数のスコープはデフォルトが Global なので、Perl の「my」のように「local」で宣言しましょう。

if, for, while, function の終了は end です。loop から抜けるのは break で、function が値を戻すのは return.

```
local t = { "A", "B" }
table.insert(t, "C")
table.remove(t, 2)
table.concat(t, ",")
for i, v in ipairs(t) do
    ngx.log(ngx.DEBUG, string.format("\[%d\]: %s", i, v))
end
local i = 1
while i <= #t do
    ngx.log(ngx.DEBUG, string.format("\[%d\]: %s", i, t\[i\]))
    i = i + 1 -- += や ++ は無い
end
local t = { a="A", b="B", c="C" }
for k, v in pairs(t) do -- 順序は保証されない
    ngx.log(ngx.DEBUG, k, ": ", v)
    if k == "A" then
        ngx.log(ngx.DEBUG, "not A")
    else
        ngx.log(ngx.DEBUG, "not A")
    end
end

```

それでは良い Lua 生活を〜〜
