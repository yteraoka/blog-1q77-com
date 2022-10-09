---
title: 'Guacamole の機能紹介'
date: Sun, 13 Jan 2019 16:19:08 +0000
draft: false
tags: ['Docker', 'Guacamole', 'remotedesktop']
---

kakakakakku さんの[ブログの Guacamole 記事](https://kakakakakku.hatenablog.com/entry/2019/01/09/001605)を見て、私もやったのになあとこんな tweet をしてしまいました。

{{< twitter user="yteraoka" id="1082856539667365888" >}}

てなわけで書かざるをえません。そして書こうと思ったら直前に1年ぶりの新バージョン [1.0.0 がリリース](https://guacamole.apache.org/releases/1.0.0/)されていたのでこれを試します。

Guacamole とは
------------

（オフィスでご覧の方は ZOZOTOWN Guacamole で検索するといいんじゃないかな 🤭）

[https://guacamole.apache.org/](https://guacamole.apache.org/) に

> Apache Guacamole is a clientless remote desktop gateway. It supports standard protocols like VNC, RDP, and SSH.

と書いてあります。

ブラウザさえあれば、Windows へのリモートデスクトップも VNC サーバーへのアクセスも SSH も Telnet もできちゃうすぐれものです。その操作をレコーディングして監査に使うこともできますし、セッションを共有することで別の場所にいる誰かと画面や SSH のセッションを共有することも可能です。参照専用の共有と操作可能な共有から選択できますし、共有用のリンクからであれば Guacamole へのログインも不要です。認証については DB に Guacamole 用ユーザーを作成することも可能ですし、LDAP を参照することも OpenID サーバと連携させることも可能です。1.0.0 では RADIUS にも対応したようですし、LDAP のグループにも対応したっぽい。以前は2要素認証として [Duo](https://duo.com/) だけがサポートされていましたが 1.0.0 から [Google Authenticator](https://ja.wikipedia.org/wiki/Google_Authenticator) や [Authy](https://authy.com/) などで使える TOTP (Time-based One-time Password) も使えるようになりました。

共有アカウントの接続情報を登録しておき、Guacamole の認証、認可によりその接続を利用させるといった使い方になると思います。

Docker Compose で実行する
--------------------

各機能を使うにはいろいろ依存ライブらいなどを用意する必要があるので Docker を使うのが楽そうです。そこで docker-compose を使います。

### 環境

使った docker と docker-compose のバージョンは次の通り。

```
$ sudo docker version
Client:
 Version:           18.09.1
 API version:       1.39
 Go version:        go1.10.6
 Git commit:        4c52b90
 Built:             Wed Jan  9 19:35:01 2019
 OS/Arch:           linux/amd64
 Experimental:      false

Server: Docker Engine - Community
 Engine:
  Version:          18.09.1
  API version:      1.39 (minimum version 1.12)
  Go version:       go1.10.6
  Git commit:       4c52b90
  Built:            Wed Jan  9 19:06:30 2019
  OS/Arch:          linux/amd64
  Experimental:     false
```

```
$ docker-compose version
docker-compose version 1.23.2, build 1110ad01
docker-py version: 3.6.0
CPython version: 3.6.7
OpenSSL version: OpenSSL 1.1.0f  25 May 2017
```

### 構成

Guacamole はサーバーの guacd と、クライアントで Web UI を提供する guacamole と設定やユーザー情報を保存する Database (MySQL, PostgreSQL, SQLServer) で構成されます。この記事では Database に PostgreSQL を使いました。LDAP のスキーマを拡張することで設定も LDAP に保存することができるようですが試していません。後半で LDAP 連携も試します。

### docker-compose 設定

`docker-compose.yml` は次のようにします。PostgreSQL のデータはホストのディレクトリをマウントさせるため `pgdata` ディレクトリをホスト側に作成しておきます。

#### docker-compose.yml

```yaml
version: '2'
services:
  postgres:
    image: postgres:10-alpine
    env_file: ./env
    volumes:
      - ./pgdata:/var/lib/postgresql/data
    restart: always

  guacd:
    image: guacamole/guacd:1.0.0
    restart: always

  guacamole:
    image: guacamole/guacamole:1.0.0
    env_file: ./env
    environment:
      GUACD_HOSTNAME: guacd
      GUACD_PORT: 4822
      POSTGRES_HOSTNAME: postgres
    restart: always

  nginx:
    image: nginx:latest
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    restart: always
```

#### env

`env` ファイルに guacamole と postgres コンテナで共有する環境変数を入れてあります。

```
POSTGRES_DATABASE=guacamole
POSTGRES_USER=guacamole
POSTGRES_PASSWORD=guacamole
```

guacamole の Tomcat に直接アクセスしても良いのですが、実用するには手前の Reverse Proxy で https 終端をすると思うので nginx を入れます。WebSocket に対応する必要があるため `nginx.conf` を用意してマウントします。

#### nginx.conf

```nginx
user nginx;
worker_processes 1;

error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
  worker_connections 1024;
}

http {
  include /etc/nginx/mime.types;
  default_type application/octet-stream;

  server {
    listen 80;
    root /usr/share/nginx/html;
    location /guacamole/ {
      proxy_pass http://guacamole:8080/guacamole/;
      proxy_buffering off;
      proxy_http_version 1.1;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection $http_connection;
      #access_log off;
    }
  }
}
```

### Database の初期化

Database にテーブルを作ったりする必要があります。次のようにして初期化用の SQL を生成します。

```
sudo docker run --rm guacamole/guacamole:1.0.0 /opt/guacamole/bin/initdb.sh --postgres > init.sql

```

次にこの SQL を Database に適用します。

```
sudo docker-compose up --no-start postgres
sudo docker-compose start postgres
cat init.sql | sudo docker-compose exec -T postgres psql -U guacamole -d guacamole
```

### 起動

あとは `docker-compose up` で起動させれば OK

```
sudo docker-compose up
```

ブラウザで `/guacamole/` にアクセスして次のようなログインフォームが表示されたらきっと成功。ID: `guacadmin` Password: `guacadmin` でログインしてみましょう。

<img src="guacamole-login-form.png">

### SSH

ログインできたら右上のメニューから **settings** に入ります。

<img src="guacadmin-menu.png">

<img src="guacamole-settings.png">

ここの **Connections** から **New Connection** で接続情報を設定します。SSH では次の設定項目があります。

{{< figure src="guacamole-add-ssh-connection.png" >}}

[Configuring Guacamole SSH](https://guacamole.apache.org/doc/gug/configuring-guacamole.html#ssh)

**Name**と接続先の**Hostname**が最低限必要な設定ですが、これではパスワード認証となります。公開鍵認証にするためには**Private key**が必要です。**Username**、**Password**、**Passphrase** がブランクの場合は接続時に入力を求められます。ログインに必要な情報がすべて設定されていれば Guacamole にログインして表示される接続名をクリックするだけで何の入力もなしにログインできます。

**Private key** も **Password** も **Passphrase** も plain text で guacamole\_connection\_parameter テーブルに保存されます。

次のような OpenSSH の Private key の新しいフォーマットは未対応のようです。

```
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----

```

ブラウザでの SSH はどんなものかと思っていましたが、思っていた以上に違和感なく使えました。Bash での各種 Ctrl キーとの組み合わせも動作しますし。文字列を選択した状態でマウスの右クリックをすればペーストできます。

### Remote Desktop

Remote Desktop の場合は次の設定項目があります。

{{< figure src="guacamole-add-rdp-connection.png" >}}

Remote Desktop の場合は **Name**, **Hostname** だけではなく、**Username**, **Password** などログインするのに必要なものはすべて登録済みである必要があります。これも SSH と同じく guacamole\_connection\_parameter テーブルに plain text で保存されます。EC2 の Windows Server 2016 では **Security Mode** は Any にする必要がありました。(Lightsail の 512MB メモリの Windows は遅すぎてまともに使えなかった)

これがブラウザ内に表示される画面です。

{{< figure src="guacamole-remote-desktop.png" >}}

Time-based One-time Password
----------------------------

TOTP を有効にするにはそれ用の jar ファイルを `${GUACAMOLE_HOME}/extensions` ディレクトリに置いて起動するようにしてやる必要があります。docker での起動は `/opt/guacamole/bin/start.sh` が環境変数によって使う Database を判断して毎回 ${GUACAMOLE\_HOME} を作り直しています。一旦ディレクトリごと削除した後に ${GUACAMOLE\_HOME} で指定したディレクトリをコピーしてから Database 用の jar をコピーするので docker-compose.yml を次のようにして guacamole/extensions に TOTP 用 jar を置いておきます。

```yaml
  guacamole:
    image: guacamole/guacamole:1.0.0
    env_file: ./env
    environment:
      GUACD_HOSTNAME: guacd
      GUACD_PORT: 4822
      POSTGRES_HOSTNAME: postgres
      GUACAMOLE_HOME: /guacamole-template
    volumes:
      - ./guacamole:/guacamole-template:ro
    restart: always
```

jar の入った tar.gz をダウンロードして展開する。

```bash
curl -Lo guacamole-auth-totp-1.0.0.tar.gz \
  "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/1.0.0/binary/guacamole-auth-totp-1.0.0.tar.gz"

test -d guacamole/extensions || mkdir -p guacamole/extensions

tar -xvf guacamole-auth-totp-1.0.0.tar.gz \
  --strip-components 1 \
  -C guacamole/extensions \
  guacamole-auth-totp-1.0.0/guacamole-auth-totp-1.0.0.jar
```

この状態で `docker-compose down` & `docker-compose up` すれば TOTP が使えるようになります。初回、ID, Password を入力した後に登録画面が表示されます。

{{< figure src="guacamole-totp.png" >}}

登録が完了すれば次回ログインからは ID, Password 入力後に次のように 6 桁のコード入力を求められます。

{{< figure src="guacamole-input-auth-code.png" >}}

TOTP は Database (MySQL, PostgreSQL, SQLServer) 認証でしかサポートされていないようです。OpenID の場合は OpenID サーバー側でやるべきでしょうしね。

(Vagrant でやっていたのですが、途中 PC を Suspend していたため、その間、サーバーの時刻が止まっておりずれてしまって。Varidation が通らなくてしばらくハマってました 😅)

LDAP 認証
-------

次に[LDAP認証](https://guacamole.apache.org/doc/gug/ldap-auth.html)を試します。環境変数で LDAP サーバーの指定をするだけで起動前に jar がコピーされて LDAP アカウントでロおグインできるようになります。[https://guacamole.apache.org/doc/gug/ldap-auth.html](https://guacamole.apache.org/doc/gug/ldap-auth.html)

```yaml
  guacamole:
    image: guacamole/guacamole:1.0.0
    env_file: ./env
    environment:
      GUACD_HOSTNAME: guacd
      GUACD_PORT: 4822
      POSTGRES_HOSTNAME: postgres
      LDAP_HOSTNAME: ldap.example.com
      LDAP_PORT: 636
      LDAP_ENCRYPTION_METHOD: ssl
      LDAP_USER_BASE_DN: ou=people,dc=example,dc=com
    restart: always
```

LDAP がらみで使える環境変数には次のものがあります。

* LDAP\_HOSTNAME
* LDAP\_PORT
* LDAP\_ENCRYPTION\_METHOD
* LDAP\_USER\_BASE\_DN
* LDAP\_USERNAME\_ATTRIBUTE
* LDAP\_GROUP\_BASE\_DN
* LDAP\_CONFIG\_BASE\_DN
* LDAP\_SEARCH\_BIND\_DN
* LDAP\_SEARCH\_BIND\_PASSWORD

Ad-hoc Connect
--------------

TOTP と同じように guacamole-auth-quickconnect-1.0.0.jar を extensions ディレクトリに置くことで [Ad-hoc Connections](https://guacamole.apache.org/doc/gug/adhoc-connections.html) が使えるようになります。Ad-hoc Connection は登録済みの接続設定を使うのではなく `ssh://linux1.example.com/` などとその場で入力して接続できるようになります。

```
curl -Lo guacamole-auth-quickconnect-1.0.0.tar.gz \
  "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/1.0.0/binary/guacamole-auth-quickconnect-1.0.0.tar.gz"

tar -xvf /tmp/guacamole-auth-quickconnect-1.0.0.tar.gz \
  --strip-components 1 \
  -C guacamole/extensions \
  guacamole-auth-quickconnect-1.0.0/guacamole-auth-quickconnect-1.0.0.jar
```

Home 画面に次の用な入力フォームが表示されます。

{{< figure src="guacamole-quick-connection.png" >}}

認証情報が保存できないので実際に使える場面は少なそうですけど。

セッション共有
-------

URL を共有することで SSH やリモートデスクトップのセッションを複数人で共有することができます。そしてこれは Guacamole にログインする必要がないため、組織外の人と共有できます。参照専用で共有することもできます。

<img src="guacamole-connections2.png">

接続設定に対して **New Sharing Profile** で共有プロファイルを作成することができます。このキャプチャの **ec2-win1** には **readonly** と **share-test** という2つの共有プロファイルを作成してあります。作成時に Read-only フラグにチェックを入れておくことで参照専用で共有することができるようになります。

共有用のリンクを取得するには接続した状態で **Ctrl**+**Alt**+**Shift** で [Guacamole menu](https://guacamole.apache.org/doc/gug/using-guacamole.html#guacamole-menu) を表示して、そこの上部にある share ボタンからプロファイルを選択します。

<img src="guacamole-menu-rdp.png">

SSH でも同様です

<img src="guacamole-share-connection.png">

表示されたリンクを使って共有セッションにアクセスすることができます。Guacamole menu は共有リンクの表示以外にオンスクリーンキーボードを表示させたり、マウスの挙動をタブレットやスマホ用に切り替えたりもできます。これは個人設定の Preference でも設定可能ですが、セッション中に変更するにはこのメニューを使います。Guacamole menu からホーム画面やセッティング画面に移動すればセッションは継続したまま別のセッションに移ったりできます。

「今、こんな感じの画面になってて困ってます」って共有する時とかに便利そうですね。

[Sharing the connection](https://guacamole.apache.org/doc/gug/using-guacamole.html#client-share-menu)

レコーディング
-------

リモートデスクトップや VNC ではグラフィカルなレコーディングが可能です。SSH や Telnet ではそれに加えてテキストでのレコーティングも可能です。保存を行うのはサーバー側の **guacd** です。

### Text session recording (typescripts)

SSH や Telnet の場合は Typescript path に保存先ディレクトリを指定すれば script コマンドでのログが保存されます。**Typescript name** が未設定の場合は typescript というファイル名で保存されます。**Automatically create typescript path** にチェックを入れておくと保存先ディレクトリが存在しない場合にディレクトリを作成してくれます。ただし、作成するのは最後のサブディレクトリだけで、その親ディレクトリは予め存在している必要があります。次のように2つ以降のセッションには末尾に連番の数字がつきます。

```
typescript  typescript.1  typescript.1.timing  typescript.2  typescript.2.timing  typescript.timing
```

再生するには次のように `scriptreplay` コマンドを使います。

```
scriptreplay typescript.timing typescript
```

テキストなので grep したりエディタで開くこともできます。

### Screen Recording

グラフィカルなレコーディングもテキストと同様に **Recording path** に保存先ディレクトリを指定すればレコーディングされます。**Recording name** でファイル名を指定しなかった場合は **recording** というファイル名で保存されます。2つ目以降は末尾に連番の数字がつきます。`guacenc` コマンドを使うことで保存されたファイルから MP4 ファイルを生成することができます。**Include key events** を有効にしておけば `guaclog` コマンドで入力をテキストで書き出すことができます。

ただし、`guacenc` も `guaclog` も **guacd** コンテナに含まれていなかったので試していません。

SFTP によるファイルのアップロード
-------------------

SSH の場合は設定の **Enable SFTP** を有効にして **File browser root directory** にサーバー側のディレクトリを指定するとそのディレクトリ以下のディレクトリツリーを参照できるようになり、任意の場所にファイルをアップロードしたり、ダウンロードすることができるようになります。

次のキャプチャのように Guacamole メニュー (**Ctrl**+**Alt**+**Shift**) に **Device** という項目が表示されます。この例ではディレクトリが未指定なので `/` で全部が見えるようになっています。

{{< figure src="guacadmin-device.png" >}}

Device を選択するとファイルブラウザの用なものが表示されるので、ここからたどってファイルをダウンロードしたり、ディレクトリにファイルをアップロードします。

{{< figure src="guacamole-sftp.png" >}}

リモートデスクトップと VNC にも SFTP 設定はありますが、別途 SFTP サーバーや認証情報を設定する必要があります。リモデ先が Windows であればそこで SFTP サーバーを起動させるか、その Windows からアクセス可能なファイルサーバーに SFTP でアクセスするとかいった使い方になるようです。

リモートデスクトップでのドライブマウント
--------------------

Windows ならクリップボードからファイルもコピーできるんだろうか？とも思ったけど、文字列のコピペはできますがファイルはできないようです。リモートデスクトップの設定には **Device Redirection** というセクションがあり、この中に **Enable drive**、**Drive name**、**Drive path**、**Automatically create drive** という項目があり、Guacamole サーバーの指定のディレクトリをリモデ先がマウントしてアクセスすることができるようになります。

次のように設定してみます

{{< figure src="guacamole-device-redirection-setting.png" >}}

すると、リモデ先では次のようにドライブとしてマウントされています

{{< figure src="guacamole-drive.png" >}}

このドライブ内に `Download` という作成した覚えのないフォルダが存在するのですが、この `Download` フォルダにファイルを置くとブラウザでダウンロードする形でリモデ先からファイルをコピーすることができるのです。ドライブ内の他の場所にファイルを置くとそれは **guacd** を実行しているサーバー（コンテナ）内の指定のディレクトリ配下にコピーされます

接続設定のグルーピングと権限設定
----------------

このキャプチャはセッション共有の節で使ったものですが、接続情報が **Banana** と **Orange** というフォルダに分かれています。

{{< figure src="guacamole-connections2.png" >}}

このようにグループ分けすることでグループ単位で人やグループにその接続の使用を許可するかどうかの設定が可能です。個別の接続単位でももちろん制御可能です。ユーザーごとに新たな設定を追加可能にするかどうかなどを設定できます。

{{< figure src="guacadmin-add-user.png" >}}

このキャプチャは接続設定作成前のものですが、作成済みの場合は一番下に接続設定のツリーが表示され、どれを使用可能とするかを選択できます。ユーザーグループの方でも制御可能です。

その他
---

OpenID 認証や VNC 接続など、ここで試さなかった機能が他にもあります

い～～～～っじょうぅ！
