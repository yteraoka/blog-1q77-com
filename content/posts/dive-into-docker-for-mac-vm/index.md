---
title: 'Docker Desktop for Mac で docker 用 VM の中に入る'
date: Sat, 14 Mar 2020 11:26:48 +0000
draft: false
tags: ['Docker', 'macOS']
---

[Docker for Mac で、moby linux にアクセスする | Developers.IO](https://dev.classmethod.jp/server-side/docker-server-side/access-moby-linux-with-docker-for-mac/) を参考にさせていただきました。

mac で Docker を動かしてる hyperkit vm の中を覗いてみたいなと思い、ググったら上記の記事が見つかりましたが、私の今の環境では Path が変わってましたので、そのメモです。

[Docker Desktop](https://docs.docker.com/docker-for-mac/) のバージョンは「docker desktop community の 2.2.0.3 (42716)」でした。

{{< figure src="docker-desktop-2.2.0.3.png" >}}

```
$ screen ~/Library/Containers/com.docker.docker/Data/vms/0/tty
```

切断は `Ctrl-a k`
