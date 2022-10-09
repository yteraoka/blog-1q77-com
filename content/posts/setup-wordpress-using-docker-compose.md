---
title: 'docker-compose で wordpress サーバーを構築'
date: Mon, 21 Sep 2020 15:23:08 +0000
draft: false
tags: ['Docker', 'WordPress', 'WordPress']
---

Lightsail の wordpress (bitnami) イメージを使ってこのブログを運用していましたが、PHP の更新が必要だけど bitnami でのやり方がよくわからんし、調べるのも面倒ということで 1 vCPU, 1GB メモリの VM を2まで無料で使える Oracle Cloud に移設 & コンテナ化してしまうことにしました。 (が、Oracle Cloud の使い方を調べるのも超面倒... しかも学ぶモチベーションが... やっちまった)

コンテナとして実行するわけですが単一ホストでの実行とする、あるいはメモリ的に厳しければ DB を別サーバーに分けることにします。まずは単一サーバーで docker-compose での実行を試みます。[シングルノードの swarm で rolling update](/2018/10/rolling-update-on-single-node-docker-swarm/) というのもありますがとりあえずまだ考えない。

Docker Engine, docker-compose のインストール
-------------------------------------

Oracle Cloud なので Oracle Linux が最も最適化されているのだろうという勝手な思い込みで Oracle Linux 7.x を使うことにします。

```bash
sudo yum -y install docker-engine
sudo curl -L "https://github.com/docker/compose/releases/download/1.27.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

docker-compose.yml の作成
----------------------

Wordpress のコンテナイメージは [wordpress:5.5.1-php7.4-apache](https://hub.docker.com/_/wordpress) で、MySQL のコンテナイメージは [mysql/mysql-server:8.0.21](https://hub.docker.com/r/mysql/mysql-server/) を使うことにします。こっちの MySQL は Oracle の MySQL Team がメンテナンスしているようです。Dockerfile などは [github.com/mysql/mysql-docker](https://github.com/mysql/mysql-docker) にあります。

wordpress コンテナが起動時にどんな処理を行っているのかは [docker-entrypoint.sh](https://github.com/docker-library/wordpress/blob/master/php7.3/apache/docker-entrypoint.sh) を参照。

で、次の `docker-compose.yml` となりました。`wp-content/plugins` と `wp-content/themes` には旧環境のファイルをコピーしておきます。

```yaml
version: "3.8"

services:
  db:
    image: mysql/mysql-server:8.0.21
    volumes:
      - ./mysql/data:/var/lib/mysql
      - ./mysql/backup:/backup
    environment:
      MYSQL_ROOT_PASSWORD: $MYSQL_ROOT_PASSWORD
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: $DB_PASSWORD
      MYSQL_DATABASE: wordpress
  wordpress:
    image: wordpress:5.5.1-php7.4-apache
    volumes:
      - ./wordpress/wp-content/plugins:/var/www/html/wp-content/plugins
      - ./wordpress/wp-content/themes:/var/www/html/wp-content/themes
      - ./wordpress/wp-content/uploads:/var/www/html/wp-content/uploads
      - ./wordpress/php.ini:/usr/local/etc/php/php.ini:ro
      - ./wordpress/backup:/backup
    depends_on:
      - db
    environment:
      # https://api.wordpress.org/secret-key/1.1/salt/
      WORDPRESS_AUTH_KEY: $WORDPRESS_AUTH_KEY
      WORDPRESS_SECURE_AUTH_KEY: $WORDPRESS_SECURE_AUTH_KEY
      WORDPRESS_LOGGED_IN_KEY: $WORDPRESS_LOGGED_IN_KEY
      WORDPRESS_NONCE_KEY: $WORDPRESS_NONCE_KEY
      WORDPRESS_AUTH_SALT: $WORDPRESS_AUTH_SALT
      WORDPRESS_SECURE_AUTH_SALT: $WORDPRESS_SECURE_AUTH_SALT
      WORDPRESS_LOGGED_IN_SALT: $WORDPRESS_LOGGED_IN_SALT
      WORDPRESS_NONCE_SALT: $WORDPRESS_NONCE_SALT

      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: $DB_PASSWORD
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_DB_CHARSET: utf8mb4
      WORDPRESS_DB_COLLATE: utf8mb4_bin

      WORDPRESS_CONFIG_EXTRA: |
        define('WPMS_ON', true);
        define('WPMS_MAIL_FROM', '$SMTP_USER');
        define('WPMS_MAIL_FROM_FORCE', true);
        define('WPMS_MAILER', 'smtp');
        define('WPMS_SMTP_HOST', 'smtp.gmail.com');
        define('WPMS_SMTP_PORT', 465);
        define('WPMS_SSL', 'ssl');
        define('WPMS_SMTP_AUTH', true);
        define('WPMS_SMTP_USER', '$SMTP_USER');
        define('WPMS_SMTP_PASS', '$SMTP_PASS');
        define('WPMS_SMTP_AUTOTLS', true);
        if (strpos($$_SERVER['HTTP_CLOUDFRONT_FORWARDED_PROTO'], 'https') !== false) {
          $$_SERVER['HTTPS']='on';
        }
        if (strtolower($$_SERVER['HTTPS']) == 'on') {
          define('WP_SITEURL', 'https://' . $$_SERVER['HTTP_HOST'] . '/');
          define('WP_HOME', 'https://' . $$_SERVER['HTTP_HOST'] . '/');
        } else {
          define('WP_SITEURL', 'http://' . $$_SERVER['HTTP_HOST'] . '/');
          define('WP_HOME', 'http://' . $$_SERVER['HTTP_HOST'] . '/');
        }
    ports:
      - 80:80
    tmpfs:
      - /run
      - /tmp
```

`WORDPRESS_CONFIG_EXTRA` は wp-config.php に追記するコードです。`WPMS_` で始まるものは [WP Mail SMTP](https://wpmailsmtp.com/docs/how-to-secure-smtp-settings-by-using-constants/) 用の設定です。ここでは gmail の SMTP サーバーを使うことにしています。Oracle Cloud にも [SMTP サービス](https://docs.cloud.oracle.com/ja-jp/iaas/Content/Email/Concepts/overview.htm)あるんですね。CloudFront は `X-Forwarded-Proto` ではなく `CloudFront-Forwarded-Proto` ヘッダーを挿入してくるのでそのための設定も入れています。`$XXX` は docker-compose 実行時の環境変数に置き換えられますが、WORDPRESS\_CONFIG\_EXTRA の中での PHP の変数としての $\_SERVER などは $$ として $ をエスケープする必要があります。

php.ini のカスタマイズは /usr/local/etc/php/conf.d ディレクトリ内にファイルをマウントすれば良いのですが、php.ini-production を使うべく、これをコンテナ内から取り出して編集して php.ini としてマウントすることにしました。

[capabilities](https://docs.docker.com/engine/reference/run/#runtime-privilege-and-linux-capabilities) 設定もやるべきかな

Oracle Cloud の Security List (SecurityGroup みたいなやつ)
---------------------------------------------------

初期状態では外部から port 80 へはアクセスできませんでした。Instance の Network Security Groups ってのを設定すれば良さそうな感じではあるものの、その方法がわかりませんでした。Subnet の Default Security List というのがデフォルトでは 22/tcp と ICMP の type 3,4 だけを許可するようになっていたのでとりあえずここに 80/tcp を追加しました。Subnet のデフォルトルールで許可してしまうのは本来は良くないとは思うものの現状、他のインスタンスは使わないし、本来の設定方法もすぐには見つからないし、どれが無料でどれが有料かもわからないのでとりあえずこれで。仕事で使うわけでもないので Oracle Cloud を真面目に調査するの嫌だ...

Backup
------

docker-compose exec で db コンテナ内で mysqldump を実行しホストのディレクトリをマウントしている /backup に書き出します。パスワードはコンテナ起動時に環境変数で渡してあるのでそれを使いますが、`-p` で指定するとセキュアじゃないよと Warning メッセージが出力されてうざいので MYSQL\_PWD 変数に設定しています。conf ファイルに書くべきなのかもしれない。

```bash
docker-compose exec -T db \
  bash -c "MYSQL_PWD=\$MYSQL_ROOT_PASSWORD \
           mysqldump --add-drop-table -u root wordpress \
           | gzip -9 > /backup/wordpress.dump.\$(date +%a).sql.gz"
```

upload したファイルはディレクトリをマウントしているだけなのでホスト側で tar にでもすれば ok。

さて、これらを Oracle Cloud の Object Storage に保存するには...

**oci** コマンドを使うと良いらしい [Getting started with the OCI Command Line Interface (CLI)](https://oracle.github.io/learning-library/oci-library/DevOps/OCI_CLI/OCI_CLI_HOL.html)

```bash
bash -c "$(curl –L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
```

でインストールできると書いてあるけど、Python 3 が入っていれば Home directory 配下に venv でインストールするだけっぽいので root で実行しなくても大丈夫。`~/lib/oracle-cli` 配下にインストールされて、`~/bin/oci` にシンボリックリンクが張られました。

が、権限設定周りが全然わからん...

データ移行
-----

旧環境からのデータ移行は Wordpress の export / import 機能を使ったのだけれど、widget 設定とかが飛んんでしまうのはなんとかならないものか？ ファイルのコピーと DB の export / import にした方が良かったのかな。
