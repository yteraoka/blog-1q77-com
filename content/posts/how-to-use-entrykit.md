---
title: 'Entrykit の使い方'
date: Wed, 31 Aug 2016 15:49:59 +0000
draft: false
tags: ['Docker', 'Docker', 'Entrykit']
---

Docker コンテナで何かを実行する場合に便利なのが [Entrykit](https://github.com/progrium/entrykit) 前に使い方を調べたはずなのに忘れてしまったので再度まとめてメモっておく インストールは [release ページ](https://github.com/progrium/entrykit/releases)から最新版をダウンロードし /bin/entrykit に設置する その後 entrykit --symlink で symlink をはる、entrykit はどの名前で実行されたかによって動作が変わります

```
# /bin/entrykit --symlink
Creating symlink /bin/entrykit ...
Creating symlink /bin/codep ...
Creating symlink /bin/prehook ...
Creating symlink /bin/render ...
Creating symlink /bin/switch ...
```

### codep

複数のプロセスを同時に起動させます

```
codep "sleep 100" "sleep 200" "nginx" "nginx -v"
```

とすると 4 つのプロセスが実行されるかと思いきゃ "sleep 200" と "nginx -v" しか実行されません。同じ実行ファイルのプロセスは後で指定したものだけが実行されるようです

```
codep "sleep 100" "/bin/echo test" "nginx -v"
```

であれば 3 つとも実行されます ドキュメントにあるように

```
ENTRYPOINT ["codep", \
    "/bin/config-reloader", \
    "/usr/sbin/nginx" ]
```

と書けば /bin/config-reloader と /usr/sbin/nginx が実行されます、どちらか一方でも終了すればコンテナごと停止します

```
ENTRYPOINT ["codep", \
    "/bin/config-reloader", \
    "/usr/sbin/nginx", \
    "sleep 100" ]
```

とすれば100秒で sleep が終了したタイミングでコンテナが停止します

### render

render は [sigil](https://github.com/gliderlabs/sigil) という template エンジンを使ってファイルを生成します

```
render /etc/nginx.conf -- /usr/sbin/nginx
```

とすれば /etc/nginx.conf.tmpl から /etc/nginx.conf を生成した後に nginx を起動させます

```
ENTRYPOINT ["render", "/etc/nginx.conf", \
            "--", "/usr/sbin/nginx", "-g", "daemon off;"]
```

### switch

```
switch shell=/bin/bash ps=/bin/ps "version=nginx -v" -- /usr/sbin/nginx -g 'daemon off;' version
```

とすれば nginx -v が実行される。末尾の version を外せば -- 以降のコマンドが実行される version の代わりに shell とすれば bash が起動する つまり

```
ENTRYPOINT ["switch", \
              "shell=/bin/bash", \
              "ps=/bin/ps", \
              "version=nginx -v", \
            "--", \
            "/usr/sbin/nginx", "-g", "daemon off;" ]
```

としておけば

```
docker run -it xxx version
```

とすれば nginx -v が実行され、

```
docker run -it xxx shell
```

とすれば bash が実行されます

```
docker run -it xxx
```

とすれば /usr/sbin/nginx -g 'daemon off;' が実行されます name=command として指定されていないものを引数に渡すとこの後ろにつけて実行されます

```
docker run -it xxx -V
```

とすれば /usr/sbin/nginx -g 'daemon off;' -V が実行されるのでバージョン情報やビルド情報が表示されます

### prehook

prehook で指定したコマンドを実行した後にアプリなどを起動させます

```
ENTRYPOINT ["prehook", "nginx -V", "--", "/usr/sbin/nginx", "-c", "/nginx.conf"]
```

"--" の後はリストで引数を渡しますが prehook コマンドをリストで渡すことはできません

```
ENTRYPOINT ["prehook", "nginx", "-V", "--", "/usr/sbin/nginx"]
```

また、prehook で指定したコマンドは正常終了しないと後のコマンドを実行しません よって、次のようにすると nginx は起動しません

```
ENTRYPOINT ["prehook", "/bin/false", "--", "/usr/sbin/nginx"]
```

### 合わせ技

これまでに出てきたものを組み合わせることが可能です

```
ENTRYPOINT [ \
  "switch", \
    "shell=/bin/sh", \
    "version=nginx -v", "--", \
  "render", "/demo/nginx.conf", "--", \
  "prehook", "nginx -V", "--", \
  "codep", \
    "/bin/reloader 3", \
    "/usr/sbin/nginx -c /demo/nginx.conf" ]
```

### 環境変数で指定する

次のように環境変数で指定することも可能なので Dockerfile に書いたものを実行時に上書きすることも可能です

```
ENV SWITCH_SHELL=/bin/sh
ENV RENDER_CONFIG=/etc/nginx.conf
ENV CODEP_NGINX=nginx -g
ENV CODEP_CONFD=confd
ENV PREHOOK_HTPASSWD=htpasswd -bc /etc/nginx/htpasswd $HTPASSWD

ENTRYPOINT ["entrykit -e"]
```

後でテンプレート機能のところをもうちょい掘り下げよう
