---
title: 'July Tech Festa の Chef / serverspec ハンズオンを家で試した #techfesta'
date: Fri, 19 Jul 2013 14:21:33 +0000
draft: false
tags: ['chef', 'vagrant', 'ハンズオン']
---

[July Tech Festa](http://www.techfesta.jp/) の Chef ハンズオン資料が[公開](http://tily.github.io/jtf2013/)されていたので家で試してみた。公開ありがとうございます。 Vagrant でテスト用環境を立ち上げる

```
$ mkdir chef
$ cd chef
$ vagrant init centos6 http://developer.nrel.gov/downloads/vagrant-boxes/CentOS-6.4-x86_64-v20130427.box
$ vagrant up
$ vagrant ssh
```

### 1.2. Chef Solo のインストール

インストール

```
$ curl -L https://www.opscode.com/chef/install.sh | sudo bash
```

試しに実行してみる

```
$ sudo chef-solo
[2013-07-19T12:54:08+00:00] WARN: *****************************************
[2013-07-19T12:54:08+00:00] WARN: Did not find config file: /etc/chef/solo.rb, using command line options.
[2013-07-19T12:54:08+00:00] WARN: *****************************************
Starting Chef Client, version 11.4.4
Compiling Cookbooks...
[2013-07-19T12:54:08+00:00] FATAL: No cookbook found in ["/var/chef/cookbooks", "/var/chef/site-cookbooks"], make sure cookbook_path is set correctly.
[2013-07-19T12:54:08+00:00] FATAL: No cookbook found in ["/var/chef/cookbooks", "/var/chef/site-cookbooks"], make sure cookbook_path is set correctly.
[2013-07-19T12:54:08+00:00] ERROR: Running exception handlers
[2013-07-19T12:54:08+00:00] ERROR: Exception handlers complete
Chef Client failed. 0 resources updated
[2013-07-19T12:54:08+00:00] FATAL: Stacktrace dumped to /var/chef/cache/chef-stacktrace.out
[2013-07-19T12:54:08+00:00] FATAL: Chef::Exceptions::CookbookNotFound: No cookbook found in ["/var/chef/cookbooks", "/var/chef/site-cookbooks"], make sure cookbook_path is set correctly.
```

### 2\. Chef Apply を試す

### 2.2. レシピの作成と実行

1つファイルを作るだけの簡単なレシピを書いてみる

```
$ cat <<_EOD_ > recipe.rb
file '/var/tmp/test.txt' do
  content "hello, world\n"
end
_EOD_
```

実行

```
$ sudo chef-apply recipe.rb
Recipe: (chef-apply cookbook)::(chef-apply recipe)
  * file[/var/tmp/test.txt] action create
    - create new file /var/tmp/test.txt with content checksum 853ff9
        --- /tmp/chef-tempfile20130719-1884-npeegm	2013-07-19 13:01:09.688309813 +0000
        +++ /tmp/chef-diff20130719-1884-uxn8m3	2013-07-19 13:01:09.688309813 +0000
        @@ -0,0 +1 @@
        +hello, world
```

作成されたファイルを確認

```
$ ls -l /var/tmp/test.txt 
-rw-r--r-- 1 root root 13 Jul 19 13:01 /var/tmp/test.txt
$ cat /var/tmp/test.txt 
hello, world
```

### 2.3. べき等性の確認

再実行してみる

```
$ sudo chef-apply recipe.rb
Recipe: (chef-apply cookbook)::(chef-apply recipe)
  * file[/var/tmp/test.txt] action create (up to date)
```

ファイルに変化なし

```
$ ls -l /var/tmp/test.txt 
-rw-r--r-- 1 root root 13 Jul 19 13:01 /var/tmp/test.txt
```

ファイルの内容を書き換えてから再実行してみる

```
$ sudo bash -c "echo hello nifty cloud > /var/tmp/test.txt"
$ cat /var/tmp/test.txt hello nifty cloud
$ sudo chef-apply recipe.rb
Recipe: (chef-apply cookbook)::(chef-apply recipe)
  * file[/var/tmp/test.txt] action create
    - update content in file /var/tmp/test.txt from bac308 to 853ff9
        --- /var/tmp/test.txt	2013-07-19 13:07:41.971353051 +0000
        +++ /tmp/chef-diff20130719-2119-b2zqpu	2013-07-19 13:09:10.647668845 +0000
        @@ -1 +1 @@
        -hello nifty cloud
        +hello, world
$ cat /var/tmp/test.txt 
hello, world
```

レシピを書き換えてみる

```
$ cat recipe.rb 
file '/var/tmp/test.txt' do
  content "hello, world\n"
end
$ sed -i -e 's/world/chef/' recipe.rb 
$ cat recipe.rb 
file '/var/tmp/test.txt' do
  content "hello, chef\n"
end
$ sudo chef-apply recipe.rb
Recipe: (chef-apply cookbook)::(chef-apply recipe)
  * file[/var/tmp/test.txt] action create
    - update content in file /var/tmp/test.txt from 853ff9 to 5b8079
        --- /var/tmp/test.txt	2013-07-19 13:14:11.097818719 +0000
        +++ /tmp/chef-diff20130719-2251-ptr0j5	2013-07-19 13:16:06.729605440 +0000
        @@ -1 +1 @@
        -hello, world
        +hello, chef
```

### 3\. Chef Solo で WordPress レシピ開発

### 3.1. Chef Solo 用の設定ファイル配置

```
$ sudo mkdir -p /var/chef/cookbooks
```

後で `knife cookbook site install` を実行するために git 管理にしておく

```
$ sudo yum -y install git
$ cd /var/chef/cookbooks
$ sudo git init .
$ sudo touch README
$ sudo git add README
$ sudo git commit -m "add readme."
```

### 3.2. WordPress レシピのダウンロード

Opscode のコミュニティサイトから knife で wordpress cookbook をダウンロード

```
$ sudo knife cookbook site install wordpress
```

なにやら沢山ダウンロードされました。

```
$ ls /var/chef/cookbooks/
apache2  build-essential  mysql  openssl  php  README  wordpress  xml
```

ブランチが切られている

```
$ cd /var/chef/cookbooks/
$ git branch
  chef-vendor-apache2
  chef-vendor-build-essential
  chef-vendor-mysql
  chef-vendor-openssl
  chef-vendor-php
  chef-vendor-wordpress
  chef-vendor-xml
* master
```

### 3.3. レシピ実行

```
$ cat <<_EOD_ > dna.json
{
  "run_list": ["recipe[wordpress]"],
  "mysql": {
    "server_root_password": "password",
    "server_debian_password": "password",
    "server_repl_password": "password"
  }
}
_EOD_
```

```
$ sudo chef-solo -j dna.json
{snip}
Chef Client finished, 106 resources updated
```

確認

```
$ curl -s -v http://localhost/
* About to connect() to localhost port 80 (#0)
*   Trying ::1... connected
* Connected to localhost (::1) port 80 (#0)
> GET / HTTP/1.1
> User-Agent: curl/7.19.7 (x86_64-redhat-linux-gnu) libcurl/7.19.7 NSS/3.13.6.0 zlib/1.2.3 libidn/1.18 libssh2/1.4.2
> Host: localhost
> Accept: */*
> 
< HTTP/1.1 302 Found
< Date: Fri, 19 Jul 2013 13:35:54 GMT
< Server: Apache
< X-Powered-By: PHP/5.3.3
< Location: http://localhost/wp-admin/install.php
< Vary: Accept-Encoding
< Content-Length: 0
< Content-Type: text/html
< 
* Connection #0 to host localhost left intact
* Closing connection #0
```

ふむふむ、インストールできているようだ

### 4\. レシピのテストを書く

### 4.1. serverspec のインストール

```
$ sudo /opt/chef/embedded/bin/gem install serverspec
Fetching: rspec-core-2.13.1.gem (100%)
Fetching: diff-lcs-1.2.4.gem (100%)
Fetching: rspec-expectations-2.13.0.gem (100%)
Fetching: rspec-mocks-2.13.1.gem (100%)
Fetching: rspec-2.13.0.gem (100%)
Fetching: serverspec-0.7.0.gem (100%)
Successfully installed rspec-core-2.13.1
Successfully installed diff-lcs-1.2.4
Successfully installed rspec-expectations-2.13.0
Successfully installed rspec-mocks-2.13.1
Successfully installed rspec-2.13.0
Successfully installed serverspec-0.7.0
6 gems installed
Installing ri documentation for rspec-core-2.13.1...
Installing ri documentation for diff-lcs-1.2.4...
Installing ri documentation for rspec-expectations-2.13.0...
Installing ri documentation for rspec-mocks-2.13.1...
Installing ri documentation for rspec-2.13.0...
Installing ri documentation for serverspec-0.7.0...
Installing RDoc documentation for rspec-core-2.13.1...
Installing RDoc documentation for diff-lcs-1.2.4...
Installing RDoc documentation for rspec-expectations-2.13.0...
Installing RDoc documentation for rspec-mocks-2.13.1...
Installing RDoc documentation for rspec-2.13.0...
Installing RDoc documentation for serverspec-0.7.0...
```

```
$ ls /opt/chef/embedded/bin/serverspec-init 
/opt/chef/embedded/bin/serverspec-init
```

```
$ /opt/chef/embedded/bin/serverspec-init
Select a backend type:

  1) SSH
  2) Exec (local)

Select number: 2

 + spec/
 + spec/localhost/
 + spec/localhost/httpd_spec.rb
 + spec/spec_helper.rb
 + Rakefile
```

### 4.2. httpd のテストを修正

そのままでは `rake spec` に失敗する

```
$ /opt/chef/embedded/bin/rake spec
/opt/chef/embedded/bin/ruby -S rspec spec/localhost/httpd_spec.rb
..F..F

Failures:

  1) Service "httpd" 
     Failure/Error: it { should be_running   }
       service httpd status
       httpd dead but subsys locked
       expected Service "httpd" to be running
     # ./spec/localhost/httpd_spec.rb:9:in `block (2 levels) in '

  2) File "/etc/httpd/conf/httpd.conf" 
     Failure/Error: it { should contain "ServerName localhost" }
       grep -q -- ServerName\ localhost /etc/httpd/conf/httpd.conf
       expected File "/etc/httpd/conf/httpd.conf" to contain "ServerName localhost"
     # ./spec/localhost/httpd_spec.rb:18:in `block (2 levels) in '

Finished in 0.10016 seconds
6 examples, 2 failures

Failed examples:

rspec ./spec/localhost/httpd_spec.rb:9 # Service "httpd" 
rspec ./spec/localhost/httpd_spec.rb:18 # File "/etc/httpd/conf/httpd.conf" 
rake aborted!
/opt/chef/embedded/bin/ruby -S rspec spec/localhost/httpd_spec.rb failed

Tasks: TOP => spec
(See full trace by running task with --trace) 
```

ので、とりあえずエラーにならないようにテストの方を書き換える 1つ目のエラーは service コマンドは root で実行する必要があったため。

```
$ sed -i -e '/ServerName localhost/d' spec/localhost/httpd_spec.rb 
```

```
$ sudo /opt/chef/embedded/bin/rake spec
/opt/chef/embedded/bin/ruby -S rspec spec/localhost/httpd_spec.rb
.....

Finished in 0.08218 seconds
5 examples, 0 failures
```

### 4.3. mysqld のテストを作成

* mysql-server パッケージがインストールされていること
* mysqld デーモンが有効化されていること (chkconfig mysqld on されていること)
* mysqld デーモンが起動していること
* 3306 ポートが LISTEN していること

httpd\_spec.rb をコピーしてちょっと書き換えればできた。

```
cp spec/localhost/{httpd,mysqld}_spec.rb
vi spec/localhost/mysqld_spec.rb
```

次は serverspec のドキュメント を参照しながら

* http://localhost/wp-admin/install.php にアクセスすると "Welcome to the famous five minute WordPress installation process!" という文字列が表示されること

を確認するテストを書きます

```
$ vi spec/localhost/wordpress_spec.rb
```

```
$ sudo /opt/chef/embedded/bin/rake spec
/opt/chef/embedded/bin/ruby -S rspec spec/localhost/httpd_spec.rb spec/localhost/mysqld_spec.rb spec/localhost/wordpress_spec.rb
..........

Finished in 0.47343 seconds
10 examples, 0 failures
```

でけた。

### 5\. CloudAutomation β で自動化！

これは省略。 さて次はこれと同じ事を Ansible で行うハンズオン資料を書いてみよう。
