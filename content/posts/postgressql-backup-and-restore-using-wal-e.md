---
title: 'WAL-E で PostgreSQL の Backup / Restore'
date: Thu, 01 Sep 2016 15:41:07 +0000
draft: false
tags: ['AWS', 'Linux', 'PostgreSQL', 'S3', 'Ubuntu', 'postgresql']
---

PostgreSQL の Backup / Restore ツールとして heroku で開発されたとされる [WAL-E](https://github.com/wal-e/wal-e) がある。 フィジカル（物理）バックアップと WAL のアーカイブを S3 互換のオブジェクトストレージや Azure BLOB Storage や Google Cloud Storage へ保存でき、そこからのリストアもできる便利ツールです。 AWS で EC2 上の PostgreSQL のバックアップ/リストアを WAL-E で行ってみます。OS は Ubuntu 14.04 (Trusty) を使います。

### S3 側の準備

バックアップ先となる S3 の Bucket を用意します。既存のものでもかまいません。 Bucket 内の指定のディレクトリ(Path)配下に保存します。 IAM のポリシーを作成

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListAllMyBuckets"
            ],
            "Resource": "arn:aws:s3:::*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": "arn:aws:s3:::YOUR_BUCKET_NAME"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::YOUR_BUCKET_NAME/*"
        }
    ]
}
```

EC2 のインスタンス Role を使わない場合は AWS\_ACCESS\_KEY\_ID と AWS\_SECRET\_ACCESS\_KEY を取得します。 この後の例はインスタンス Role を使っているため --aws-instance-profile オプションを指定してありますが、クレデンシャルを使う場合はこれを削る必要があります。

### wal-e のインストール

wal-e は Python で書かれており pip でインストールできます まずは apt で必要なパッケージをインストールします

```
sudo apt-get update
sudo apt-get install lzop pv python-pip python-dev daemontools -y
```

daemontools に含まれる envdir コマンドで AWS のクレデンシャルを環境変数として読み込んでコマンドを実行するようにします lzop はファイルの圧縮に使われます pv は disk i/o のレート制限に使われます（バックアップ処理の負荷で影響がでないように） requests と six が古いので更新して wal-e をインストールします

```
sudo pip install -U requests
sudo pip install -U six
sudo pip install wal-e
```

```
$ wal-e -h
usage: wal-e [-h] [-k AWS_ACCESS_KEY_ID | --aws-instance-profile]
             [-a WABS_ACCOUNT_NAME] [--s3-prefix S3_PREFIX]
             [--wabs-prefix WABS_PREFIX] [--gpg-key-id GPG_KEY_ID] [--terse]
             {version,backup-fetch,backup-list,backup-push,wal-push,wal-fetch,wal-prefetch,delete}
             ...

WAL-E is a program to assist in performing PostgreSQL continuous
archiving on S3 or Windows Azure Blob Service (WABS): it handles pushing
and fetching of WAL segments and base backups of the PostgreSQL data directory.

optional arguments:
  -h, --help            show this help message and exit
  -k AWS_ACCESS_KEY_ID, --aws-access-key-id AWS_ACCESS_KEY_ID
                        public AWS access key. Can also be defined in an
                        environment variable. If both are defined, the one
                        defined in the programs arguments takes precedence.
  --aws-instance-profile
                        Use the IAM Instance Profile associated with this
                        instance to authenticate with the S3 API.
  -a WABS_ACCOUNT_NAME, --wabs-account-name WABS_ACCOUNT_NAME
                        Account name of Windows Azure Blob Service account.
                        Can also be defined in an environmentvariable. If both
                        are defined, the one definedin the programs arguments
                        takes precedence.
  --s3-prefix S3_PREFIX
                        S3 prefix to run all commands against. Can also be
                        defined via environment variable WALE_S3_PREFIX.
  --wabs-prefix WABS_PREFIX
                        Storage prefix to run all commands against. Can also
                        be defined via environment variable WALE_WABS_PREFIX.
  --gpg-key-id GPG_KEY_ID
                        GPG key ID to encrypt to. (Also needed when
                        decrypting.) Can also be defined via environment
                        variable WALE_GPG_KEY_ID
  --terse               Only log messages as or more severe than a warning.

subcommands:
  {version,backup-fetch,backup-list,backup-push,wal-push,wal-fetch,wal-prefetch,delete}
    version             print the wal-e version
    backup-fetch        fetch a hot backup from S3 or WABS
    backup-list         list backups in S3 or WABS
    backup-push         pushing a fresh hot backup to S3 or WABS
    wal-push            push a WAL file to S3 or WABS
    wal-fetch           fetch a WAL file from S3 or WABS
    wal-prefetch        Prefetch WAL
    delete              operators to destroy specified data in S3 or WABS
```

### PostgreSQL のインストール

```
sudo apt-get install postgresql-9.3 -y
```

Ubuntu の場合、データベースの設定ファイルは /etc/postgresql/9.3/main/ 配下に、データは /var/lib/postgresql/9.3/main/ 配下に設置されます アーカイブモードの設定を行います

```
sudoedit /etc/postgresql/9.3/main/postgresql.conf
```

```
wal_level = archive   # hot_standby でも可
archive_mode = on
archive_command = '/usr/bin/envdir /etc/wal-e.d/env /usr/local/bin/wal-e --aws-instance-profile wal-push %p'
archive_timeout = 60   # WAL ファイルがいっぱいにならなくてもこの秒数が経過すればログスイッチしてアーカイブする
```

反映には再起動が必要ですがそれは envdir 設定の後で

### envdir 用設定

場所に決まりはありませんが /etc/wal-e.d/env/ ディレクトリを作成し、そこに設定したい環境変数名のファイルを作成し値を入れます

```bash
sudo mkdir -p /etc/wal-e.d/env
sudoedit /etc/wal-e.d/env/AWS_ACCESS_KEY_ID  # インスタンス Role を使う場合は不要
sudoedit /etc/wal-e.d/env/AWS_SECRET_ACCESS_KEY  # インスタンス Role を使う場合は不要
sudoedit /etc/wal-e.d/env/AWS_REGION  # 東京なので ap-northeast-1
sudoedit /etc/wal-e.d/env/WALE_S3_PREFIX  # s3://YOUR_BUCKET_NAME/SUBDIR
sudo chown -R root:postgres /etc/wal-e.d
sudo chmod -R o-rwx /etc/wal-e.d
```

### バックアップの実行

```
sudo service postgresql restart
```

archive\_command が正常に実行されるかどうかログ (/var/log/postgresql/postgresql-9.3-main.log) を確認します

```
wal_e.main   INFO     MSG: starting WAL-E
        DETAIL: The subcommand is "wal-push".
        STRUCTURED: time=2016-09-01T14:39:52.182896-00 pid=23763
wal_e.worker.upload INFO     MSG: begin archiving a file
        DETAIL: Uploading "pg_xlog/000000010000000000000002" to "s3://YOUR_BUCKET_NAME/SUBDIR/wal_005/000000010000000000000002.lzo".
        STRUCTURED: time=2016-09-01T14:39:52.234031-00 pid=23763 action=push-wal key=s3://YOUR_BUCKET_NAME/SUBDIR/wal_005/000000010000000000000002.lzo prefix=SUBDIR/ seg=000000010000000000000002 state=begin
wal_e.worker.upload INFO     MSG: completed archiving to a file
        DETAIL: Archiving to "s3://YOUR_BUCKET_NAME/SUBDIR/wal_005/000000010000000000000002.lzo" complete at 609.625KiB/s.
        STRUCTURED: time=2016-09-01T14:39:52.462079-00 pid=23763 action=push-wal key=s3://YOUR_BUCKET_NAME/SUBDIR/wal_005/000000010000000000000002.lzo prefix=SUBDIR/ rate=609.625 seg=000000010000000000000002 state=complete
```

```
sudo -u postgres envdir /etc/wal-e.d/env /usr/local/bin/wal-e --aws-instance-profile backup-push /var/lib/postgresql/9.3/main
```

これでデータベース全体のバックアップが行われます

```
$ sudo -u postgres envdir /etc/wal-e.d/env /usr/local/bin/wal-e --aws-instance-profile backup-push /var/lib/postgresql/9.3/main
wal_e.main   INFO     MSG: starting WAL-E
        DETAIL: The subcommand is "backup-push".
        STRUCTURED: time=2016-09-01T14:39:51.941209-00 pid=23737
wal_e.operator.backup INFO     MSG: start upload postgres version metadata
        DETAIL: Uploading to s3://YOUR_BUCKET_NAME/SUBDIR/basebackups_005/base_000000010000000000000003_00000040/extended_version.txt.
        STRUCTURED: time=2016-09-01T14:39:52.237635-00 pid=23737
wal_e.operator.backup INFO     MSG: postgres version metadata upload complete
        STRUCTURED: time=2016-09-01T14:39:52.368084-00 pid=23737
wal_e.worker.upload INFO     MSG: beginning volume compression
        DETAIL: Building volume 0.
        STRUCTURED: time=2016-09-01T14:39:52.399796-00 pid=23737
wal_e.worker.upload INFO     MSG: begin uploading a base backup volume
        DETAIL: Uploading to "s3://YOUR_BUCKET_NAME/SUBDIR/basebackups_005/base_000000010000000000000003_00000040/tar_partitions/part_00000000.tar.lzo".
        STRUCTURED: time=2016-09-01T14:39:52.720335-00 pid=23737
wal_e.worker.upload INFO     MSG: finish uploading a base backup volume
        DETAIL: Uploading to "s3://YOUR_BUCKET_NAME/SUBDIR/basebackups_005/base_000000010000000000000003_00000040/tar_partitions/part_00000000.tar.lzo" complete at 8799.85KiB/s.
        STRUCTURED: time=2016-09-01T14:39:53.112379-00 pid=23737
NOTICE:  pg_stop_backup complete, all required WAL segments have been archived
```

backup-list サブコマンドでベースバックアップのリストが確認できまう

```
$ sudo -u postgres envdir /etc/wal-e.d/env /usr/local/bin/wal-e --aws-instance-profile backup-list
wal_e.main   INFO     MSG: starting WAL-E
        DETAIL: The subcommand is "backup-list".
        STRUCTURED: time=2016-09-01T14:50:11.054832-00 pid=24023
name    last_modified   expanded_size_bytes     wal_segment_backup_start        wal_segment_offset_backup_start wal_segment_backup_stop wal_segment_offset_backup_stop
base_000000010000000000000003_00000040  2016-09-01T14:39:55.000Z                000000010000000000000003        00000040
base_000000010000000000000007_00000040  2016-09-01T14:49:02.000Z                000000010000000000000007        00000040
base_000000010000000000000009_00000040  2016-09-01T14:49:27.000Z                000000010000000000000009        00000040
```

`--detail` をつけるともう少し情報が増えますが、それぞれについて S3 にアクセスすることになるので大量にある時間がかかります

```
$ sudo -u postgres envdir /etc/wal-e.d/env /usr/local/bin/wal-e --aws-instance-profile backup-list --detail
wal_e.main   INFO     MSG: starting WAL-E
        DETAIL: The subcommand is "backup-list".
        STRUCTURED: time=2016-09-01T14:51:08.766735-00 pid=24049
name    last_modified   expanded_size_bytes     wal_segment_backup_start        wal_segment_offset_backup_start wal_segment_backup_stop wal_segment_offset_backup_stop
base_000000010000000000000003_00000040  2016-09-01T14:39:55.000Z        19603869        000000010000000000000003        00000040        000000010000000000000003        00000184
base_000000010000000000000007_00000040  2016-09-01T14:49:02.000Z        26102357        000000010000000000000007        00000040        000000010000000000000007        00000184
base_000000010000000000000009_00000040  2016-09-01T14:49:27.000Z        26110549        000000010000000000000009        00000040        000000010000000000000009        00000184
```

### リストアする

PostgreSQL を停止してデータディレクトリを空っぽにする

```bash
sudo service postgresql stop
sudo rm -fr /var/lib/postgresql/9.3/main
sudo install -o postgres -g postgres -m 0700 -d /var/lib/postgresql/9.3/main
```

backup-fetch サブコマンドでベースバックアップを取得する

```
$ sudo -u postgres envdir /etc/wal-e.d/env /usr/local/bin/wal-e --aws-instance-profile backup-fetch /var/lib/postgresql/9.3/main LATEST
wal_e.main   INFO     MSG: starting WAL-E
        DETAIL: The subcommand is "backup-fetch".
        STRUCTURED: time=2016-09-01T15:01:12.084425-00 pid=24131
wal_e.worker.s3.s3_worker INFO     MSG: beginning partition download
        DETAIL: The partition being downloaded is part_00000000.tar.lzo.
        HINT: The absolute S3 key is waletest2/basebackups_005/base_000000010000000000000009_00000040/tar_partitions/part_00000000.tar.lzo.
        STRUCTURED: time=2016-09-01T15:01:12.439743-00 pid=24131
```

recovery.conf を作成する restore\_command に wal-fetch サブコマンドを指定します、これでベースバックアップ後の WAL ファイルを順に取得して最後の WAL archive 時点まで復旧されます

```
cat <<_EOF_ | sudo -u postgres tee /var/lib/postgresql/9.3/main/recovery.conf
restore_command = '/usr/bin/envdir /etc/wal-e.d/env /usr/local/bin/wal-e --aws-instance-profile wal-fetch "%f" "%p"'
_EOF_
```

PostgreSQL の起動

```
sudo service postgresql start
```

ログ (/var/log/postgresql/postgresql-9.3-main.log) を確認 recovery.conf が recovery.done になっててデータが復元されていることを確認

### 指定の時刻の状態に復元する

さっきは LATEST 指定で最新のベースバックアップを取得したが、もっと前の状態に戻したいのでバックアップの名前指定で取得する

```
sudo service postgresql stop
sudo rm -fr /var/lib/postgresql/9.3/main
sudo install -o postgres -g postgres -m 0700 -d /var/lib/postgresql/9.3/main
```

```
sudo -u postgres envdir /etc/wal-e.d/env /usr/local/bin/wal-e --aws-instance-profile backup-fetch /var/lib/postgresql/9.3/main base_000000010000000000000003_00000040
```

```
cat <<_EOF_ | sudo -u postgres tee /var/lib/postgresql/9.3/main/recovery.conf
restore_command = '/usr/bin/envdir /etc/wal-e.d/env /usr/local/bin/wal-e --aws-instance-profile wal-fetch "%f" "%p"'
recovery_target_time = '2016-09-01 14:49:30'
_EOF_
```

```
sudo service postgresql start
```

これで 2016-09-01 14:49:30 時点の状態に戻りました。recovery\_target\_time はミリ秒まで指定可能。

### 定期実行

ベースバックアップは cron などで日次や週次で定期的に実行します 毎日夜中の3時にベースバックアップを取得する設定

```
0 3 * * * /usr/bin/envdir /etc/wal-e.d/env /usr/local/bin/wal-e --aws-instance-profile backup-push /var/lib/postgresql/9.3/main
```

### バックアップの削除

ベースバックアップは圧縮されてはいるもののフルバックアップなので沢山持つと大きなサイズになっていまいます。 そこからの WAL ファイルを全部持つのも大きなサイズになるので定期的に古いものを削除することになると思います。 次のように delete retain 3 とすることで最新の3つ残して古いものを削除することができます これも cron などで定期実行すると良いでしょう

```
/usr/bin/envdir /etc/wal-e.d/env /usr/local/bin/wal-e --aws-instance-profile delete --confirm retain 3
```

delete everything で全部、delete before base\_000000010000000000000009\_00000040 で指定のバックアップより古いもの（指定したものは残る）を削除できます --confirm を付けない場合は削除対象が表示されるだけです

### ファイルの暗号化

gpg を使ってファイルを暗号化して保存することもできます

### WAL-E を使った replication

マスタ側の archive\_command で backup-push し、レプリカ側の recovery.conf で wal-fetch するようにしておけば S3 などを経由したレプリケーションを組むことも可能です。 Streaming Replication を組めないネットワーク環境では便利かも。
