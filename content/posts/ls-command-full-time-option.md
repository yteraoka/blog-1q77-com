---
title: 'ls コマンドで秒まで表示'
date: Fri, 07 Dec 2012 11:40:55 +0000
draft: false
tags: ['Linux']
---

ls コマンドでファイルの timesamp (mtime) を秒(もしくはより詳細)まで確認する方法です。 `ls -l` では分までです

```
$ date
Sat Sep  8 08:37:25 JST 2012
$ touch test
$ ls -l test
-rw-r--r-- 1 ytera users 0 Sep  8 08:37 test
```

そして、古いファイルだと日までしか表示されません。 2年前に変更して確認します

```
$ touch -t $(date -d "2 year ago" +%y%m%d%H%M) test
$ ls -l test
-rw-r--r-- 1 ytera users 0 Sep  8  2010 test
```

そこで `--full-time` オプションです。

```
$ ls -l --full-time test
-rw-r--r-- 1 ytera users 0 2010-09-08 08:39:00.000000000 +0900 test
```

`touch -t` で mtime を更新したため秒以下が 0 になっているので 再度更新して確認

```
$ touch test
$ ls -l --full-time test
-rw-r--r-- 1 ytera users 0 2012-09-08 08:43:01.410675831 +0900 test
```

atime も ctime も確認したい場合は `stat` コマンドです

```
$ stat test
  File: `test'
  Size: 0               Blocks: 0          IO Block: 4096   regular empty file
Device: fc03h/64515d    Inode: 2753833     Links: 1
Access: (0644/-rw-r--r--)  Uid: ( 1000/   ytera)   Gid: (  100/   users)
Access: 2012-09-08 08:43:01.410675831 +0900
Modify: 2012-09-08 08:43:01.410675831 +0900
Change: 2012-09-08 08:43:01.410675831 +0900
```

ext4 や ZFS などでは秒より細かな制度でタイムスタンプが保存されてます、ext2, ext3, ufs などでは秒までです。
