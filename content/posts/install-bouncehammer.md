---
title: 'BounceHammerを試してみた (インストール編)'
date: Thu, 10 Jan 2013 15:02:36 +0000
draft: false
tags: ['Linux', 'SMTP', 'mail', 'Perl']
---

その昔、SoftwareDesign 2010年11月号 で見たメールのエラーリターンを管理する仕組み BounceHammer を2年の年月を隔てて試してみた。 [オープンソースのバウンスメール解析システム BounceHammer：メール｜gihyo.jp … 技術評論社](http://gihyo.jp/admin/column/01/mail/2010/bouncehammer) 各社それぞれの思惑で実装されたエラーメールはそれはそれはバリエーションに富んでおり、これの Parser を書くのは大変骨の折れる作業だから、これはとてもありがたい。 これまで試さなかったのは、Perl のモジュール沢山いれるの嫌だなというのが原因なのと、一応それらしく動いているっぽい独自の仕組みが存在したから。でも誰もメンテしないのでなんか怪しくなってきた。そこで過去の記憶をたどり試してみることにした。 cpanm を覚えた今 ( [いまさら cpanm](/2013/01/%E3%81%84%E3%81%BE%E3%81%95%E3%82%89-cpanm/) ) となっては、インストールはとっても簡単。 CentOS 6 の /opt/bouncehammer にインストールする方法 Perl の Module 読み込みのための環境変数設定

```
$ echo "export PERL5OPT=\"-I~/bouncehammer/lib/perl5 -I~/bouncehammer/lib/perl5/$(perl -MConfig -e 'print $Config{archname}')\"" >> .bashrc
```

```
$ wget http://dist.bouncehammer.jp/bouncehammer-2.7.9.tar.gz
$ tar zxvf bouncehammer-2.7.9.tar.gz
$ cd bouncehammer-2.7.9
$ mkdir ~/bouncehammer
$ perl Modules.PL missing | awk '{print $4}' | cpanm -l ~/bouncehammer
$ ./configure --prefix=~/bouncehammer
$ make
$ make test
$ make install
```

DB は PostgreSQL にしておく (標準の yum のはいまだに 8.4 だけど)、MySQL でも OK

```
$ sudo yum install postgresql-devel postgresql-server
$ cpanm -l ~/bouncehammer DBD::Pg
$ sudo -u postgres initdb -E utf8 --locale=ja_JP.utf8 -D /var/lib/pgsql/data
$ sudo /sbin/chkconfig postgresql on
$ sudo /sbin/service postgresql start
$ sudo -u postgres createuser bouncehammer
$ sudo -u postgres createdb -E utf8 -O bouncehammer bouncehammer
$ cat ~/bouncehammer/share/script/PostgreSQL*.sql | psql -U bouncehammer bouncehammer
$ cat ~/bouncehammer/share/script/mastertable-*.sql | psql -U bouncehammer bouncehammer
```

BounceHammer 設定

```
$ cd ~/bouncehammer/etc
$ cp available-countries{-example,}
$ cp bouncehammer.cf{-example,}
$ touch neighbor-domains
$ cp webui.cf{-example,}
$ vi bouncehammer.cf
$ vi webui.cf
```

送信元メールアドレスの domain 登録

```
$ ~/bouncehammer/bin/tablectl --insert -ts --name example.com
```

確認

```
$ ~/bouncehammer/bin/tablectl --list -ts -Fa
.----------------------------------------------.
|                 SenderDomains                |
+-----+---------------+-------------+----------+
| #ID | domainname    | description | disabled |
+-----+---------------+-------------+----------+
|   1 | m3.com        |             |        0 |
|   2 | askdoctors.jp |             |        0 |
'-----+---------------+-------------+----------'
```

メールの取り込みは fetchmail & procmail

```bash
$ sudo yum install fetchmail procmail
$ cat > ~/.fetchmailrc <<_EOD_
set no bouncemail

defaults
 uidl
 no mimedecode
 keep

poll メールサーバー名
 protocol pop3
 user ユーザー名
 password パスワード
 smtphost localhost
 mda /usr/bin/procmail
_EOD_

$ cat > ~/.procmailrc <<_EOD_
MAILDIR=$HOME/Maildir
DEFAULT=$MAILDIR/
LOCKFILE=$HOME/procmail.lock
$LOGFILE=$HOME/procmail.log
_EOD_
```

メール受信

```
$ fetchmail --ssl
```

これでメールが ~/Maildir/new/ に溜まる (.fetchmailrc に keep と書いているため、メールサーバーからは削除しないので ~/.fetchids に受信済み UIDL が保存される) Web Interface は Apache + CGI (mod\_perl も可能)

```
$ sudo yum install httpd
$ sudo cp ~/bouncehammer/share/script/bouncehammer.cgi /var/www/cgi-bin/
$ sudo cp ~/bouncehammer/share/script/api.cgi /var/www/cgi-bin/
$ sudo chmod 755 /var/www/cgi-bin/{bouncehammer,api}.cgi
$ sudo vi /var/www/cgi-bin/{bouncehammer,api}.cgi
   use lib '/home/xxx/bouncehammer/lib';
     ↓
   use lib qw(/home/xxx/bouncehammer/lib /home/xxx/bouncehammer/lib/perl5);
```

リターンメールを BounceHammer に登録

```
$ ~/bouncehammer/bin/mailboxparser -g --log ~/Maildir/new --remove
(~/bouncehammer/var/spool/ にデータが溜まる)

$ ~/bouncehammer/bin/logger -c --remove
(spool のデータから var/log/hammer.YYYY-MM-DD.log を生成)

$ ~/bouncehammer/bin/databasectl --update --today
(log/hammer.YYYY-MM-DD.log の当日分をDBに登録)

$ ~/bouncehammer/bin/databasectl --update --yesterday
(log/hammer.YYYY-MM-DD.log の前日分をDBに登録)
```

初回は全部登録させる

```bash
$ for f in ~/bouncehammer/var/log/*.log
do
  ~/bouncehammer/bin/databasectl --update $f
done
```

海外のMTAからのメールとか、ひどい実装のMTAが変なリターンメールを送ってくるから UTF-8 じゃねーよと言われてDBに登録できないことがあるのにちょっと対応が必要かな
