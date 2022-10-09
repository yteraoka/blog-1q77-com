---
title: 'TP-Link Deco の Parental Control で yum が block されてハマる'
date: Sun, 31 May 2020 01:46:15 +0000
draft: false
tags: ['Home']
---

[過去の投稿](/2018/08/deco-m5/)の通り、我が家の無線LANには TP-Link の Deco M5 を使用しており、[TP-Link HomeCare](https://www.tp-link.com/jp/homecare/) も有効にしてあります。

Mac book 内の Vagrant で起動した CentOS から yum update ができずにハマったのですが、調べたところ HomeCare の Parental Control が原因でした。誰かの役に立てば。

```
$ sudo yum check-update
Loaded plugins: fastestmirror
Determining fastest mirrors


 One of the configured repositories failed (Unknown),
 and yum doesn't have enough cached data to continue. At this point the only
 safe thing yum can do is fail. There are a few ways to work "fix" this:

     1. Contact the upstream for the repository and get them to fix the problem.

     2. Reconfigure the baseurl/etc. for the repository, to point to a working
        upstream. This is most often useful if you are using a newer
        distribution release than is supported by the repository (and the
        packages for the previous distribution release still work).

     3. Run the command with the repository temporarily disabled
            yum --disablerepo=<repoid> ...

     4. Disable the repository permanently, so yum won't use it by default. Yum
        will then just ignore the repository until you permanently enable it
        again or use --enablerepo for temporary usage:

            yum-config-manager --disable <repoid>
        or
            subscription-manager repos --disable=<repoid>

     5. Configure the failing repository to be skipped, if it is unavailable.
        Note that yum will try to contact the repo. when it runs most commands,
        so will have to try and fail each time (and thus. yum will be be much
        slower). If it is a very temporary problem though, this is often a nice
        compromise:

            yum-config-manager --save --setopt=.skip_if_unavailable=true

Cannot find a valid baseurl for repo: base/7/x86_64 
```

`base/7/x86_64` の `baseurl` が見つからない？

`/etc/yum.repos.d/CentOS-Base.repo` の mirrorlist をやめて baseurl を指定するようにしてみたら...

```
$ sudo yum check-update
Loaded plugins: fastestmirror
Loading mirror speeds from cached hostfile
base                                                                                                                                                                                                    |  176 B  00:00:00     
!http://ftp.jaist.ac.jp/pub/Linux/CentOS/7.8.2003/os/x86_64/repodata/repomd.xml: [Errno -1] Error importing repomd.xml for base: Damaged repomd.xml file
Trying other mirror.


 One of the configured repositories failed (CentOS-7 - Base),
 and yum doesn't have enough cached data to continue. At this point the only
 safe thing yum can do is fail. There are a few ways to work "fix" this:

     1. Contact the upstream for the repository and get them to fix the problem.

     2. Reconfigure the baseurl/etc. for the repository, to point to a working
        upstream. This is most often useful if you are using a newer
        distribution release than is supported by the repository (and the
        packages for the previous distribution release still work).

     3. Run the command with the repository temporarily disabled
            yum --disablerepo=base ...

     4. Disable the repository permanently, so yum won't use it by default. Yum
        will then just ignore the repository until you permanently enable it
        again or use --enablerepo for temporary usage:

            yum-config-manager --disable base
        or
            subscription-manager repos --disable=base

     5. Configure the failing repository to be skipped, if it is unavailable.
        Note that yum will try to contact the repo. when it runs most commands,
        so will have to try and fail each time (and thus. yum will be be much
        slower). If it is a very temporary problem though, this is often a nice
        compromise:

            yum-config-manager --save --setopt=base.skip_if_unavailable=true

failure: repodata/repomd.xml from base: [Errno 256] No more mirrors to try.
!http://ftp.jaist.ac.jp/pub/Linux/CentOS/7.8.2003/os/x86_64/repodata/repomd.xml: [Errno -1] Error importing repomd.xml for base: Damaged repomd.xml file
```

今度は `[Errno -1] Error importing repomd.xml for updates: Damaged repomd.xml file` で repomd.xml が壊れてるとか言われる...

しかし、curl でアクセスしてみても、ブラウザからアクセスしても問題なくアクセスできる

わからん...

次に tcpdump で何が起きてるのかのぞいてみた。yum では https ではなく http が使われていたので `tcpdump -i eth0 -s 0 -A port 80` で http でのやりとりは容易に見ることができる。(MACアドレス部分は一部マスクした)

```
GET /pub/Linux/CentOS/7.8.2003/os/x86_64/repodata/repomd.xml HTTP/1.1
User-Agent: urlgrabber/3.10 yum/3.4.3
Host: ftp.jaist.ac.jp
Accept: */*

HTTP/1.1 200 OK
Server: Jetty/4.2.x (Windows XP/5.1 x86 java/1.6.0_17)
Content-Type: text/html
Content-Length: 176
Accept-Ranges: bytes

<html>
<head>
<meta HTTP-EQUIV="REFRESH" content="0; url=http://192.168.200.1:80/shn_blocking.html?app_cid=15&app_id=12&mac=F8FFC2******">
</head>
<body></body>
</html>

```

なんかルーターがブロックしてるっぽい URL へのリンクが見える。ブラウザでアクセスしてみると、

{{< figure src="tp-link-parental-control-capture.png" alt="ペアレンタルコントロール" >}}

* * *

Parental Control Restrictions  
  
Your access to this website is blocked.  
Classificatioin: Yum, Pay to Sur

* * *

は？いや、確かに **Pay to Surf (P2S)** をブロックするようには設定しましたよ。しかし、なんで Yum をブロックするわけ！？

でも curl やブラウザではアクセスできたじゃん？

どうやら **User-Agent** を見てブロックしているようです。`urlgrabber/` と `yum/` の両方にマッチするとブロックされました。

しかたがないので Parental Control 設定を変更して回避しました。付いてきたから使ってるけどあまり意味がある感じもしないんですよねぇ。9.9.9.9 とか使いたいけど DAZN が見れなくなったりするからなあ。話題の 8GB メモリのラズパイ買って [Pi-hole](https://pi-hole.net/) でも動かそうかな。
