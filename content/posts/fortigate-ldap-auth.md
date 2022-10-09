---
title: 'FortiGate で VPN 認証に LDAP / Active Directory を使う'
date: Fri, 05 Apr 2013 15:11:45 +0000
draft: false
tags: ['ActiveDirectory', 'FortiGate', 'LDAP', 'LDAP']
---

メジャーな UTM である [FortiGate](http://www.fortinet.co.jp/) で VPN などのユーザー認証に LDAP / Active Directory を使う方法を紹介。LDAP サーバーの構築方法は [OpenDJ – LDAP Server (1)](/2013/03/opendj-ldap-server-1/) で。FortiGate の OS は Version 4.0 MR3 で確認。

### LDAP の場合

これは簡単 **User > Remote > LDAP > Create New** で

Name

ldap.example.com （任意の名前）

Server Name/IP

ldap.example.com （LDAPサーバー）

Server Port

1389 （IANA の wellknown port は 389）

Common Name Identifier

uid

Destinguished Name

ou=People,dc=example,dc=com

Bind Type

Simple

### Active Directory の場合

AD を使う場合は FortiGate からアクセスするためのユーザーが必要。**Domain Users** に属していれば OK ここでは fortigate@example.com というユーザーを作成する。表示名は「**FortiGate VPN**」とする。 **User > Remote > LDAP > Create New** で

Name

ActiveDirectory （任意の名前）

Server Name/IP

192.168.xx.xx （AD Server）

Server Port

389

Common Name Identifier

sAMAccountName

Distinguished Name

OU=Users,DC=example,DC=com

Bind Type

Regular

User DN

CN=FortiGate VPN,CN=Users,DC=example,DC=com （CNはADの表示名の値）

Password

パスワード （fortigate@example.comユーザーのパスワード）

ユーザーの ou は部署ごとに分かれてても ok でした。