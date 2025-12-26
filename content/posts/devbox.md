---
title: "Devbox を使った開発環境"
date: 2023-03-05T00:05:12+09:00
tags: ["devbox", "Ruby", "Python", "PostgreSQL"]
draft: false
---

[ローカル環境を汚さずDockerコンテナのオーバーヘッドもなく、開発環境を自在に構築できる「Devbox 0.2.0」登場 － Publickey](https://www.publickey1.jp/blog/22/dockerdevbox_020.html)

この記事を最初に見たときは「えーそんなのコンテナじゃないじゃん」とか思って不要じゃね？って思ってたんですが、Rails を少し触ることになって macOS 上での docker の遅さに辟易してきたので devbox を思い出し、使ってみることにしました。

[https://www.jetpack.io/devbox/](https://www.jetpack.io/devbox/)

## Devbox のインストール

```
curl -fsSL https://get.jetpack.io/devbox | bash
```

## 初期化

プロジェクトの開発用のディレクトリで `devbox init` を実行します。

```bash
$ devbox init
✓ Downloading version 0.4.2... [DONE]
✓ Verifying checksum... [DONE]
✓ Unpacking binary... [DONE]

? Do you want to enable direnv integration for this devbox project? [y/N]
```

これで `devbox.json` ファイルが作成されます。(direnv を有効にしておくと便利ですが、ここでは無効のまま進めます。後で `devbox generate direnv` コマンドを実行すれば `.envrc` を作成できる。)

```json
{
  "packages": [],
  "shell": {
    "init_hook": null
  },
  "nixpkgs": {
    "commit": "f80ac848e3d6f0c12c52758c0f25c10c97ca3b62"
  }
}
```

nixpkgs.commit で git の hash が指定されていることで、このファイルを元に devbox を使えば誰の環境でも同じバージョンがインストールされることが保障されるようです。

## Ruby をインストール

ここに Ruby をインストールしてみます。

```bash
$ devbox add ruby
Installing nix packages.
    this derivation will be built:
      /nix/store/kzhm3ccb4n76djyl8p031nrwqjkhb3y8-devbox-development.drv
    this path will be fetched (4.05 MiB download, 17.84 MiB unpacked):
      /nix/store/68b23xs1x21037lspz52dh5ck7w7wqg7-ruby-2.7.6
    copying path '/nix/store/68b23xs1x21037lspz52dh5ck7w7wqg7-ruby-2.7.6' from 'https://cache.nixos.org'...
    building '/nix/store/kzhm3ccb4n76djyl8p031nrwqjkhb3y8-devbox-development.drv'...
    created 18 symlinks in user environment
    building '/nix/store/frxp5w9pziibvajnc10bvspaa7hmslma-user-environment.drv'...

This plugin sets the following environment variables:
* RUBY_CONFDIR=/Users/teraoka/work/rails-devbox/.devbox/virtenv/ruby
* GEMRC=/Users/teraoka/work/rails-devbox/.devbox/virtenv/ruby/.gemrc
* GEM_HOME=/Users/teraoka/work/rails-devbox/.devbox/virtenv/ruby

To show this information, run `devbox info ruby`

ruby (ruby-2.7.6) is now installed.
```

この記事を書いている時点ではデフォルトは Ruby 2.7 のようです。

もうちょい新しいバージョンを使いたいので入れ直します。

```bash
$ devbox rm ruby
Uninstalling nix packages.
ruby (ruby-2.7.6) is now removed.
```

最新の Ruby は 3.2.1 ですが、devbox では 3.1.x が最新のようです。

```bash
$ devbox add ruby_3_2
error: attribute 'ruby_3_2' in selection path 'ruby_3_2' not found
       Did you mean one of ruby_3_0, ruby_3_1 or ruby_2_7?

Error: ruby_3_2: package not found

To search for packages use https://search.nixos.org/packages
```

https://www.jetpack.io/devbox/docs/devbox_examples/languages/ruby/

```bash
$ devbox add ruby_3_1
Installing nix packages.
    this derivation will be built:
      /nix/store/i5kw0js4xzh7imibp2mznrf75517bg20-devbox-development.drv
    building '/nix/store/i5kw0js4xzh7imibp2mznrf75517bg20-devbox-development.drv'...
    created 19 symlinks in user environment
    building '/nix/store/j9jkl4kjlf1r6l64jxayhi4pnzk8dd90-user-environment.drv'...

This plugin sets the following environment variables:
* RUBY_CONFDIR=/Users/teraoka/work/rails-devbox/.devbox/virtenv/ruby_3_1
* GEMRC=/Users/teraoka/work/rails-devbox/.devbox/virtenv/ruby_3_1/.gemrc
* GEM_HOME=/Users/teraoka/work/rails-devbox/.devbox/virtenv/ruby_3_1

To show this information, run `devbox info ruby_3_1`

ruby_3_1 (ruby-3.1.2) is now installed.
```

これで ruby 3.1.2 がインストールされたわけですが、このままでは `ruby` を実行してもここでインストールした Ruby が使われません。

```
$ which ruby
/usr/bin/ruby
```

devbox.json には packages の中に `ruby_3_1` が追加されています。

```json
{
  "packages": [
    "ruby_3_1"
  ],
  "shell": {
    "init_hook": null
  },
  "nixpkgs": {
    "commit": "f80ac848e3d6f0c12c52758c0f25c10c97ca3b62"
  }
}
```


## 環境に入る

まだ Ruby しか入れてませんが、`devbox add` でインストールしたものを使うためには `devbox shell` を実行します。

```bash
$ devbox shell
Ensuring packages are installed.
Starting a devbox shell...
```

これで必要な環境変数が設定された状態の shell に入っています。抜ける場合は `exit` や `Ctrl-D` です。

`which ruby` を実行するとこんな場所の ruby が使われることになっています。

```bash
$ which ruby
/nix/store/l4wmx8lfn6hlcfmbyhmksm024f8hixm1-ruby-3.1.2/bin/ruby
```

`PATH` 環境変数をで `/nix` から始まるものを確認してみます。

```bash
$ echo $PATH | sed 's/:/\n/g' | grep /nix
/nix/store/l4wmx8lfn6hlcfmbyhmksm024f8hixm1-ruby-3.1.2/bin
/nix/store/ahk80g4lqv6qh2jk2p0ggzq9rv4bn225-clang-wrapper-11.1.0/bin
/nix/store/06lsfl4m6njbpazdg5plfnpqnl63cnap-clang-11.1.0/bin
/nix/store/aldzp4nyc8bh298rdn322vjkbl0rhzvd-coreutils-9.1/bin
/nix/store/d73lqqzmsr1lmcn5n7l1axkdn0f87d0h-cctools-binutils-darwin-wrapper-973.0.1/bin
/nix/store/9yrcjsmixpdixxizicr283gh15gx223b-cctools-binutils-darwin-973.0.1/bin
/nix/store/774p215bpvwknjwamilpwvh4p3693jgx-findutils-4.9.0/bin
/nix/store/m94cfkc4h75b5za553xq3b7hakjz73pq-diffutils-3.8/bin
/nix/store/pky0yxv00gfmj285wgylax4hl1n4fh91-gnused-4.9/bin
/nix/store/qlnlyri7zhki0sry772ya72ba8w3diq8-gnugrep-3.7/bin
/nix/store/br47bnv28g9wn7cp5az8y4ljh38a1wh9-gawk-5.2.1/bin
/nix/store/lws0p7smg585mlmxyhp2n6m1ar13m5p0-gnutar-1.34/bin
/nix/store/3d9rywizccxy7lkm2wr6lpbg4imzl3dl-gzip-1.12/bin
/nix/store/9rbs940q589kpvhqjjqhf8byp63wkfww-bzip2-1.0.8-bin/bin
/nix/store/2rx6bfjaz079hsri7n3zbqai8jw9vswc-gnumake-4.4/bin
/nix/store/1icxmg6cq1xcv7mkry7ra1i21x8k9cjf-bash-5.2-p15/bin
/nix/store/p0051sa7s8mg6f8zk54jp25pj654ds4h-patch-2.7.6/bin
/nix/store/pd2igmbgi4fl5gpkf9w31qdw5vw09lck-xz-5.4.0-bin/bin
/nix/store/8z0l0aw1f8dx5l1a0h39j6k5q5wfyas7-file-5.43/bin
/nix/var/nix/profiles/default/bin
```

package ごとに別々のディレクトリにインストールされた形になっており、PATH に沢山追加されています。

PATH 以外も見てみます。

```bash
$ env | grep /nix/ | grep -v ^PATH= | sort
CONFIG_SHELL=/nix/store/1icxmg6cq1xcv7mkry7ra1i21x8k9cjf-bash-5.2-p15/bin/bash
GEM_PATH=/nix/store/l4wmx8lfn6hlcfmbyhmksm024f8hixm1-ruby-3.1.2/lib/ruby/gems/3.1.0
HOST_PATH=/nix/store/aldzp4nyc8bh298rdn322vjkbl0rhzvd-coreutils-9.1/bin:/nix/store/774p215bpvwknjwamilpwvh4p3693jgx-findutils-4.9.0/bin:/nix/store/m94cfkc4h75b5za553xq3b7hakjz73pq-diffutils-3.8/bin:/nix/store/pky0yxv00gfmj285wgylax4hl1n4fh91-gnused-4.9/bin:/nix/store/qlnlyri7zhki0sry772ya72ba8w3diq8-gnugrep-3.7/bin:/nix/store/br47bnv28g9wn7cp5az8y4ljh38a1wh9-gawk-5.2.1/bin:/nix/store/lws0p7smg585mlmxyhp2n6m1ar13m5p0-gnutar-1.34/bin:/nix/store/3d9rywizccxy7lkm2wr6lpbg4imzl3dl-gzip-1.12/bin:/nix/store/9rbs940q589kpvhqjjqhf8byp63wkfww-bzip2-1.0.8-bin/bin:/nix/store/2rx6bfjaz079hsri7n3zbqai8jw9vswc-gnumake-4.4/bin:/nix/store/1icxmg6cq1xcv7mkry7ra1i21x8k9cjf-bash-5.2-p15/bin:/nix/store/p0051sa7s8mg6f8zk54jp25pj654ds4h-patch-2.7.6/bin:/nix/store/pd2igmbgi4fl5gpkf9w31qdw5vw09lck-xz-5.4.0-bin/bin:/nix/store/8z0l0aw1f8dx5l1a0h39j6k5q5wfyas7-file-5.43/bin
NIX_BINTOOLS=/nix/store/d73lqqzmsr1lmcn5n7l1axkdn0f87d0h-cctools-binutils-darwin-wrapper-973.0.1
NIX_CC=/nix/store/ahk80g4lqv6qh2jk2p0ggzq9rv4bn225-clang-wrapper-11.1.0
NIX_CFLAGS_COMPILE= -frandom-seed=1aq9kj7l40 -isystem /nix/store/l4wmx8lfn6hlcfmbyhmksm024f8hixm1-ruby-3.1.2/include -isystem /nix/store/ybmfy7bxzzp4jjx7fpxsqy9px6396k29-libcxx-11.1.0-dev/include -isystem /nix/store/57i6imd3clhwcdbv451vakxyl5lfq495-libcxxabi-11.1.0-dev/include -isystem /nix/store/l6iswd551p01acd9p83fkwzlha3yw6bx-compiler-rt-libc-11.1.0-dev/include -iframework /nix/store/q7l7lhds9saxx3aa2d64hcahiy5k4f3s-swift-corefoundation-unstable-2018-09-14/Library/Frameworks -isystem /nix/store/l4wmx8lfn6hlcfmbyhmksm024f8hixm1-ruby-3.1.2/include -isystem /nix/store/ybmfy7bxzzp4jjx7fpxsqy9px6396k29-libcxx-11.1.0-dev/include -isystem /nix/store/57i6imd3clhwcdbv451vakxyl5lfq495-libcxxabi-11.1.0-dev/include -isystem /nix/store/l6iswd551p01acd9p83fkwzlha3yw6bx-compiler-rt-libc-11.1.0-dev/include -iframework /nix/store/q7l7lhds9saxx3aa2d64hcahiy5k4f3s-swift-corefoundation-unstable-2018-09-14/Library/Frameworks
NIX_COREFOUNDATION_RPATH=/nix/store/q7l7lhds9saxx3aa2d64hcahiy5k4f3s-swift-corefoundation-unstable-2018-09-14/Library/Frameworks
NIX_LDFLAGS= -L/nix/store/l4wmx8lfn6hlcfmbyhmksm024f8hixm1-ruby-3.1.2/lib -L/nix/store/x13469darccfi8d26zjgvgcv49r18hkn-libcxx-11.1.0/lib -L/nix/store/kngsbg02d7jw527pn5vx8s4wcsdgrmr3-libcxxabi-11.1.0/lib -L/nix/store/hnszpmz6qjf17fn6jjr31c96fgcsrxf6-compiler-rt-libc-11.1.0/lib -L/nix/store/l4wmx8lfn6hlcfmbyhmksm024f8hixm1-ruby-3.1.2/lib -L/nix/store/x13469darccfi8d26zjgvgcv49r18hkn-libcxx-11.1.0/lib -L/nix/store/kngsbg02d7jw527pn5vx8s4wcsdgrmr3-libcxxabi-11.1.0/lib -L/nix/store/hnszpmz6qjf17fn6jjr31c96fgcsrxf6-compiler-rt-libc-11.1.0/lib
NIX_PROFILES=/nix/var/nix/profiles/default /Users/teraoka/.nix-profile
NIX_SSL_CERT_FILE=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt
NIX_STORE=/nix/store
PATH_LOCALE=/nix/store/99dx3s639mrkaclnx6xdjw7lmjr64gxc-adv_cmds-119-locale/share/locale
RUBYLIB=/nix/store/l4wmx8lfn6hlcfmbyhmksm024f8hixm1-ruby-3.1.2/lib/ruby/site_ruby:/nix/store/l4wmx8lfn6hlcfmbyhmksm024f8hixm1-ruby-3.1.2/lib/ruby/site_ruby/3.1.0
XDG_DATA_DIRS=/nix/store/l4wmx8lfn6hlcfmbyhmksm024f8hixm1-ruby-3.1.2/share
_=/nix/store/aldzp4nyc8bh298rdn322vjkbl0rhzvd-coreutils-9.1/bin/env
builder=/nix/store/1icxmg6cq1xcv7mkry7ra1i21x8k9cjf-bash-5.2-p15/bin/bash
nativeBuildInputs=/nix/store/l4wmx8lfn6hlcfmbyhmksm024f8hixm1-ruby-3.1.2
out=/nix/store/1aq9kj7l40g0rza7s5k1abaakrzcw1c2-nix-shell-env
shell=/nix/store/1icxmg6cq1xcv7mkry7ra1i21x8k9cjf-bash-5.2-p15/bin/bash
stdenv=/nix/store/ibgiw134amh5hj4znpay84s7dlb550yj-stdenv-darwin
```

コンパイラやリンカが `CFLAGS` や `LDFLAGS` に加えて `NIX_CFLAGS` や `NIX_LDFLAGS` も参照するようになっているのかな？

これによってコンパイルの必要な C 拡張の gem なども使えるようになっています。

### rails をインストール

gem コマンドももちろん入っているので

```
$ which gem
/nix/store/l4wmx8lfn6hlcfmbyhmksm024f8hixm1-ruby-3.1.2/bin/gem
```

`gem install rails` します。

```bash
gem install rails
```

`devbox add ruby_3_1` 実行時の出力に次のものがありました。

```
RUBY_CONFDIR=/Users/teraoka/work/rails-devbox/.devbox/virtenv/ruby_3_1
GEMRC=/Users/teraoka/work/rails-devbox/.devbox/virtenv/ruby_3_1/.gemrc
GEM_HOME=/Users/teraoka/work/rails-devbox/.devbox/virtenv/ruby_3_1
```

ということで、そこにインストールされています。

```
$ ls .devbox/virtenv/ruby_3_1/bin
nokogiri  rackup  rails  thor

$ ls .devbox/virtenv/ruby_3_1/gems
actioncable-7.0.4.2    activestorage-7.0.4.2  mail-2.8.1                     rails-dom-testing-2.0.3
actionmailbox-7.0.4.2  activesupport-7.0.4.2  marcel-1.0.2                   rails-html-sanitizer-1.5.0
actionmailer-7.0.4.2   builder-3.2.4          method_source-1.0.0            railties-7.0.4.2
actionpack-7.0.4.2     concurrent-ruby-1.2.2  mini_mime-1.1.2                thor-1.2.1
actiontext-7.0.4.2     crass-1.0.6            nio4r-2.5.8                    tzinfo-2.0.6
actionview-7.0.4.2     erubi-1.12.0           nokogiri-1.14.2-x86_64-darwin  websocket-driver-0.7.5
activejob-7.0.4.2      globalid-1.1.0         rack-2.2.6.3                   websocket-extensions-0.1.5
activemodel-7.0.4.2    i18n-1.12.0            rack-test-2.0.2                zeitwerk-2.6.7
activerecord-7.0.4.2   loofah-2.19.1          rails-7.0.4.2
```

`which rails` で出てこなければ `rehash` を実行。

## nodejs をインストール

Rails では nodejs も必要となるので追加します。

```bash
$ devbox add nodejs-18_x
Installing nix packages.
    this derivation will be built:
      /nix/store/0crzc6ilmg4lm8kj9mfv59kzn847rabm-devbox-development.drv
    building '/nix/store/0crzc6ilmg4lm8kj9mfv59kzn847rabm-devbox-development.drv'...
    created 99 symlinks in user environment
    building '/nix/store/38h0q2ix2vra62py8phr85k3sbsnc6cy-user-environment.drv'...
nodejs-18_x (nodejs-18.13.0) is now installed.

To update your shell and ensure your new packages are usable, please run:

eval $(devbox shellenv)
```

すでに `devbox shell` を実行した状態で行なっているので `eval $(devbox shellenv)` で更新しろと表示されています。

`PATH` に `/nix/store/6km55cr5bkg2n40xxdb3kckkxg1wjzbm-nodejs-18.13.0/bin` が追加されました。
他の環境変数にも追加されたものがあります。

## yarn をインストール

もう同じですね

```bash
$ devbox add yarn
Installing nix packages.
    this derivation will be built:
      /nix/store/xj4bj2xi7mk6iqklwrb3pjknvgw4g96z-devbox-development.drv
    this path will be fetched (0.85 MiB download, 5.08 MiB unpacked):
      /nix/store/3qr0nz4gj73cwybvbagcsj1px7h5723r-yarn-1.22.19
    copying path '/nix/store/3qr0nz4gj73cwybvbagcsj1px7h5723r-yarn-1.22.19' from 'https://cache.nixos.org'...
    building '/nix/store/xj4bj2xi7mk6iqklwrb3pjknvgw4g96z-devbox-development.drv'...
    created 101 symlinks in user environment
    building '/nix/store/kg40s5pdz3rqs65icjxvq2mpca1nj2rp-user-environment.drv'...
yarn (yarn-1.22.19) is now installed.

To update your shell and ensure your new packages are usable, please run:

eval $(devbox shellenv)
```

## PostgreSQL のインストール

Database に PostgreSQL を使おうと思うのでこれもインストールします。

```bash
$ devbox add postgresql_14
Installing nix packages.
    this derivation will be built:
      /nix/store/qc08nll2anma4nw2a973h313hkga2w6j-devbox-development.drv
    building '/nix/store/qc08nll2anma4nw2a973h313hkga2w6j-devbox-development.drv'...
    created 382 symlinks in user environment
    building '/nix/store/zs3jiclvv5x67gsfvzrq3fqm295glcaz-user-environment.drv'...

postgresql NOTES:
To initialize the database run `initdb`.

Services:
* postgresql

Use `devbox services start|stop [service]` to interact with services

This plugin creates the following helper files:

This plugin sets the following environment variables:
* PGDATA=/Users/teraoka/work/rails-devbox/.devbox/virtenv/postgresql_14/data
* PGHOST=/Users/teraoka/work/rails-devbox/.devbox/virtenv/postgresql_14

To show this information, run `devbox info postgresql_14`

postgresql_14 (postgresql-14.6) is now installed.

To update your shell and ensure your new packages are usable, please run:

eval $(devbox shellenv)
```

`PGDATA` が `.devbox/virtenv/postgresql_14/data` に設定されているので `initdb` を実行すればそこにデータファイルが作成されます。
起動させると `PGHOST` の `.devbox/virtenv/postgresql_14` に Unix Domain Socket のファイルが作成されます。

```
$ initdb
The files belonging to this database system will be owned by user "teraoka".
This user must also own the server process.

The database cluster will be initialized with locale "en_US.UTF-8".
The default database encoding has accordingly been set to "UTF8".
The default text search configuration will be set to "english".

Data page checksums are disabled.

fixing permissions on existing directory /Users/teraoka/work/rails-devbox/.devbox/virtenv/postgresql_14/data ... ok
creating subdirectories ... ok
selecting dynamic shared memory implementation ... posix
selecting default max_connections ... 100
selecting default shared_buffers ... 128MB
selecting default time zone ... Asia/Tokyo
creating configuration files ... ok
running bootstrap script ... ok
performing post-bootstrap initialization ... ok
syncing data to disk ... ok

initdb: warning: enabling "trust" authentication for local connections
You can change this by editing pg_hba.conf or using the option -A, or
--auth-local and --auth-host, the next time you run initdb.

Success. You can now start the database server using:

    pg_ctl -D /Users/teraoka/work/rails-devbox/.devbox/virtenv/postgresql_14/data -l logfile start
```

### PostgreSQL サービスの起動

`devbox services` コマンドで PostgreSQL サーバーを起動させることができるようになっています。

```
$ devbox services ls
postgresql
```

```
$ devbox services start
waiting for server to start.... done
server started
Service "postgresql" started
```

この後 redis もインストール＆起動させますが、 `devbox services start` の後に `postgresql` や `redis` を指定することで個別に起動・停止することが可能です。

https://www.jetpack.io/devbox/docs/guides/services/

macOS の自分のユーザー名で PostgreSQL の Superuser ユーザーが作成されています。

```
$ psql postgres
psql (14.6)
Type "help" for help.

postgres=# \l
                                List of databases
   Name    |  Owner  | Encoding |   Collate   |    Ctype    |  Access privileges
-----------+---------+----------+-------------+-------------+---------------------
 postgres  | teraoka | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 template0 | teraoka | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/teraoka         +
           |         |          |             |             | teraoka=CTc/teraoka
 template1 | teraoka | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/teraoka         +
           |         |          |             |             | teraoka=CTc/teraoka
(3 rows)

postgres=#
```

```
postgres=# \du
                                   List of roles
 Role name |                         Attributes                         | Member of
-----------+------------------------------------------------------------+-----------
 teraoka   | Superuser, Create role, Create DB, Replication, Bypass RLS | {}
```

デフォルトだと localhost の 5432/tcp を listen するので複数 project で同時に実行すると port が被って起動できないので `listen_addresses = ''` として Unix Domain Socket だけにするか port を変更する必要があります。
Docker を使う場合との違いですね。
メモリを無駄にしてしまうので、不要なら停止させておくのが良いですが。

ただし、Unix Domain Socket のファイル path は 103 bytes が上限のようなので注意

```
Unix-domain socket path "/Users/teraoka/ghq/github.com/yteraoka/django-otel-cloud-trace/.devbox/virtenv/postgresql_14/.s.PGSQL.5432" is too long (maximum 103 bytes)
```

`postgresql.conf` の `unix_socket_directories` を書き換えても変更できないのだがどうやって指定してるんだろうか？


### Ruby の pg gem をインストール

```
$ gem install pg
Fetching pg-1.4.6.gem
Building native extensions. This could take a while...
Successfully installed pg-1.4.6
Parsing documentation for pg-1.4.6
Installing ri documentation for pg-1.4.6
Done installing documentation for pg after 5 seconds
1 gem installed
```

## Redis のインストール

```bash
$ devbox add redis
Installing nix packages.
    this derivation will be built:
      /nix/store/zadjqfb3ndrxqy0wil5vkvw1jsk04l58-devbox-development.drv
    building '/nix/store/zadjqfb3ndrxqy0wil5vkvw1jsk04l58-devbox-development.drv'...
    created 388 symlinks in user environment
    building '/nix/store/b9zfg0m64xq3726njarxkgdy2lp2dp1q-user-environment.drv'...

redis NOTES:
Running `devbox services start redis` will start redis as a daemon in the background.

You can manually start Redis in the foreground by running `redis-server $REDIS_CONF --port $REDIS_PORT`.

Logs, pidfile, and data dumps are stored in `.devbox/virtenv/redis`. You can change this by modifying the `dir` directive in `devbox.d/redis/redis.conf`

Services:
* redis

Use `devbox services start|stop [service]` to interact with services

This plugin creates the following helper files:
* /Users/teraoka/work/rails-devbox/devbox.d/redis/redis.conf

This plugin sets the following environment variables:
* REDIS_PORT=6379
* REDIS_CONF=/Users/teraoka/work/rails-devbox/devbox.d/redis/redis.conf

To show this information, run `devbox info redis`

redis (redis-7.0.8) is now installed.

To update your shell and ensure your new packages are usable, please run:

eval $(devbox shellenv)
```

redis の場合は `devbox.d/redis/redis.conf` に設定ファイルが置かれています。
`.devbox/virtenv/redis` 配下ではないのですね。`redis.conf` の中の `dir` 設定は

```
dir .devbox/virtenv/redis/
```

と設定されているので save コマンドでのデータファイルの出力先や aof のファイルはここに出力されるようです。


## Python で試していたら grpcio package がインストールできなかった問題

devbox の Python 3.10 を使っていた時に `pip install grpcio` がコケる問題が発生して困った。

compile 時に header file が見つからないようなエラーが出ていた。

Twitter でつぶやいたら Jetpack の中の人が対処方法を教えてくれた。ありがたい。

{{< x user="jetpack_john" id="1630597719592173571" >}}

これを見て devbox.json での shell.init_hook や [shell.scripts](https://www.jetpack.io/devbox/docs/guides/scripts/) の使い方を知った。


## Plugin

ここで使った PostgreSQL や Redis は [Plugin](https://www.jetpack.io/devbox/docs/guides/plugins/) と呼ばれる機構でその project 独自の config や data の保持ができるように調整されるようになっていました。現在対応されているものは devbox の repository で確認できる。

https://github.com/jetpack-io/devbox/tree/main/plugins

MySQL は未対応だが、MariaDB はある。

Ruby で Ruby Gems のインストール先を指定する環境変数を設定しているのもこの Plugin 機構だった。
Python の場合は venv 使えよって出力するだけ。


## Services

PostgreSQL や Redis のように `devbox services` に対応しているものは [Plugins that Support Services](https://www.jetpack.io/devbox/docs/guides/services/) にあった。

Plugin にはあった MariaDB だが Service はまだ未対応のようだ。
しかし、起動方法は[ドキュメント](https://www.jetpack.io/devbox/docs/devbox_examples/databases/mariadb/)にあった。


## インストール可能な package

`devbox add` でインストール可能な package は https://search.nixos.org/packages で探せるっぽい。


## Examples

[Devbox Examples](https://www.jetpack.io/devbox/docs/devbox_examples/) を見てから始めるのが良さそう。


## Dockerfile 生成

[devbox generate dockerfile](https://www.jetpack.io/devbox/docs/cli_reference/devbox_generate_dockerfile/) コマンドを実行すると Dockerfile を生成してくれる。
ただし、コンテナの中でも nix package を使うものになっている。開発にそれを使っているのだからコンテナでもそうあるべきだろうというのはわかるけど、うーむ。
これは使わないかな。
