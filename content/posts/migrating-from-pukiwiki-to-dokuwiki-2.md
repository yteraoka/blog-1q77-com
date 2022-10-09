---
title: '（続）PukiWiki から DokuWiki にデータ移行'
date: Sat, 20 Apr 2013 14:44:00 +0000
draft: false
tags: ['Perl', 'dokuwiki', 'pukiwiki']
---

先日、「[PukiWiki から DokuWiki にデータ移行](/2013/04/migrating-from-pukiwiki-to-dokuwiki/)」を書いた後にもいろいろ改善をすすめたので改めて整理しておく。添付ファイルに対応しました。さらにその後、UTF-8対応の PullRequest をもらってマージしました。 データ移行スクリプトは Github [https://github.com/yteraoka/puki2doku](https://github.com/yteraoka/puki2doku) に。 PukiWki が /var/www/html/pukiwiki に、DokuWiki が /var/www/html/dokuwiki にある前提とする。 各データもそれぞれのデフォルトのフォルダを使用している前提。

### 添付ファイルのコピー

添付ファイルは PukiWiki では attach/ フォルダに、DokuWiki では data/media/ フォルダに保存される。 PukiWiki は各ページに対して添付するという考え方だが、DokuWiki はページとは独立した名前空間にファイルをアップロードする。データコピーの方法として、ページ名と同じ階層でディレクトリを作成し、そこへコピーすることとした。PukiWiki では attach フォルダに {ページ名}\_{ファイル名} というファイル名で作成されている。これを {ページ名}/{ファイル名} とする。{ページ名} にも / が含まれる。それぞれ、ファイルシステム上はページと同様のエンコーディングが採用されている。

```
$ puki2doku.pl -v -A \
  -s /var/www/html/pukiwiki/attach \
  -d /var/www/html/dokuwiki/data/media
```

**課題** PukiWiki はページに結びついているので、ページ内にリンクが書かれていなくても添付ファルへアクセスできるのだが、DokuWiki ではページ内にリンクがないと迷子になってしまう。ページに添付ファルのリストを追記すべきかもしれない。

### wiki ページの変換

```
$ puki2doku.pl \
  -v \
  --font-color \
  --indexmenu \
  --ignore-unknown-macro \
  -s /var/www/html/pukiwiki/wiki \
  -d /var/www/html/dokuwiki/data/pages
```

前回は `--font-size` で &size(N){str}; を fontsize plugin を利用して引き継ぐようにしていたが、このプラグインは他のテキスト装飾を入れ子にできないという問題があったため無効とした。

### 検索インデックス

インデックスを作成しないと検索できないので次の手順で作成します。

```
$ cd /var/www/html/dokuwiki/bin
$ php indexer.pp
```

この作業やデータ移行を DokuWiki の実行ユーザー以外で実行した場合は `/var/www/html/dokuwiki/data` 配下を全部 DokuWiki 実行ユーザーで書き換え可能にしましょう。

### キャッシュとかメタデータ

DokuWiki は data/cache/, data/meta/ などにキャッシュを作成するので、移行手順をやり直す場合などはこのあたりのファイルを消してやる必要があります。

### LDAP認証

DokuWiki は標準で LDAP 認証をサポートしている。 LDAP サーバーとして以前取り上げた（[その1](/2013/03/opendj-ldap-server-1/)、[その2](/2013/04/opendj-ldap-server-2/)） OpenDJ を使っている場合は `dokuwiki/conf/local.php` に次のように書くことで

```
$conf['useacl'] = 1;
$conf['authtype'] = 'ldap';
$conf['openregister'] = '0';
$conf['auth']['ldap']['server'] = 'ldap://ldap.example.com:1389';
$conf['auth']['ldap']['usertree'] = 'ou=People,dc=example,dc=com';
$conf['auth']['ldap']['grouptree'] = 'ou=Group,dc=example,dc=com';
$conf['auth']['ldap']['userfilter'] = '(&(uid=%{user})(objectClass=inetorgperson))';
$conf['auth']['ldap']['groupfilter'] = '(&(objectClass=groupOfUniqueNames)(uniqueMember=%{dn}))';
```

`dokuwiki/conf/acl.auth.php` に `@グループ名` としてグループでの権限設定も可能となる。

### 矢印とかの自動置換

`dokuwiki/conf/entities.conf` に

```
<->     ↔
->      →
<-      ←
<=>     ⇔
=>      ⇒
<=      ⇐
>>      »
<<      «
---     —
--      –
(c)     ©
(tm)    ™
(r)     ®
...     …
```

というページ表示時に自動的に置換して表示する機能がありますが、技術系の文書を書いてる場合「--」とか「<<」などを置換されるとウザイので全部コメントアウトしてしまいましょう。

### 諸設定

スーパーユーザーに設定されたアカウントであれば管理ページにアクセスしてページ名やデザインやプラグインの有効化・無効化などいろいろな設定ができます。 スーパーユーザー設定は `conf/local.php` で

```
$conf['superuser'] = 'user1,user2';
```

と設定します。複数人指定する場合はカンマ区切りで指定。 前回書いたファイル名のエンコーディングはここで変更可能でした。UTF-8でそのままファイルを作成することも出来るようですが、プラグインなどの互換性の問題で推奨されてません。 トップページを `start` から PukiWiki と同じ `FrontPage` にすることもできますが、こちらも互換性の問題で変更は推奨されていませんでした。 これで一段落かな。（もうちょっとかっこいい [Template](https://www.dokuwiki.org/template) ないかなぁ...）
