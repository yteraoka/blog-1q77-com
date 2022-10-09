---
title: 'fluent-plugin-dbi 書いた'
date: Sun, 17 Feb 2013 15:50:20 +0000
draft: false
tags: ['MySQL', 'PostgreSQL', 'dbi', 'fluentd', 'Ruby']
---

fluentd で DB に書き込むために DBI を使って PostgreSQL でも MySQL にでも入れられるようにしてみました。PostgreSQL なら dbd-pg を、MySQL なら dbd-mysql が必要です。 [https://github.com/yteraoka/fluent-plugin-dbi](https://github.com/yteraoka/fluent-plugin-dbi)

```
 type dbi
  #dsn DBI:Pg:dbname:dbhost
  dsn DBI:Mysql:dbname:dbhost
  db_user username
  db_pass password
  keys host,time_m,method,uri,protocol,status
  query insert into access_log (host, time, method, uri, protocol, status) values (?, ?, ?, ?, ?, ?) 
```

Query は自動生成ではないので、任意の処理を実行できます。 keys のカンマ区切りの順に「?」のプレースホルダに入れます。 time\_m っていうのは Apache 2.4 だと %{msec\_frac}t という LogFormat マクロでミリ秒まで出せるので、次のように指定して DB にミリ秒精度で入れられます。

```
time_m:%{%Y-%m-%d %H:%M:%S}t.%{msec_frac}t
```

%{usec\_frac}t だとマイクロ秒でも出せますが、DB にマイクロ秒精度で入らないので msec で。 [mod\_log\_config - Apache HTTP Server](http://httpd.apache.org/docs/2.4/mod/mod_log_config.html#formats)

```
fluent-gem fluent-plugin-dbi
```

で。
