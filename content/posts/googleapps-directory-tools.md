---
title: 'GoogleAppsのアカウント操作用コマンドラインツールを書いた'
date: Thu, 14 Aug 2014 14:52:56 +0000
draft: false
tags: ['GoogleApps', 'Python', 'API']
---

GoogleApps のアカウントやグループ操作をブラウザからポチポチやってたら日が暮れそうだったのでコマンドラインツールを書きました。 [https://github.com/yteraoka/googleapps-directory-tools](https://github.com/yteraoka/googleapps-directory-tools) 旧版の API は廃止予定とのことで OAuth 2.0 版の API を使ってます（ぜんぜん理解していないけれど）。 [google-api-python-client](https://code.google.com/p/google-api-python-client/) を使っていて、[samples/groupssettings/groupsettings.py](https://code.google.com/p/google-api-python-client/source/browse/samples/groupssettings/groupsettings.py) を参考にしています(Python は素人です)。 OOP っぽく使えるライブラリにすれば良かったなと思いつつ、取り急ぎ動くものが必要だったということもありとりあえずは今のかたちで。 対応している操作は

* [Orgunits](https://github.com/yteraoka/googleapps-directory-tools#orgunits) (組織、部署)
* [Users](https://github.com/yteraoka/googleapps-directory-tools#users) (ユーザー)
* [Users.aliases](https://github.com/yteraoka/googleapps-directory-tools#usersaliases) (ユーザーエイリアス)
* [Groups](https://github.com/yteraoka/googleapps-directory-tools#groups) (グループ)
* [Group.aliases](https://github.com/yteraoka/googleapps-directory-tools#groupsaliases) (グループエイリアス)
* [Members](https://github.com/yteraoka/googleapps-directory-tools#members) (グループのメンバー)
* [Groups Settings](https://github.com/yteraoka/googleapps-directory-tools#groups-for-business) (Groups for business 用設定)

それぞれの確認、一覧(検索)、作成、削除、更新です。あと、一部は JSON ファイルからの一括登録。それぞれの API でサポートされていることはほぼできるはず。

セットアップ
------

Python のバージョンは 2.7.6, 2.7.8 でしかテストしてません。CentOS 6 ですが、source から [xbuild](https://github.com/tagomoris/xbuild) で入れました。後は

```
$ pip install google-api-python-client simplejson
```

するだけ。simplejson は json ファイルから一括で登録したりするときにしか使わないけど常に load してるので必要。

OAuth 認証
--------

まず、[Google Developers Console](https://console.developers.google.com/) (このアカウントは Google Apps とは関係ない個人のアカウントでも問題ありません) にて既存のプロジェクトを選択するか、新規作成し、左のメニューにある「API と認証」の「認証情報」を選択する。「新しいクライアントIDを作成する」をクリックし、「アプリケーションの種類」を「インストールされているアプリケーション」、「インストールされているアプリケーションの種類」を「その他」としてクライアントIDを作成する。すると「ネイティブ アプリケーションのクライアント ID」が新たに追加されるので「JSONをダウンロード」をクリックして clone した中の private ディレクトリに `client_secret.json` という名前で保存する。またそのプロジェクトで使う API を有効にする必要があるため、左のメニューから「API と認証」→「API」で「Admin SDK」と「Groups Settings API」を有効にします。 その後、次のようにコマンドを実行すると

```
$ ./user.py --noauth_local_webserver list -d your.domain.name
```

次のように表示されるのでブラウザに URL を貼り付けて、Google Apps の管理者アカウントでログインした状態で承認します。そこで表示されるコードをコピペでターミナルに貼り付けます。

```
Go to the following link in your browser:

    https://accounts.google.com/o/oauth2/auth?...

Enter verification code:
```

`Authentication successful.` と表示されれば次から使えるようになります。 今のバージョンではここで `unknown command '--noauth_local_webserver'` と表示されてしまいますが、無視してください。

ユーザーを操作する
---------

### 一覧

```
$ ./user.py list -d example.com
```

これだけの場合はメールアドレス、姓、名だけを表示しますが、`--json` を追加すると JSON フォーマットで他の詳細情報も出力されます。`--json` の代わりに `--jsonPretty` を使えば読みやすく出力します。list API は件数が多いと paging されて結果が帰りますが、list コマンドはすべてのページを取り出して返します。`--query` を使えば検索できます。[クエリの書き方](https://developers.google.com/admin-sdk/directory/v1/guides/search-users) 各サブコマンドに `--help` をつければ簡単な使い方が表示されます。

```
$ ./user.py --help
usage: user.py [-h] [--auth_host_name AUTH_HOST_NAME]
               [--noauth_local_webserver]
               [--auth_host_port [AUTH_HOST_PORT [AUTH_HOST_PORT ...]]]
               [--logging_level {DEBUG,INFO,WARNING,ERROR,CRITICAL}]
               {list,get,insert,patch,delete,setadmin,unsetadmin,bulkinsert}
               ...

positional arguments:
  {list,get,insert,patch,delete,setadmin,unsetadmin,bulkinsert}
                        sub command
    list                Retrieves a paginated list of either deleted users or
                        all users in a domain
    get                 Retrieves a user
    insert              Creates a user
    patch               Updates a user
    delete              Deletes a user
    setadmin            Makes a user a super administrator
    unsetadmin          Makes a user a normal user
    bulkinsert          bulk insert

optional arguments:
  -h, --help            show this help message and exit
```

```
$ ./user.py list --help
usage: user.py list [-h] [-v] [--json] [--jsonPretty]
                    [--orderBy {email,familyName,givenName}]
                    [--maxResults MAXRESULTS] [-q QUERY] [-r] [--showDeleted]
                    domain

positional arguments:
  domain                search domain

optional arguments:
  -h, --help            show this help message and exit
  -v, --verbose         show all user data
  --json                output in JSON
  --jsonPretty          output in pretty JSON
  --orderBy {email,familyName,givenName}
                        show all user data
  --maxResults MAXRESULTS
                        Acceptable values are 1 to 500
  -q QUERY, --query QUERY
                        search query
  -r, --reverse         DESCENDING sort
  --showDeleted         show deleted user only
```

### ユーザーの追加

次のようにしてユーザーを追加できます。

```
$ ./user.py insert t.yamada@example.com password 山田 太郎
```

`--orgUnitPath` で組織グループを指定可能 (`--orgUnitPath /営業部` など) ですが、事前に組織を作成しておく必要があります。orgunit.py で作成可能ですが、このコマンドには customerId を渡す必要があります。ユーザーの情報に含まれているので `get` や `list` に `--json` や `--jsonPretty` をつけて実行すれば確認することができます。

グループを操作する
---------

グループの作成、削除は [group.py](https://github.com/yteraoka/googleapps-directory-tools#groups) で行い、その参加者の操作は [member.py](https://github.com/yteraoka/googleapps-directory-tools#members) で行います。 Groups for Businness では Web でメールの管理(スレッド表示や投稿、返信など)ができます。この設定については group-settings.py で行います。こちらは項目が大変多いです。[ドキュメント (Google Apps Groups Settings API)](https://developers.google.com/admin-sdk/groups-settings/v1/reference/groups) を参照してください。

```
$ ./group-settings.py patch --help
usage: group-settings.py patch [-h]
                               [--whoCanInvite {ALL_MANAGERS_CAN_INVITE,ALL_MEMBERS_CAN_INVITE}]
                               [--whoCanJoin {ANYONE_CAN_JOIN,ALL_IN_DOMAIN_CAN_JOIN,INVITED_CAN_JOIN,CAN_REQUEST_TO_JOIN}]
                               [--whoCanPostMessage {ALL_IN_DOMAIN_CAN_POST,ALL_MANAGERS_CAN_POST,ALL_MEMBERS_CAN_POST,ANYONE_CAN_POST,NONE_CAN_POST}]
                               [--whoCanViewGroup {ALL_IN_DOMAIN_CAN_VIEW,ALL_MANAGERS_CAN_VIEW,ALL_MEMBERS_CAN_VIEW,ANYONE_CAN_VIEW}]
                               [--whoCanViewMembership {ALL_IN_DOMAIN_CAN_VIEW,ALL_MANAGERS_CAN_VIEW,ALL_MEMBERS_CAN_VIEW}]
                               [--messageModerationLevel {MODERATE_ALL_MESSAGES,MODERATE_NON_MEMBERS,MODERATE_NEW_MEMBERS,MODERATE_NONE}]
                               [--spamModerationLevel {ALLOW,MODERATE,SILENTLY_MODERATE,REJECT}]
                               [--whoCanLeaveGroup {ALL_MANAGERS_CAN_LEAVE,ALL_MEMBERS_CAN_LEAVE}]
                               [--whoCanContactOwner {ALL_IN_DOMAIN_CAN_CONTACT,ALL_MANAGERS_CAN_CONTACT,ALL_MEMBERS_CAN_CONTACT,ANYONE_CAN_CONTACT}]
                               [--messageDisplayFont {DEFAULT_FONT,FIXED_WIDTH_FONT}]
                               [--replyTo {REPLY_TO_CUSTOM,REPLY_TO_SENDER,REPLY_TO_LIST,REPLY_TO_OWNER,REPLY_TO_IGNORE,REPLY_TO_MANAGERS}]
                               [--membersCanPostAsTheGroup {true,false}]
                               [--includeInGlobalAddressList {true,false}]
                               [--customReplyTo CUSTOMREPLYTO]
                               [--sendMessageDenyNotification {true,false}]
                               [--defaultMessageDenyNotificationText DEFAULTMESSAGEDENYNOTIFICATIONTEXT]
                               [--showInGroupDirectory {true,false}]
                               [--allowGoogleCommunication {true,false}]
                               [--allowExternalMembers {true,false}]
                               [--allowWebPosting {true,false}]
                               [--primaryLanguage {ja,en-US}]
                               [--maxMessageBytes MAXMESSAGEBYTES]
                               [--isArchived {true,false}]
                               [--archiveOnly {true,false}] [--json]
                               [--jsonPretty]
                               groupUniqueId

positional arguments:
  groupUniqueId         group email address

optional arguments:
  -h, --help            show this help message and exit
  --whoCanInvite {ALL_MANAGERS_CAN_INVITE,ALL_MEMBERS_CAN_INVITE}
  --whoCanJoin {ANYONE_CAN_JOIN,ALL_IN_DOMAIN_CAN_JOIN,INVITED_CAN_JOIN,CAN_REQUEST_TO_JOIN}
  --whoCanPostMessage {ALL_IN_DOMAIN_CAN_POST,ALL_MANAGERS_CAN_POST,ALL_MEMBERS_CAN_POST,ANYONE_CAN_POST,NONE_CAN_POST}
  --whoCanViewGroup {ALL_IN_DOMAIN_CAN_VIEW,ALL_MANAGERS_CAN_VIEW,ALL_MEMBERS_CAN_VIEW,ANYONE_CAN_VIEW}
  --whoCanViewMembership {ALL_IN_DOMAIN_CAN_VIEW,ALL_MANAGERS_CAN_VIEW,ALL_MEMBERS_CAN_VIEW}
  --messageModerationLevel {MODERATE_ALL_MESSAGES,MODERATE_NON_MEMBERS,MODERATE_NEW_MEMBERS,MODERATE_NONE}
  --spamModerationLevel {ALLOW,MODERATE,SILENTLY_MODERATE,REJECT}
  --whoCanLeaveGroup {ALL_MANAGERS_CAN_LEAVE,ALL_MEMBERS_CAN_LEAVE}
  --whoCanContactOwner {ALL_IN_DOMAIN_CAN_CONTACT,ALL_MANAGERS_CAN_CONTACT,ALL_MEMBERS_CAN_CONTACT,ANYONE_CAN_CONTACT}
  --messageDisplayFont {DEFAULT_FONT,FIXED_WIDTH_FONT}
  --replyTo {REPLY_TO_CUSTOM,REPLY_TO_SENDER,REPLY_TO_LIST,REPLY_TO_OWNER,REPLY_TO_IGNORE,REPLY_TO_MANAGERS}
  --membersCanPostAsTheGroup {true,false}
  --includeInGlobalAddressList {true,false}
  --customReplyTo CUSTOMREPLYTO
                        Reply-To header (REPLY_TO_CUSTOM)
  --sendMessageDenyNotification {true,false}
  --defaultMessageDenyNotificationText DEFAULTMESSAGEDENYNOTIFICATIONTEXT
  --showInGroupDirectory {true,false}
  --allowGoogleCommunication {true,false}
  --allowExternalMembers {true,false}
  --allowWebPosting {true,false}
  --primaryLanguage {ja,en-US}
  --maxMessageBytes MAXMESSAGEBYTES
  --isArchived {true,false}
  --archiveOnly {true,false}
  --json                output in JSON
  --jsonPretty          output in pretty JSON
```

エイリアスの操作
--------

ユーザーとグループにはエイリアスが設定可能です。これはそれぞれ [user-alias.py](https://github.com/yteraoka/googleapps-directory-tools#usersaliases), [group-alias.py](https://github.com/yteraoka/googleapps-directory-tools#groupsaliases) で行います。

今後
--

必要になるか気が向いたら機能追加とかやっていきます。もしも「こんなツールが欲しかったんだよ」というかたがいらっしゃいましたら使っていただいてフィードバックをいただければと。Python はもっとこう書けとかいうアドバイスもお待ちしております。
