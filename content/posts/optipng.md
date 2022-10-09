---
title: 'PNG を最適化'
date: Sat, 19 Oct 2013 02:43:23 +0000
draft: false
tags: ['Linux', 'KVM', 'pagespeed', 'PNG', 'QEMU']
---

[Google PageSpeed Insights](https://developers.google.com/speed/pagespeed/insights/) で画像ファイルはもっと小さくなるよって注意されるので [OptiPNG](http://optipng.sourceforge.net/) を試してみた。 CentOS で EPEL にパッケージがあったのでインストールはこれだけ。

```
$ sudo yum -y install optipng
```

とりあえず実行してみる

```
$ optipng
OptiPNG 0.6.4: Advanced PNG optimizer.
Copyright (C) 2001-2010 Cosmin Truta.

Synopsis:
    optipng [options] files ...
Files:
    Image files of type: PNG, BMP, GIF, PNM or TIFF
Basic options:
    -?, -h, -help	show the extended help
    -o optimization level (0-7)		default 2
    -v			verbose mode / show copyright and version info
Examples:
    optipng file.png			(default speed)
    optipng -o5 file.png		(moderately slow)
    optipng -o7 file.png		(very slow)
Type "optipng -h" for extended help. 
```

Help を確認

```
$ optipng -h
OptiPNG 0.6.4: Advanced PNG optimizer.
Copyright (C) 2001-2010 Cosmin Truta.

Synopsis:
    optipng [options] files ...
Files:
    Image files of type: PNG, BMP, GIF, PNM or TIFF
Basic options:
    -?, -h, -help	show this help
    -o optimization level (0-7)		default 2
    -v			verbose mode / show copyright and version info
General options:
    -fix		enable error recovery
    -force		enforce writing of a new output file
    -keep		keep a backup of the modified files
    -preserve		preserve file attributes if possible
    -quiet		quiet mode
    -simulate		simulation mode
    -snip		cut one image out of multi-image or animation files
    -out write output file to -dir write output file(s) to -log log messages to --			stop option switch parsing
Optimization options:
    -f  PNG delta filters (0-5)			default 0,5
    -i  PNG interlace type (0-1)		default 
    -zc zlib compression levels (1-9)		default 9
    -zm zlib memory levels (1-9)		default 8
    -zs zlib compression strategies (0-3)	default 0-3
    -zw zlib window size (32k,16k,8k,4k,2k,1k,512,256)
    -full		produce a full report on IDAT (might reduce speed)
    -nb			no bit depth reduction
    -nc			no color type reduction
    -np			no palette reduction
    -nx			no reductions
    -nz			no IDAT recoding
Optimization details:
    The optimization level presets
        -o0  <=>  -o1 -nx -nz
        -o1  <=>  [use the libpng heuristics]	(1 trial)
        -o2  <=>  -zc9 -zm8 -zs0-3 -f0,5	(8 trials)
        -o3  <=>  -zc9 -zm8-9 -zs0-3 -f0,5	(16 trials)
        -o4  <=>  -zc9 -zm8 -zs0-3 -f0-5	(24 trials)
        -o5  <=>  -zc9 -zm8-9 -zs0-3 -f0-5	(48 trials)
        -o6  <=>  -zc1-9 -zm8 -zs0-3 -f0-5	(120 trials)
        -o7  <=>  -zc1-9 -zm8-9 -zs0-3 -f0-5	(240 trials)
    The libpng heuristics
        -o1  <=>  -zc9 -zm8 -zs0 -f0		(if PLTE is present)
        -o1  <=>  -zc9 -zm8 -zs1 -f5		(if PLTE is not present)
    The most exhaustive search (not generally recommended)
      [no preset] -zc1-9 -zm1-9 -zs0-3 -f0-5	(1080 trials)
Examples:
    optipng file.png				(default speed)
    optipng -o5 file.png			(moderately slow)
    optipng -o7 file.png			(very slow)
    optipng -i1 -o7 -v -full -sim experiment.png 
```

なんかいろいろオプションはあるみたいだけど、とりあえず optimization level は max で全部（数は少ない）最適化してみる

```
$ find . -type f -name '*.png' -print0 | xargs -0 optipng -o7
```

**very slow** って書いてあるだけあったかなり時間がかかりますね。対した画像じゃないのに。 試したのはさくらのVPS 2Gプランのサーバーです。 /proc/cpuinfo 見ると Xeon E5645 とありますね。そんなに悪くない。どれだけ Over commit されてるかわかりませんけど。 うちの KVM は Guest からだと QEMU Virtual CPU って表示されるんだけどなぁって思ってググったら -cpu host なんていうオプションがあったんですね。試してみよう。 [サーバ屋日記: kvmによる仮想マシン"-cpu host"オプションで性能向上する場合がある](http://ktaka.blog.clustcom.com/2013/05/kvm-cpu.html) /etc/libvirt/qemu/xxx.xml に次の1行を追加すれば良いようだ（2行に分割されるけど）。
