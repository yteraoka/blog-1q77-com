---
title: 'Tomcat 9 を HTTP/2 サーバーにする'
date: Wed, 17 Feb 2016 15:52:26 +0000
draft: false
tags: ['Java', 'TLS', 'Tomcat', 'HTTP2']
---

Tomcat 9 の server.xml を見ていたら次のような記述がありました。HTTP/2 をサポートしているようです。

すぐに使う予定はないけれども動作確認してみたのでメモ。
環境は CentOS 7 Let's Encrypt で証明書を用意してこの設定をアンコメントしてみました。が、これだけでは起動してくれませんでした。

```
17-Feb-2016 23:51:15.022 SEVERE [main] org.apache.catalina.core.StandardService.initInternal Failed to initialize connector [Connector[HTTP/1.1-8443]]
 org.apache.catalina.LifecycleException: Failed to initialize component [Connector[HTTP/1.1-8443]]
	at org.apache.catalina.util.LifecycleBase.init(LifecycleBase.java:112)
	at org.apache.catalina.core.StandardService.initInternal(StandardService.java:549)
	at org.apache.catalina.util.LifecycleBase.init(LifecycleBase.java:107)
	at org.apache.catalina.core.StandardServer.initInternal(StandardServer.java:855)
	at org.apache.catalina.util.LifecycleBase.init(LifecycleBase.java:107)
	at org.apache.catalina.startup.Catalina.load(Catalina.java:606)
	at org.apache.catalina.startup.Catalina.load(Catalina.java:629)
	at sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
	at sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
	at sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	at java.lang.reflect.Method.invoke(Method.java:497)
	at org.apache.catalina.startup.Bootstrap.load(Bootstrap.java:311)
	at org.apache.catalina.startup.Bootstrap.main(Bootstrap.java:494)
Caused by: org.apache.catalina.LifecycleException: The configured protocol [org.apache.coyote.http11.Http11AprProtocol] requires the APR/native library which is not available
	at org.apache.catalina.connector.Connector.initInternal(Connector.java:997)
	at org.apache.catalina.util.LifecycleBase.init(LifecycleBase.java:107)
	... 12 more
```

```
The configured protocol [org.apache.coyote.http11.Http11AprProtocol] requires the APR/native library which is not available
```

ということで [Tomcat Native Library](http://tomcat.apache.org/native-doc/) とやらが必要なようです。

```bash
sudo yum install apr-devel
tar xvf tomcat-native-1.2.4-src.tar.gz
cd tomcat-native-1.2.4-src/native
./configure --prefix=/usr --libdir=/usr/lib64 --with-java-home=/usr/java/latest --with-ssl
make
sudo make install
```

これで libtcnative がインストールされました

```
$ ls /usr/lib64/libtcnative-1.*
/usr/lib64/libtcnative-1.a   /usr/lib64/libtcnative-1.so    /usr/lib64/libtcnative-1.so.0.2.4
/usr/lib64/libtcnative-1.la  /usr/lib64/libtcnative-1.so.0
```

が、うまく行かない。

```
18-Feb-2016 00:11:57.657 SEVERE [main] org.apache.catalina.core.AprLifecycleListener.lifecycleEvent Failed to initialize the SSLEngine.
 org.apache.tomcat.jni.Error: 70023: This function has not been implemented on this platform
	at org.apache.tomcat.jni.SSL.initialize(Native Method)
	at sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
	at sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
	at sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	at java.lang.reflect.Method.invoke(Method.java:497)
	at org.apache.catalina.core.AprLifecycleListener.initializeSSL(AprLifecycleListener.java:283)
	at org.apache.catalina.core.AprLifecycleListener.lifecycleEvent(AprLifecycleListener.java:135)
	at org.apache.catalina.util.LifecycleBase.fireLifecycleEvent(LifecycleBase.java:94)
	at org.apache.catalina.util.LifecycleBase.setStateInternal(LifecycleBase.java:401)
	at org.apache.catalina.util.LifecycleBase.init(LifecycleBase.java:104)
	at org.apache.catalina.startup.Catalina.load(Catalina.java:606)
	at org.apache.catalina.startup.Catalina.load(Catalina.java:629)
	at sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
	at sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
	at sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	at java.lang.reflect.Method.invoke(Method.java:497)
	at org.apache.catalina.startup.Bootstrap.load(Bootstrap.java:311)
	at org.apache.catalina.startup.Bootstrap.main(Bootstrap.java:494)
```

```
18-Feb-2016 00:11:58.253 WARNING [main] org.apache.tomcat.util.net.openssl.OpenSSLEngine. Failed getting cipher list
 java.lang.Exception: Not implemented
	at org.apache.tomcat.jni.SSL.newSSL(Native Method)
	at org.apache.tomcat.util.net.openssl.OpenSSLEngine.(OpenSSLEngine.java:81)
	at org.apache.tomcat.util.net.AprEndpoint.bind(AprEndpoint.java:365)
	at org.apache.tomcat.util.net.AbstractEndpoint.init(AbstractEndpoint.java:790)
	at org.apache.coyote.AbstractProtocol.init(AbstractProtocol.java:547)
	at org.apache.coyote.http11.AbstractHttp11Protocol.init(AbstractHttp11Protocol.java:66)
	at org.apache.catalina.connector.Connector.initInternal(Connector.java:1010)
	at org.apache.catalina.util.LifecycleBase.init(LifecycleBase.java:107)
	at org.apache.catalina.core.StandardService.initInternal(StandardService.java:549)
	at org.apache.catalina.util.LifecycleBase.init(LifecycleBase.java:107)
	at org.apache.catalina.core.StandardServer.initInternal(StandardServer.java:855)
	at org.apache.catalina.util.LifecycleBase.init(LifecycleBase.java:107)
	at org.apache.catalina.startup.Catalina.load(Catalina.java:606)
	at org.apache.catalina.startup.Catalina.load(Catalina.java:629)
	at sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
	at sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
	at sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	at java.lang.reflect.Method.invoke(Method.java:497)
	at org.apache.catalina.startup.Bootstrap.load(Bootstrap.java:311)
	at org.apache.catalina.startup.Bootstrap.main(Bootstrap.java:494)

18-Feb-2016 00:11:58.361 WARNING [main] org.apache.tomcat.util.net.AprEndpoint.bind Secure re-negotiation is not supported by the SSL library null
18-Feb-2016 00:11:58.380 WARNING [main] org.apache.tomcat.util.net.AprEndpoint.bind Honor cipher order option is not supported by the SSL library null
18-Feb-2016 00:11:58.386 WARNING [main] org.apache.tomcat.util.net.AprEndpoint.bind Disable compression option is not supported by the SSL library null
18-Feb-2016 00:11:58.386 WARNING [main] org.apache.tomcat.util.net.AprEndpoint.bind Disable TLS Session Tickets option is not supported by the SSL library null 
```

yum で入っている OpenSSL が 1.0.1e だからかな? ということで最新の OpenSSL をインストールしてやり直します。

```bash
tar xvf openssl-1.0.2f.tar.gz
cd openssl-1.0.2f
./config --prefix=/opt/openssl zlib shared
make
sudo make install
```

```bash
cd tomcat-native-1.2.4-src/native
./configure --prefix=/usr --libdir=/usr/lib64 --with-java-home=/usr/java/latest --with-ssl=/opt/openssl
make
sudo make install
```

リンク時に rpath が指定されていたので /opt/openssl の新しい OpenSSL が使われるはず。 ldd で確認してみます。

```
$ ldd /usr/lib64/libtcnative-1.so.0.2.4
	linux-vdso.so.1 =>  (0x00007fff17fa5000)
	libssl.so.1.0.0 => /opt/openssl/lib/libssl.so.1.0.0 (0x00007f826088e000)
	libcrypto.so.1.0.0 => /opt/openssl/lib/libcrypto.so.1.0.0 (0x00007f8260440000)
	libapr-1.so.0 => /lib64/libapr-1.so.0 (0x00007f826020b000)
	libpthread.so.0 => /lib64/libpthread.so.0 (0x00007f825ffef000)
	libdl.so.2 => /lib64/libdl.so.2 (0x00007f825fdea000)
	libc.so.6 => /lib64/libc.so.6 (0x00007f825fa29000)
	libz.so.1 => /lib64/libz.so.1 (0x00007f825f813000)
	libuuid.so.1 => /lib64/libuuid.so.1 (0x00007f825f60d000)
	libcrypt.so.1 => /lib64/libcrypt.so.1 (0x00007f825f3d6000)
	/lib64/ld-linux-x86-64.so.2 (0x00007f8260d34000)
	libfreebl3.so => /lib64/libfreebl3.so (0x00007f825f1d3000)
```

イケました、イェイ！

```
$ ~/bin/curl --http2 -sv https://cas.teraoka.me:8443/ -o /dev/null
*   Trying 127.0.0.1...
* Connected to cas.teraoka.me (127.0.0.1) port 8443 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* Cipher selection: ALL:!EXPORT:!EXPORT40:!EXPORT56:!aNULL:!LOW:!RC4:@STRENGTH
* successfully set certificate verify locations:
*   CAfile: /etc/ssl/certs/ca-certificates.crt
  CApath: none
* TLSv1.2 (OUT), TLS header, Certificate Status (22):
} [5 bytes data]
* TLSv1.2 (OUT), TLS handshake, Client hello (1):
} [512 bytes data]
* TLSv1.2 (IN), TLS handshake, Server hello (2):
{ [75 bytes data]
* TLSv1.2 (IN), TLS handshake, Certificate (11):
{ [2493 bytes data]
* TLSv1.2 (IN), TLS handshake, Server key exchange (12):
{ [333 bytes data]
* TLSv1.2 (IN), TLS handshake, Server finished (14):
{ [4 bytes data]
* TLSv1.2 (OUT), TLS handshake, Client key exchange (16):
} [70 bytes data]
* TLSv1.2 (OUT), TLS change cipher, Client hello (1):
} [1 bytes data]
* TLSv1.2 (OUT), TLS handshake, Finished (20):
} [16 bytes data]
* TLSv1.2 (IN), TLS change cipher, Client hello (1):
{ [1 bytes data]
* TLSv1.2 (IN), TLS handshake, Finished (20):
{ [16 bytes data]
* SSL connection using TLSv1.2 / ECDHE-RSA-AES256-GCM-SHA384
* ALPN, server accepted to use h2
* Server certificate:
* 	 subject: CN=cas.teraoka.me
* 	 start date: Feb 13 03:32:00 2016 GMT
* 	 expire date: May 13 03:32:00 2016 GMT
* 	 subjectAltName: cas.teraoka.me matched
* 	 issuer: C=US; O=Let's Encrypt; CN=Let's Encrypt Authority X1
* 	 SSL certificate verify ok.
* Using HTTP2, server supports multi-use
* Connection state changed (HTTP/2 confirmed)
* TCP_NODELAY set
* Copying HTTP/2 data in stream buffer to connection buffer after upgrade: len=0
} [5 bytes data]
* Using Stream ID: 1 (easy handle 0x995dd0)
} [5 bytes data]
> GET / HTTP/1.1
> Host: cas.teraoka.me:8443
> User-Agent: curl/7.46.0
> Accept: */*
> 
{ [5 bytes data]
< HTTP/2.0 200
< content-type:text/html;charset=UTF-8
< date:Wed, 17 Feb 2016 15:47:25 GMT
< 
{ [5 bytes data]
* Connection #0 to host cas.teraoka.me left intact
```
