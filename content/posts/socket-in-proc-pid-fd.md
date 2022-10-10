---
title: '/proc/PID/fd の socket の接続先を調べる方法'
date: Sat, 17 Oct 2020 16:08:21 +0000
draft: false
tags: ['Linux']
---

Linux で何か調査をしていて、lsof が使えない場合に /proc/{PID}/fd 配下でそのプロセスが開いているファイルやソケットを確認したりしますが、ソケットの場合、通信相手が分かりませんでした。私は。でも知ってしまったのですその方法を。（数ヶ月前に）

ということで次回以降のためにメモです。

```
# ls -l /proc/5322/fd
total 0
lr-x------. 1 root root 64 Oct 17 15:23 0 -> /dev/null
lrwx------. 1 root root 64 Oct 17 15:23 1 -> /dev/null
lrwx------. 1 root root 64 Oct 17 15:23 2 -> /dev/null
lrwx------. 1 root root 64 Oct 17 15:23 3 -> socket:[**40495282**]
lrwx------. 1 root root 64 Oct 17 15:23 4 -> socket:[40496301]
lrwx------. 1 root root 64 Oct 17 15:23 5 -> /dev/ptmx
l-wx------. 1 root root 64 Oct 17 15:23 6 -> /run/systemd/sessions/7567.ref
lrwx------. 1 root root 64 Oct 17 15:23 7 -> socket:[40495333]
```

fd 配下の symbolic link 先の socket の後ろにある番号で /proc/{PID}/net/tcp を grep すると次のようなテキストが見つかります

```
# head -n 1 /proc/5322/net/tcp; grep 40495282 /proc/5322/net/tcp
  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode                                                     
   9: 0200000A:0016 7100CBEA:C6CE 01 00000000:00000000 02:00098690 00000000     0        0 **40495282** 2 ffff9fd048647800 21 4 1 10 35
```

この local\_address, rem\_address がそれぞれ ipaddress:port を表しています。IP アドレスは 2 オクテットづつに分割して 16 進数を 10 進数にして順序を逆にしてドットでつなげれば見慣れた形式になります。

```
$ printf "%d.%d.%d.%d\n" 0x0a 0x00 0x00 0x02
10.0.0.2
$ printf "%d.%d.%d.%d\n" 0xEA 0xCB 0x00 0x71
234.203.0.113
```

ポート番号

```
$ printf "%d\n" 0x0016
22
$ printf "%d\n" 0xC6CE
50894
```

[gist.github.com/jkstill/5095725](https://gist.github.com/jkstill/5095725) にファイルの中身の説明があります。st の tcp state は [tcp\_states.h](https://elixir.bootlin.com/linux/v4.14.42/source/include/net/tcp_states.h) にありまして 01 は ESTABLISHED です。

socket は tcp に限らないため grep は /proc/{PID}/net/\* を対象にすると良いかもしれません。tcp6 かもしれないし unix かもしれない。unix domain socket ってどうやって相手を探すんだろうな？

これを知るきっかけは「[Why Fluentd stopped to send logs to ElasticSearch on Kubernetes (Related To SSL)](https://medium.com/uckey/why-fluentd-stopped-to-send-logs-to-elasticsearch-on-kubernetes-related-to-ssl-4ec1671b9ced)」でした。ありがとうございます。 m(\_ \_)m
