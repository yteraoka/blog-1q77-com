---
title: 'ownCloud でオンプレ Dropbox'
date: Sat, 20 Apr 2013 05:18:22 +0000
draft: false
tags: ['Dropbox', 'ownCloud', 'ownCloud']
---

![ownCloud](/wp-content/uploads/2013/04/ownCloud-login.png "ownCloud") [Dropbox](https://www.dropbox.com/) は便利ですが、データを外部に預けてしまうのは不安だとか、料金が気に入らないという人には [ownCloud](http://owncloud.org/) という Dropbox クローンを使うという選択肢があるようです。ということで試してみました。 日本で ownCloud を使ったサービスを提供されてるところもあるようです。([http://owncloud.jp/](http://owncloud.jp/)) サーバーは PHP で書かれていて Web Server は Apache でも Nginx でも Lighttpd でも IIS でも OK ([Installation](http://doc.owncloud.org/server/5.0/admin_manual/installation.html)).IIS が使えることからわかるように Windows をサーバーに使うこともできます。 DB は SQLite か MySQL. ユーザー認証に LDAP や IMAP、SMB に FTP なんてのも使えるようです。 サーバー側のストレージには local disk、SMB mount、WebDAV に OpenStack の [Swift](http://openstack.org/projects/storage/) が使えるようです。 インストールもとっても簡単、主要な Linux distrbution であれば [package](http://software.opensuse.org/download.html?project=isv:ownCloud:community&package=owncloud) が存在します。 試した環境はさくらのVPSで CentOS 6 + Apache + MySQL + ローカルストレージ。 クライアントソフトも Windows、Mac OS X、Linux 向けに無料のフォルダ同期クライアントが提供されており、iOS、Android 向けのアプリ（[iTunes](https://itunes.apple.com/us/app/owncloud/id543672169?ls=1&mt=8)、[Google Play](https://play.google.com/store/apps/details?id=com.owncloud.android)）も有料ですが最低価格程度で提供されています。 Webブラウザでもアクセス可能です。 フォルダ同期ではサーバー側、クライアント側それぞれで任意のフォルダ選択して同期させます。同期のペアは複数設定できます。アカウントは一つのみです。 グループでの共有、アクセス権管理もできます。参照だけさせる共有や編集も可能にする共有ができます。共有された側の Shared というフォルダに下に見えるようになります。ブラウザからの操作で任意のファイル用のURLを作成し不特定多数の人と共有することもできますし、そこにパスワードをつけることもできます。 iOS、Android のクライアントでは複数のアカウントを切り替えながら使う機能がありました。 Linux Mint 14、Windows 8、iOS (iPhone 5)、Android (Nexus 7) でクライアントを試してみました。 ↓これは Linux クライアント ![](/wp-content/uploads/2013/04/ownCloud-linux-client.png "Linux Client") Web サーバーで SSL を設定すれば通信は暗号化されます。自己署名の証明書でも使えました。 Linux クライアントは現状だと、サーバーに接続できなかった場合、エラーで終了してしまいます。無線LANが不安定だったりするといつのまにかいなくなってます... Dropbox の場合、Windows でも Linux でもクライアント側のファイルを右クリックで過去のバージョンへアクセスできますが、現状の ownCloud ではブラウザでログインしてからそのファイルのメニューからアクセスする必要があります。 ![Rename, Download, Versions, Share](/wp-content/uploads/2013/04/ownCloud-file-menu.png "ファイル操作メニュー") 削除したファイルを取り出すにはブラウザで画面右上の「Deleted files」からWindows のゴミ箱にアクセスする感じです。 ![](/wp-content/uploads/2013/04/ownCloud-deleted-files.png "Deleted files") 戻したいファイルで「Restore」をクリックします。「Download」の方は機能しませんでした。なぜだろ？ ![](/wp-content/uploads/2013/04/ownCloud-restore.png "Restore") まだ使ったことがありませんが、ownCloud にはアドレス帳、カレンダー、音楽プレーヤー、画像ビューワーなんて機能もあるようです。 ![](/wp-content/uploads/2013/04/ownCloud-side.png) [Features | ownCloud.org](http://owncloud.org/features/) Lucene ベースの検索とかドキュメントビューワーとかまだまだ機能はあります。 セットアップは簡単なので興味を持ったら是非お試しを。 今後に期待のソフトウェアですが、個人利用だったらまだまだ Dropbox が便利ですかね。100GBで年間$99だからさくらのVPSで100GBのプランを借りるのと変わらない。

[![ownCloud](https://a174.phobos.apple.com/us/r1000/111/Purple2/v4/6d/2e/de/6d2ede80-766a-506e-9e61-a0477c1125ba/mzl.dcfrmswu.100x100-75.png "ownCloud")](https://itunes.apple.com/jp/app/owncloud/id543672169?mt=8&uo=4)

[ownCloud](https://itunes.apple.com/jp/app/owncloud/id543672169?mt=8&uo=4)  
ownCloud, Inc.  
価格： 85円  
[![iTunesで見る](https://ax.phobos.apple.com.edgesuite.net/ja_jp/images/web/linkmaker/badge_appstore-sm.gif)](https://itunes.apple.com/jp/app/owncloud/id543672169?mt=8&uo=4)  
posted with [sticky](http://sticky.linclip.com/linkmaker/) on 2013.4.20  

[![](https://lh5.ggpht.com/p7kxWC_IgYgI3asyDiFvS61aFUKfSZYRrqvNjfcmcOD_OJB-rgKlcWAiX3Cyj-wbCg=w124)**ownCloud**](https://play.google.com/store/apps/details?id=com.owncloud.android)  
ownCloud, Inc.  
価格：99円　　平均評価：3.2（556）