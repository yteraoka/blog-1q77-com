---
title: 'OpenDJ - LDAP Server (2)'
date: Tue, 09 Apr 2013 15:42:14 +0000
draft: false
tags: ['LDAP', 'OpenDJ']
---

前回 [OpenDJ - LDAP Server (1)](/2013/03/opendj-ldap-server-1/) の続き 今回はデータの export, import, backup, restore あたりを紹介。 control-panel は GUI での操作と等価なコマンド(CLI)も表示してくれるので便利。

### export

Export はこんな感じでまるっと export できます。

```
bin/export-ldif \
 --backendID userRoot \
 --hostname 192.168.0.12 \
 --port 4444 \
 --bindDN "cn=Directory Manager" \
 --bindPassword ******** \
 --trustAll \
 --ldifFile /tmp/export.ldif
```

`--excludeBranch ou=Group,dc=example,dc=com` をつければグループ情報を除外することができます。 `--excludeAttribute ds-sync-generation-id` をつければその項目を除外できます。 これらは import 時にも指定可能です。 Replication 構成のサーバーから export すると ds-sync-\* という attribute が export されますが、それをそのまま import しようとすると意図した通りにならなかったりするので注意。ただ export したものを import したいだけの場合は ds-sync-\* は除外しておくのが良いでしょう。

### import

export とよく似てます。

```
bin/import-ldif \
 --backendID userRoot \
 --hostname 192.168.0.12 \
 --port 4444 \
 --bindDN cn=Directory\ Manager \
 --bindPassword ******** \
 --trustAll \
 --excludeAttribute ds-sync-generation-id \
 --excludeBranch ou=Group,dc=example,dc=com \
 --append \
 --ldifFile /tmp/users.ldif
```

通常 import はデータの追加登録の用途で利用すると思います、この時 `--append` を忘れると全部消えてしまうという悲惨な目にある可能性が高いので要注意です。また、デフォルトではすでに存在するエントリーは上書きしないので、上書きしたい場合は `--replaceExisting` をつけます。export 同様 `--excludeAttribute` や `--excludeBranch` は必要に応じて指定。exclulde じゃなくて include という指定方法もあります。 1ユーザー追加しようと思って `uid=user,ou=People,dc=example,dc=com` の1エントリーだけの ldif を作って `--append` を忘れると `dc=example,dc=com` も `ou=People` も消えてしまって空っぽになってしまいます。要注意。 import で replication が崩れることがありますが、そんな場合は忘れずに `dsreplication initialize` してください。

### Backup

バックアップは保存先ディレクリと任意の名前(bakupID)を指定します。 control-panel からバックアップを行うと backupID は日時がセットされます。 圧縮、暗号化、増分バックアップも指定できます（今回は省略）。

```
bin/backup \
 --backupDirectory /opt/OpenDJ-2.5.0-Xpress1/bak \
 --backupID 20130409232226 \
 --backendID userRoot \
 --hostName 192.168.0.12 \
 --port 4444 \
 --bindDN cn=Directory\ Manager \
 --bindPassword ******** \
 --trustAll \
 --noPropertiesFile
```

### Restore

リストアは Backup の逆ですね。

```
bin/restore \
 --backupID 20130409232226 \
 --backupDirectory /opt/OpenDJ-2.5.0-Xpress1/bak \
 --bindPassword ******** \
 --trustAll
```

`--dry-run` をつけると実際には restore せずにチェックを行なってくれます。 でわでわ、また何かあったら続きを書くかも。
