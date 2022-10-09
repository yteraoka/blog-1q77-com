---
title: 'Redis の内部を探ってみる (save)'
date: Thu, 27 Dec 2012 15:09:17 +0000
draft: false
tags: ['Linux', 'Redis', 'redis']
---

Redis の versin up ついでに内部を軽く探ってみる 対象の version は 2.6.7 Redis を起動すると `WARNING overcommit_memory is set to 0! Background save may fail under low memory condition. To fix this issue add 'vm.overcommit_memory = 1' to /etc/sysctl.conf and then reboot or run the command 'sysctl vm.overcommit_memory=1' for this to take effect.` と表示されることから、save って fork した子供がコピーされたメモリを dump してるのかぁと想像し、実際にコードを見てみることにした。 rdb.c の rdbSaveBackground() の中で fork して書き出している。 fork した子供を看取るのは redis.c の serverCron() がずっと looop で動いていて、いろんな処理をしてる中の一つの仕事で rdb.c の backgroundSaveDoneHandler()。rdbSaveBackground() を実行するのも serverCron() の中。 ということで、save (dump) 処理でレスポンスが落ちるとしたらそれは save 中に更新が多くてメモリの Copy on write が沢山発生する場合なんだろうな。 次回は aof (AppendOnlyFile) を調べてみる。