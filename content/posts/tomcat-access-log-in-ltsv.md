---
title: 'Tomcat のアクセスログを LTSV で出力する'
date: Tue, 08 Mar 2016 15:19:55 +0000
draft: false
tags: ['Java', 'LTSV', 'Tomcat']
---

Tomcat はたしか 7 から AccessLog Valve がデフォルトで有効になっていますがそのフォーマットは Apache httpd の common に近いものです。これを今時の LTSV にする方法をメモ。

これがデフォルト設定

```
<!-- Access log processes all example.
     Documentation at: /docs/config/valve.html
     Note: The pattern used is equivalent to using pattern="common" -->
<Valve className="org.apache.catalina.valves.AccessLogValve" directory="logs"
       prefix="localhost_access_log." suffix=".txt"
       pattern="%h %l %u %t &quot;%r&quot; %s %b" />
```

`pattern` を書き換えれば良いわけですが、server.xml は XML なので TAB は `&#9;` とします。普通に TAB のコードを入れてもスペースになってしまいますし、`\t` も使えません。Apache や nginx の用に改行を入れて見やすくすることもできなっぽい。

```
pattern="host:%h&#9;time:%{yyyy-MM-dd hh:mm:ss}t&#9;ident:%l&#9;user:%u&#9;method:%m&#9;uri:%U%q&#9;protocol:%H&#9;status:%s&#9;size:%B&#9;referer:%{referer}i&#9;ua:%{user-agent}i&#9;msec:%D&#9;thread:%I"
```

で次のように出力されます

```
host:127.0.0.1	time:2016-03-08 11:57:33	ident:-	user:-	method:GET	uri:/favicon.ico	protocol:HTTP/1.1	status:200	size:21630	referer:http://localhost:8080/	ua:Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.75 Safari/537.36	msec:3	thread:http-bio-8080-exec-9
```

TAB を改行にして見やすくするとこんな内容

```
host:127.0.0.1
time:2016-03-08 11:57:33
ident:-
user:-
method:GET
uri:/favicon.ico
protocol:HTTP/1.1
status:200
size:21630
referer:http://localhost:8080/
ua:Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.75 Safari/537.36
msec:3
thread:http-bio-8080-exec-9
```

リクエスト時刻は `%{xxx}t` で指定します。`xxx` 部分は SimpleDateFormat になります。`time:%{yyyy-MM-dd'T'HH:mm:ss.SSSZ}t` と指定すれば `time:2016-03-09T00:13:25.991+0900` のように出力されます。

[http://tomcat.apache.org/tomcat-7.0-doc/config/valve.html#Access\_Log\_Valve](http://tomcat.apache.org/tomcat-7.0-doc/config/valve.html#Access_Log_Valve)

Ubuntu への Java のインストール方法はこちらを参照  
[How To Manually Install Oracle Java on a Debian or Ubuntu VPS](https://www.digitalocean.com/community/tutorials/how-to-manually-install-oracle-java-on-a-debian-or-ubuntu-vps)
