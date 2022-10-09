---
title: '389-ds のセットアップ'
date: 
draft: true
tags: ['未分類']
---

### 389 DS のインストール

```
sudo yum -y install 389-ds-base
```

### セットアップの準備

```
127.0.0.1   **ldap.example.com** localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
```

▲ テストで ldap.example.com を使うことにする、正逆一致していないとセットアップでコケるので 127.0.0.1 の最初に入れておく

### セットアップ

```
sudo /usr/sbin/setup-ds.pl
```

▲ `setup-ds.pl` を引数なしで実行すると対話形式でのセットアップが始まる

```
This program will set up the 389 Directory Server.

It is recommended that you have "root" privilege to set up the software.
Tips for using this  program:
  - Press "Enter" to choose the default and go to the next screen
  - Type "Control-B" or the word "back" then "Enter" to go back to the previous screen
  - Type "Control-C" to cancel the setup program

Would you like to continue with set up? [yes]:
```

▲ 中断するには **Control-C** を、戻るには **Control-B** か **back** とタイプせよと

```
Your system has been scanned for potential problems, missing patches,
etc.  The following output is a report of the items found that need to
be addressed before running this software in a production
environment.

389 Directory Server system tuning analysis version 14-JULY-2016.

NOTICE : System is x86_64-unknown-linux3.10.0-862.14.4.el7.x86_64 (1 processor).

WARNING: There are only 1024 file descriptors (soft limit) available, which
limit the number of simultaneous connections.

WARNING  : The warning messages above should be reviewed before proceeding.

Would you like to continue? [no]: yes
```

▲ ファイルディスクリプタの上限が小さいよを警告されているが、systemd で起動する場合は systemd の設定で大きく指定されているので気にしないで **yes** で進める

```
Choose a setup type:

   1. Express
       Allows you to quickly set up the servers using the most
       common options and pre-defined defaults. Useful for quick
       evaluation of the products.

   2. Typical
       Allows you to specify common defaults and options.

   3. Custom
       Allows you to specify more advanced options. This is
       recommended for experienced server administrators only.

To accept the default shown in brackets, press the Enter key.

Choose a setup type [2]:
```

▲ とりあえず **Typical** で進める

```
Enter the fully qualified domain name of the computer
on which you're setting up server software. Using the form
. Example: eros.example.com.

To accept the default shown in brackets, press the Enter key.

Warning: This step may take a few minutes if your DNS servers
can not be reached or if DNS is not configured correctly.  If
you would rather not wait, hit Ctrl-C and run this program again
with the following command line option to specify the hostname:

    General.FullMachineName=your.hostname.domain.name

Computer name [localhost.localdomain]: ldap.example.com
```

▲ サーバーの FQDN を指定する

```
The server must run as a specific user in a specific group.
It is strongly recommended that this user should have no privileges
on the computer (i.e. a non-root user).  The setup procedure
will give this user/group some permissions in specific paths/files
to perform server-specific operations.

If you have not yet created a user and group for the server,
create this user and group using your native operating
system utilities.

System User [dirsrv]:
System Group [dirsrv]:
```

▲ サーバーの実行ユーザーを指定（デフォルトのまま）

```
The standard directory server network port number is 389.  However, if
you are not logged as the superuser, or port 389 is in use, the
default value will be a random unused port number greater than 1024.
If you want to use port 389, make sure that you are logged in as the
superuser, that port 389 is not in use.

Directory server network port [389]:
```

▲ サーバーの Listen port を指定、LDAP の標準ポートが 389 なのでそのまま

```
Each instance of a directory server requires a unique identifier.
This identifier is used to name the various
instance specific files and directories in the file system,
as well as for other uses as a server instance identifier.

Directory server identifier [ldap]:
```

▲ サーバーの識別子（FQDN の最初のパートがデフォルトかな？）

```
The suffix is the root of your directory tree.  The suffix must be a valid DN.
It is recommended that you use the dc=domaincomponent suffix convention.
For example, if your domain is example.com,
you should use dc=example,dc=com for your suffix.
Setup will create this initial suffix for you,
but you may have more than one suffix.
Use the directory server utilities to create additional suffixes.

Suffix [dc=example, dc=com]:
```

▲ ドメイン指定

```
Certain directory server operations require an administrative user.
This user is referred to as the Directory Manager and typically has a
bind Distinguished Name (DN) of cn=Directory Manager.
You will also be prompted for the password for this user.  The password must
be at least 8 characters long, and contain no spaces.
Press Control-B or type the word "back", then Enter to back up and start over.

Directory Manager DN [cn=Directory Manager]:
Password:
Password (confirm):
Your new DS instance 'ldap' was successfully created.
Exiting . . .
Log file is '/tmp/setupIMTRQh.log'
```

▲ ディレクトリマネージャーアカウトのID、パスワードを指定 これで、LDAP サーバーが起動している（`@` が使われているので identifier と port を別にすれば同一ホストに複数サーバーを起動することができそうです）

```
$ sudo systemctl status dirsrv@ldap
● dirsrv@ldap.service - 389 Directory Server ldap.
   Loaded: loaded (/usr/lib/systemd/system/dirsrv@.service; enabled; vendor preset: disabled)
   Active: active (running) since Sat 2018-11-17 12:34:25 UTC; 5min ago
  Process: 6858 ExecStartPre=/usr/sbin/ds_systemd_ask_password_acl /etc/dirsrv/slapd-%i/dse.ldif (code=exited, status=0/SUCCESS)
 Main PID: 6864 (ns-slapd)
   Status: "slapd started: Ready to process requests"
   CGroup: /system.slice/system-dirsrv.slice/dirsrv@ldap.service
           └─6864 /usr/sbin/ns-slapd -D /etc/dirsrv/slapd-ldap -i /var/run/dirsrv/slapd-ldap.pid
```

### 生成されるファイル

```
/etc/tmpfiles.d/dirsrv-ldap.conf
/etc/dirsrv/slapd-ldap/dse.ldif.bak
/etc/dirsrv/slapd-ldap/key3.db
/etc/dirsrv/slapd-ldap/certmap.conf
/etc/dirsrv/slapd-ldap/dse_original.ldif
/etc/dirsrv/slapd-ldap/schema/99user.ldif
/etc/dirsrv/slapd-ldap/dse.ldif
/etc/dirsrv/slapd-ldap/dse.ldif.startOK
/etc/dirsrv/slapd-ldap/cert8.db
/etc/dirsrv/slapd-ldap/slapd-collations.conf
/etc/dirsrv/slapd-ldap/secmod.db
/etc/sysconfig/dirsrv-ldap
```

DB は `/var/lib/dirsrv/slapd-ldap/` 配下に生成され、ログは `/var/log/dirsrv/slapd-ldap/` 配下に出力されます。

### インスタンスの削除

```
$ sudo /usr/sbin/remove-ds.pl -i slapd-ldap
Instance slapd-ldap removed.
```

一部のファイルはリネームされて残されていました

```
/etc/dirsrv/slapd-ldap.removed/key3.db
/etc/dirsrv/slapd-ldap.removed/cert8.db
/etc/dirsrv/slapd-ldap.removed/secmod.db
```

### 非対話型セットアップ

```
sudo /usr/sbin/setup-ds.pl --keepcache
```

と、`--keepcache` をつけて実行すると `/tmp/setup*.inf` ファイルが残されるのでこのファイルを使うと非対話型セットアップが実行できます

```
sudo /usr/sbin/setup-ds.pl --file=xxx.inf --silent
```

今回の例では INF ファイルの中身は次のようになっていました

```ini
[General]
FullMachineName = ldap.example.com
ServerRoot = /usr/lib64/dirsrv
StrictHostCheck = true
SuiteSpotGroup = dirsrv
SuiteSpotUserID = dirsrv
[slapd]
AddOrgEntries = Yes
AddSampleEntries = No
HashedRootDNPwd = {SSHA512}o8jXqzruhMvlMhRcr192O/p4COdcRG95kX0I0ruNM/DJhVZxaJE9IVyQ2ik8N40fyfUfR+Phj/8WPykp2WSUhnynsqLvEbrF
InstScriptsEnabled = true
InstallLdifFile = suggest
RootDN = cn=Directory Manager
RootDNPwd = password
ServerIdentifier = ldap
ServerPort = 389
Suffix = dc=example,dc=com
bak_dir = /var/lib/dirsrv/slapd-ldap/bak
bindir = /usr/bin
cert_dir = /etc/dirsrv/slapd-ldap
config_dir = /etc/dirsrv/slapd-ldap
datadir = /usr/share
db_dir = /var/lib/dirsrv/slapd-ldap/db
ds_bename = userRoot
inst_dir = /usr/lib64/dirsrv/slapd-ldap
ldif_dir = /var/lib/dirsrv/slapd-ldap/ldif
localstatedir = /var
lock_dir = /var/lock/dirsrv/slapd-ldap
log_dir = /var/log/dirsrv/slapd-ldap
naming_value = example
run_dir = /var/run/dirsrv
sbindir = /usr/sbin
schema_dir = /etc/dirsrv/slapd-ldap/schema
sysconfdir = /etc
tmp_dir = /tmp
```
