---
title: 'CertM という TLS 証明書作成ツール'
date: Fri, 10 Jun 2016 15:00:59 +0000
draft: false
tags: ['Certificate', 'Docker', 'TLS']
---

[https://github.com/ehazlett/certm](https://github.com/ehazlett/certm) という TLS 証明書作成ツールを見つけたのでメモっておく OpenSSL での証明書作成については [https://jamielinux.com/docs/openssl-certificate-authority/index.html](https://jamielinux.com/docs/openssl-certificate-authority/index.html) がとても良く出来ているのであまりこのツールに頼ることはない気もするがテスト用の証明書をさくっと作りたい場合には使うかもしれない （docker を実行可能な環境であれば `docker run ...` と実行するだけで使えるっていうのは配布方法としても悪くないですね） まずはヘルプを見てみる

```
$ docker run --rm ehazlett/certm -h
NAME:
   /bin/certm - certificate management

USAGE:
   /bin/certm [global options] command [command options] [arguments...]

VERSION:
   0.1.2 (f7754d5)

AUTHOR:
  @ehazlett

COMMANDS:
   ca		CA certificate management
   server	server certificate management
   client	client certificate management
   bundle	generate CA, server and client certs
   help, h	Shows a list of commands or help for one command
   
GLOBAL OPTIONS:
   --output-directory, -d 	output directory for certs
   --debug, -D			enable debug
   --help, -h			show help
   --version, -v		print the version
```

### CA の証明書を作成する

```
$ mkdir certs
$ docker run --rm -v $(pwd)/certs:/certs ehazlett/certm -d /certs ca generate -o=local
generating ca: org=local bits=2048
$ ls certs
ca-key.pem  ca.pem
```

こんなのが生成されました。

```
$ openssl x509 -text -in certs/ca.pem -noout
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            5c:4b:0e:8c:4a:28:20:68:36:de:2d:a6:88:82:bf:f6
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: O=local
        Validity
            Not Before: Jun 10 13:42:00 2016 GMT
            Not After : May 26 13:42:00 2019 GMT
        Subject: O=local
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:bb:8f:c4:1c:53:c7:11:d8:fb:5d:d6:33:1c:cb:
                    ...
                    26:17
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment, Key Agreement, Certificate Sign
            X509v3 Basic Constraints: critical
                CA:TRUE
    Signature Algorithm: sha256WithRSAEncryption
         87:bb:4c:4a:d9:0b:a8:5d:88:ac:52:6b:96:b0:38:6c:b3:dc:
         ...
         fc:09:9f:2e
```

鍵は RSA の 2048 bit Subject で指定可のなのは `O` の Organization だけ 鍵の bit 数は `-b` で指定可能

```
$ docker run --rm ehazlett/certm ca -h
NAME:
   generate - generate new certificate

USAGE:
   command generate [command options] [arguments...]

OPTIONS:
   --org, -o "unknown"	organization
   --bits, -b "2048"	number of bits in the key (default: 2048)
   --overwrite		overwrite existing certificates and keys
```

### サーバー証明書を作成する

```
$ docker run --rm -v $(pwd)/certs:/certs ehazlett/certm -d /certs server generate --host localhost --host 127.0.0.1 -o=local
generating server certificate: org=local bits=2048
$ ls certs/
ca-key.pem  ca.pem  server-key.pem  server.pem
```

次のような証明書が作成されました

```
$ openssl x509 -text -in certs/server.pem -noout
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            54:e0:8b:ae:b9:94:cd:e3:09:fb:79:22:38:dd:a3:50
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: O=local
        Validity
            Not Before: Jun 10 13:48:00 2016 GMT
            Not After : May 26 13:48:00 2019 GMT
        Subject: O=local
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:ea:3c:c4:ac:46:23:09:29:e0:a1:65:35:d6:00:
                    ...
                    85:ff
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment, Key Agreement
            X509v3 Extended Key Usage: 
                TLS Web Client Authentication, TLS Web Server Authentication
            X509v3 Basic Constraints: critical
                CA:FALSE
            X509v3 Subject Alternative Name: 
                DNS:localhost, IP Address:127.0.0.1
    Signature Algorithm: sha256WithRSAEncryption
         27:5e:4e:b9:89:87:93:f7:af:0f:a8:89:fc:87:25:82:2b:81:
         ...
         9f:f2:b8:fa
```

こちらも Subject は O=local (Organization) だけ

```
        Subject: O=local
```

サーバー証明書作成モード (server) だけどクライアント証明書としても使えるようになっている

```
            X509v3 Extended Key Usage: 
                TLS Web Client Authentication, TLS Web Server Authentication
```

`--host localhost --host 127.0.0.1` と指定したため subjectAltName に DNS:localhost,IP:127.0.0.1 が指定されている。もっと沢山ならべることも可能。IPアドレスでアクセスする場合は CommonName (CN) が使えないらしいので subjectAltName が使えることを知っておくと便利

```
            X509v3 Subject Alternative Name: 
                DNS:localhost, IP Address:127.0.0.1
```

こちらも指定できる subject は Organization だけですね。sbjectAltName が指定できるから CommonName が指定できなくても大丈夫なのかな。ダメなクライアントもありそうだけど。

```
$ docker run --rm ehazlett/certm server -h
NAME:
   generate - generate new certificate

USAGE:
   command generate [command options] [arguments...]

OPTIONS:
   --ca-cert 				CA certificate for signing (defaults to ca.pem in output dir)
   --ca-key 				CA key for signing (defaults to ca-key.pem in output dir)
   --cert 				certificate name (default: server.pem)
   --key 				key name (default: server-key.pem)
   --host [--host option --host option]	SAN/IP SAN for certificate
   --org, -o "unknown"			organization
   --bits, -b "2048"			number of bits in the key (default: 2048)
   --overwrite				overwrite existing certificates and keys
```

### クライアント署名書を作成する

クライアント証明書では `CommonName` が指定可能になってますね クライアントのアイデンティファイにも使えるようにかな

```
$ docker run --rm ehazlett/certm client -h
NAME:
   generate - generate new certificate

USAGE:
   command generate [command options] [arguments...]

OPTIONS:
   --ca-cert 		CA certificate for signing (defaults to ca.pem in output dir)
   --ca-key 		CA key for signing (defaults to ca-key.pem in output dir)
   --cert 		certificate name (default: cert.pem)
   --key 		key name (default: key.pem)
   --common-name, -c 	common name
   --org, -o "unknown"	organization
   --bits, -b "2048"	number of bits in the key (default: 2048)
   --overwrite		overwrite existing certificates and keys
```

```
$ docker run --rm -v $(pwd)/certs:/certs ehazlett/certm -d /certs client generate --common-name=ehazlett -o=local
generating client certificate: cn="ehazlett" org=local bits=2048 cert="/certs/cert.pem" key="/certs/key.pem"
```

```
$ openssl x509 -text -noout -in certs/cert.pem
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            a8:5d:80:4a:77:ae:73:84:a1:e3:8b:82:43:28:c7:71
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: O=local
        Validity
            Not Before: Jun 10 14:10:00 2016 GMT
            Not After : May 26 14:10:00 2019 GMT
        Subject: O=local, CN=ehazlett
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:d2:39:09:4e:18:69:fe:17:3f:12:d9:22:7f:a5:
                    ...
                    14:cb
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment, Key Agreement
            X509v3 Extended Key Usage: 
                TLS Web Client Authentication, TLS Web Server Authentication
            X509v3 Basic Constraints: critical
                CA:FALSE
    Signature Algorithm: sha256WithRSAEncryption
         97:02:cc:98:55:21:d5:3a:b5:75:8d:46:37:d7:79:75:a5:bc:
         ...
         dc:37:6f:20
```

CommonName (CN) がセットされてる

```
        Subject: O=local, CN=ehazlett
```

クライアント認証用のコマンドだけどサーバー証明書としても使える

```
            X509v3 Extended Key Usage: 
                TLS Web Client Authentication, TLS Web Server Authentication
```

### bundle モード

CA, Server, Client 証明書を1コマンドで作ってくれる でも CommonName が指定できない

```
$ docker run --rm ehazlett/certm bundle -hNAME:
   generate - generate new bundle

USAGE:
   command generate [command options] [arguments...]

OPTIONS:
   --host [--host option --host option]	SAN/IP SAN for certificate
   --org, -o "unknown"			organization
   --bits, -b "2048"			number of bits in the key (default: 2048)
   --overwrite				overwrite existing certificates and keys
```

```
$ docker run --rm -v $(pwd)/certs:/certs ehazlett/certm -d /certs bundle generate --host 127.0.0.1 -o=local
generating ca: org=local bits=2048
$ ls certs
ca-key.pem  ca.pem  cert.pem  key.pem  server-key.pem  server.pem
```

### PKCS12 形式に変換

クライアント証明書を PKCS12 形式にする

```
$ openssl pkcs12 -export -in certs/cert.pem -inkey certs/key.pem -out certs/cert.p12 -password pass:""
```

### 使ってみる

bundle で作成したものを Apache で使ってみた `SSLCertificateFile`, `SSLCertificateKeyFile`, `SSLCACertificateFile` に certm で作成した証明書と鍵を指定し `SSLVerifyClient` を `require` にしてテストしました。 無事アクセスできました。ヨカッタネ
