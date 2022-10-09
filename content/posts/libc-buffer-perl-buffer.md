---
title: 'libc の buffer と perl の buffer'
date: Fri, 01 Feb 2013 15:01:04 +0000
draft: false
tags: ['Linux', 'Perl', 'libc']
---

libc の buffer と perl の buffer は違うんだよという話を聞いたのでちょい調べてみた。 libc の buffer は grep を pipe で複数つなぐとなかなか表示されないやつ

```
$ while : ; do echo hoge; sleep 1; done | grep hoge
```

↑これはすぐに hoge が表示されますが

```
$ while : ; do echo hoge; sleep 1; done | grep hoge | grep hoge
```

↑こっちはずーっと待ってないと出力されません。出力先が端末でない場合、fwrite とかは buffering されるんですね。すぐに出力したい場合は次のように

```
$ while : ; do echo hoge; sleep 1; done | grep --line-buffered hoge | grep hoge
```

"--line-buffered" オプションをつけることで、毎行 fflush() が実行されてすぐさま出力されます。もうひとつ

```
$ while : ; do echo hoge; sleep 1; done | stdbuf -o0 grep hoge | grep hoge
```

と、stdbuf で LD\_PRELOAD を使って buffer をコントロールするという方法もあるようです。([How to fix stdio buffering](http://www.perkin.org.uk/posts/how-to-fix-stdio-buffering.html)) で、Perl もこんな仕組みで buffering されてるんだろうと思ってたら違うんですね。 [7.12. Flushing Output](http://docstore.mik.ua/orelly/perl/cookbook/ch07_13.htm)

```
$ perl -e 'while (1) { print "hoge\n"; sleep 1; }' | grep hoge
$ stdbuf -o0 perl -e 'while (1) { print "hoge\n"; sleep 1; }' | grep hoge
```

このどちらもすぐには出力されません。 次のようにするしかないようです。(IO::Handle 使っても良い)

```
$ perl -e '$|=1; while (1) { print "hoge\n"; sleep 1; }' | grep hoge
```

なるほどねぇ。

awk には fflush() っていう関数があって、sed には --unbuffered というオプションがあるらしい。

[grep, awk, sed でバッファしない方法](http://www.techscore.com/blog/2012/12/06/grep-awk-sed-%E3%81%A7%E3%83%90%E3%83%83%E3%83%95%E3%82%A1%E3%81%97%E3%81%AA%E3%81%84%E6%96%B9%E6%B3%95/)
