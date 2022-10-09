---
title: 'DigitalOcean にて Rancher を試す - その2 (HA構成)'
date: Sat, 28 Jan 2017 16:09:33 +0000
draft: false
tags: ['DigitalOcean', 'Docker', 'Rancher']
---

今回は Rancher Server を HA 構成でセットアップしてみます。

[https://docs.rancher.com/rancher/v1.3/en/installing-rancher/installing-server/#multi-nodes](https://docs.rancher.com/rancher/v1.3/en/installing-rancher/installing-server/#multi-nodes) これまた簡単でした。

[前回](/2017/01/rancher-on-digitalocean-part1/)試した [Quick Start Guide](https://docs.rancher.com/rancher/v1.3/en/quick-start-guide/) では

```
docker run -d --restart=unless-stopped -p 8080:8080 rancher/server
```

とするだけでした。この Container の中で MySQL も稼働しているのですが、HA 構成とするためには複数のサーバーで共有するための MySQL サーバーを別途用意し、サーバーはお互いに 9345/tcp で通信できるようにします。ただそれだけで、複数台のどのサーバーにアクセスしても良い状態となるためこれらを Load Balancer に入れます。
今回も DigitalOcean です。OS は Ubuntu 16.04 サーバー間の通信には Private Network を使うこととします。

### MySQL サーバーのセットアップ

MySQL サーバーのインストール

```
$ sudo apt-get install mysql-server
$ sudo sed -i 's/bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
$ sudo systemctl restart mysql
```

firewall 設定

```
$ sudo ufw allow ssh
$ sudo ufw enable
$ sudo ufw allow from 10.130.0.0/16 to any port mysql
```

MySQL の DB とユーザーを作成

```
mysql> CREATE DATABASE IF NOT EXISTS cattle COLLATE = 'utf8_general_ci' CHARACTER SET = 'utf8';
mysql> GRANT ALL ON cattle.* TO 'cattle'@'%' IDENTIFIED BY 'cattle-pass';
mysql> GRANT ALL ON cattle.* TO 'cattle'@'localhost' IDENTIFIED BY 'cattle-pass';
```

### Rancher Server の起動

```
$ sudo docker run -d \
    --restart=unless-stopped \
    -p 8080:8080 \
    -p 9345:9345 \
    rancher/server \
      --db-host 10.130.37.252 \
      --db-port 3306 \
      --db-user cattle \
      --db-pass cattle-pass \
      --db-name cattle \
      --advertise-address $(curl -s http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address)
```

* 外部の MySQL サーバーを使うように指定 (`--db-*`)
* お互いの通信のために expose する port に 9345 が追加 (`-p 9345:9345`)
* お互いの通信のためにここに接続しろと DB に登楼するアドレスを `--advertise-address` で指定 (private address を DigitalOcean の metadata API から取得している)

```
mysql> select id, name, uuid, heartbeat, config, hex(clustered) from cluster_membership\G
*************************** 1. row ***************************
            id: 5
          name: NULL
          uuid: 772d6569-11ba-416a-a057-2dc7693d4571
     heartbeat: 1485617842672
        config: {"advertiseAddress":"10.130.48.220:9345","httpPort":8080,"clustered":true}
hex(clustered): 1
*************************** 2. row ***************************
            id: 6
          name: NULL
          uuid: 4b7a0e7d-c31c-4dbe-904b-461204c7d017
     heartbeat: 1485617846379
        config: {"advertiseAddress":"10.130.48.23:9345","httpPort":8080,"clustered":true}
hex(clustered): 1
2 rows in set (0.00 sec)
```

MySQL よくわかんないけど **clustered** の値がなんかおかしい？ **bit** 型って mysql コマンドでは普通にテキストで表示できないのかな？

```
mysql> desc cluster_membership;
+-----------+--------------+------+-----+---------+----------------+
| Field     | Type         | Null | Key | Default | Extra          |
+-----------+--------------+------+-----+---------+----------------+
| id        | bigint(20)   | NO   | PRI | NULL    | auto_increment |
| name      | varchar(255) | YES  | MUL | NULL    |                |
| uuid      | varchar(128) | NO   | UNI | NULL    |                |
| heartbeat | bigint(20)   | YES  |     | NULL    |                |
| config    | mediumtext   | YES  |     | NULL    |                |
| clustered | bit(1)       | NO   |     | b'0'    |                |
+-----------+--------------+------+-----+---------+----------------+
6 rows in set (0.01 sec)
```

2つの Rancher Server を起動した状態です。**Admin** → **High Availability** で確認ができます。

{{< figure src="rancher-ha.png" caption="Rancher HA" >}}

今回はロードバランサーの設定は行っていませんが、どちらのサーバー (8080/tcp) へアクセスしても問題ありませんでした。一方で Kubernetes クラスタの追加を行って、そのセットアップ状況をもう一方で確認することができました。

### まとめ

MySQL の冗長化は MHA などで別途対応する必要がありますが、Rancher Server の冗長化はとても簡単に行えることが確認できました。次は Node が突然死んだ場合とか、メンテナンスのために止めたいときにそこで動いているコンテナがどうなるのかを確認したいと思います。
