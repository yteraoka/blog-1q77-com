---
title: 'OpenDJ - LDAP Server (1)'
date: Wed, 27 Mar 2013 15:52:26 +0000
draft: false
tags: ['LDAP', 'LDAP', 'OpenDJ']
---

[OpenDJ](http://forgerock.com/what-we-offer/open-identity-stack/opendj/) とは Sun Microsystems が OSS として開発していた OpenDS という LDAP サーバーを Oracle が買収後に「OSS やーめたっ」と発表したために [ForgeRock](http://forgerock.com/) が fork して開発を継続している Java 製の LDAP サーバーです。ForgeRock は OpenSSO についても [OpenAM](http://forgerock.com/what-we-offer/open-identity-stack/openam/) として開発を行なっています。 Sun が開発を行なっていたためか、日本語ローカライズがしっかりされています。LANG=ja\_JP.UTF8 で作業すればほとんど日本語で表示されます。 OpenDJ は Multi-Master Replication の構成を組むことが可能です。 そして、LDAP エントリを操作するための GUI もついています。 [ApacheDS](http://directory.apache.org/apacheds/) も Multi-Master Replication 対応で Eclipse plugin の エントリ操作ツール[Apache Directory Studio](http://directory.apache.org/studio/) が提供されてて便利ですね。

> ※2013-04-05追記 Apache Directory Studio は Eclipse プラグインじゃなくて単体アプリになってました。これだけでも使えます、便利です。Active Directory につないだりもできます。

Multi-Master なんていう甘い言葉は危険なかおリもしますが、LDAP はもともと更新頻度の低いデータベースなので危険度は低いのではないかと。実際には、ホットスタンバイとして使ってるわけですけど。 それでは、OpenDJ のセットアップを。

Install
-------

まずは1台目のセットアップ (192.168.0.12) 最新版の OpenDJ-2.5.0-Xpress1.zip をダウンロードし、任意の場所で展開します。 そこで setup コマンドを実行すれば GUI のインストーラーが起動しますが、サーバーだとコマンドラインですね。`--cli` をつけましょう。`--no-prompt` を付けなければ指定しなかった項目は入力を求められます。

```
$ ./setup \
  --cli \
  --baseDN dc=example,dc=com \
  --sampleData 10 \
  --ldapPort 1389 \
  --adminConnectorPort 4444 \
  --rootUserDN cn=Directory\ Manager \
  --rootUserPassword password \
  --ldapsPort 1636 \
  --generateSelfSignedCertificate \
  --hostName ldap.example.com \
  --no-prompt \
  --noPropertiesFile
```

これで example.com ドメインの LDAP サーバーが構築できました。`--sampleData 10` の指定により10個のサンプルユーザーデータが作成されています。root で実行しないので1000番台の port となっています。自己署名の SSL 付き。 `bin/control-panel` で接続してみるとこんな感じ。

{{< figure src="Screenshot_from_2013-03-25-232622-e1364398286394.png" >}}

{{< figure src="Screenshot_from_2013-03-25-232558-e1364398359869.png" >}}

次に2台目のセットアップ (192.168.0.11)

```
$ ./setup \
  --cli \
  --baseDN dc=example,dc=com \
  --ldapPort 1389 \
  --adminConnectorPort 4444 \
  --rootUserDN cn=Directory\ Manager \
  --rootUserPassword password \
  --ldapsPort 1636 \
  --generateSelfSignedCertificate \
  --hostName ldap.example.com \
  --no-prompt \
  --noPropertiesFile
```

今度はサンプルデータはなしでセットアップして、Replication で同期されることを確認します。

Replication Setup
-----------------

1台目(192.168.0.12)と2台目(192.168.0.11)で Replication 構成を組むためのコマンドです。

```
$ bin/dsreplication \
 enable \
 --adminUID admin \
 --adminPassword password \
 --baseDN dc=example,dc=com \
 --host1 192.168.0.12 \
 --port1 4444 \
 --bindDN1 "cn=Directory Manager" \
 --bindPassword1 password \
 --replicationPort1 8989 \
 --host2 192.168.0.11 \
 --port2 4444 \
 --bindDN2 "cn=Directory Manager" \
 --bindPassword2 password \
 --replicationPort2 8989 \
 --trustAll \
 --no-prompt
```

これで 8989 ポートを使って Replication する設定が行われました。が、この状態ではまだデータは同期されていません。それぞれに control-panel で接続してみるとわかります。

Replication Initialize
----------------------

1台目のデータを2台目にコピーすることでデータを初期化します。 `--hostSource` と `--hostDestination` を反対にしてしまわないように注意。

```
$ bin/dsreplication \
 initialize \
 --baseDN "dc=example,dc=com" \
 --adminUID admin \
 --adminPassword password \
 --baseDN dc=example,dc=com \
 --hostSource 192.168.0.12 \
 --portSource 4444 \
 --hostDestination 192.168.0.11 \
 --portDestination 4444 \
 --trustAll \
 --no-prompt
```

これでおしまい。とっても簡単。それぞれ `status` コマンドで確認してみましょう。

```
$ bin/dsreplication status \
 --adminUID admin \
 --adminPassword password \
 --trustAll \
 --hostname 192.168.0.12 \
 --port 4444
```

```
$ bin/dsreplication status \
 --adminUID admin \
 --adminPassword password \
 --trustAll \
 --hostname 192.168.0.12 \
 --port 4444
```

かれこれ2年ほどトラブルフリーで動作してます。バージョンはちょいと古いですが。 1台停止中にもう1台で更新されたデータは復帰後に自動で反映されます。

Replication をやめる
----------------

サーバーが壊れてしまって切り離したい場合とかで Replication をやめるためにはそれぞれのサーバーに接続して disable にします。

```
$ bin/dsreplication \
 disable \
 --disableAll \
 --port 4444 \
 --hostname 192.168.0.12 \
 --bindDN "cn=Directory Manager" \
 --adminPassword password \
 --trustAll \
 --no-prompt
```

```
$ bin/dsreplication \
 disable \
 --disableAll \
 --port 4444 \
 --hostname 192.168.0.11 \
 --bindDN "cn=Directory Manager" \
 --adminPassword password \
 --trustAll \
 --no-prompt
```

いじょー。 データのバックアップとかリストアとかの手順はまたそのうち。

[つづき](/2013/04/opendj-ldap-server-2/)を書きました。
