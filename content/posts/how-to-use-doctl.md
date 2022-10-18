---
title: 'DigitalOcean の doctl の使い方'
date: Sat, 11 Jun 2016 14:33:04 +0000
draft: false
tags: ['DigitalOcean']
---

[DigitalOcean](https://www.digitalocean.com/) の [API](https://developers.digitalocean.com/documentation/v2/) にアクセスするコマンドラインツールである [doctl](https://github.com/digitalocean/doctl) の使い方をメモ

### Access Token の設定

```
$ doctl auth login
```

と実行すればブラウザが起動して DigitalOcean のログインフォームが表示されるのでログインすれば ~/.doctlcfg ファイルに

```
access-token: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
```

てな具合に保存されます。（私の手元では 1.0.2 ではこれが正常に動作したのですが、1.1.0, 1.2.0 では動作しませんでした） `.doctlcfg` に設定する以外に `DIGITALOCEAN_ACCESS_TOKEN` という環境変数に設定する方法もあります

### Droplet （仮想サーバー） の作成

作成には `docker compute droplet create` を使う、次のように `--image`, `--size`, `--region` が必須項目となっている

```
$ doctl compute droplet create -h
create droplet

Usage:
  doctl compute droplet create NAME [NAME ...] [flags]

Aliases:
  create, c


Flags:
      --enable-backups              Backup droplet
      --enable-ipv6                 IPv6 support
      --enable-private-networking   Private networking
      --format string               Columns for output in a comma seperated list. Possible values: ID,Name,PublicIPv4,Memory,VCPUs,Disk,Region,Image,Status,Tags
      --image string                Droplet image (required)
      --no-header                   hide headers
      --region string               Droplet region (required)
      --size string                 Droplet size (required)
      --ssh-keys value              SSH Keys or fingerprints (default [])
      --tag-name string             Tag name
      --user-data string            User data
      --user-data-file string       User data file
      --wait                        Wait for droplet to be created

Global Flags:
  -t, --access-token string   API V2 Access Token
  -c, --config string         config file (default is $HOME/.doctlcfg)
  -o, --output string         output format [text|json] (default "text")
      --trace                 trace api access
  -v, --verbose               verbose output
```

```
$ doctl compute image list
```

で起動可能なイメージの一覧が表示されます。ubuntu のイメージの一覧は次のようにして確認できる `create` の `--image` にはこの出力の `Slug` の値を指定する

```
$ doctl compute image list | egrep '^ID|ubuntu'
ID          Name           Type        Distribution  Slug                Public  Min Disk
17154032    14.04.4 x64    snapshot    Ubuntu        ubuntu-14-04-x64    true    20
17154107    14.04.4 x32    snapshot    Ubuntu        ubuntu-14-04-x32    true    20
17157155    12.04.5 x64    snapshot    Ubuntu        ubuntu-12-04-x64    true    20
17157433    12.04.5 x32    snapshot    Ubuntu        ubuntu-12-04-x32    true    20
15621816    15.10 x64      snapshot    Ubuntu        ubuntu-15-10-x64    true    20
15621817    15.10 x32      snapshot    Ubuntu        ubuntu-15-10-x32    true    20
17769086    16.04 x64      snapshot    Ubuntu        ubuntu-16-04-x64    true    20
17769845    16.04 x32      snapshot    Ubuntu        ubuntu-16-04-x32    true    20
```

リージョンの一覧は次のようにして確認できます

```
$ doctl compute region list
Slug    Name            Available
nyc1    New York 1      true
sfo1    San Francisco 1 true
nyc2    New York 2      true
ams2    Amsterdam 2     true
sgp1    Singapore 1     true
lon1    London 1        true
nyc3    New York 3      true
ams3    Amsterdam 3     true
fra1    Frankfurt 1     true
tor1    Toronto 1       true
blr1    Bangalore 1     true
```

サイズは次のコマンドで。これも `--size` には `Slug` を指定します。 Slug はメモリのサイズになっていますが DigitalOcean ではこのようにメモリ、CPU、Diskのサイズがセットになっています。

```
$ doctl compute size list
Slug    Memory  VCPUs   Disk    Price Monthly   Price Hourly
512mb   512     1       20      5.00            0.007440
1gb     1024    1       30      10.00           0.014880
2gb     2048    2       40      20.00           0.029760
4gb     4096    2       60      40.00           0.059520
8gb     8192    4       80      80.00           0.119050
16gb    16384   8       160     160.00          0.238100
32gb    32768   12      320     320.00          0.476190
48gb    49152   16      480     480.00          0.714290
64gb    65536   20      640     640.00          0.952380
```

作成してみます。

```
$ doctl compute droplet create test01 --image ubuntu-16-04-x64 --size 512mb --region sgp1 --ssh-keys 76364
ID        Name    Public IPv4      Memory  VCPUs  Disk  Region  Image             Status  Tags
17218487  test01                   512     1      20    sgp1    Ubuntu 16.04 x64  new
```

起動したら Status が `active` にかわります。

```
$ doctl compute droplet list
ID        Name    Public IPv4      Memory  VCPUs  Disk  Region  Image             Status  Tags
17218487  test01  128.199.206.232  512     1      20    sgp1    Ubuntu 16.04 x64  active
```

IPアドレスを確認せずとも次のようにして SSH でアクセスできます

```
$ doctl compute ssh test01
```

`create` の `--ssh-keys` は必須ではないため省略可能です。省略するとパスワードがメールで送られてきます DigitalOcean の sshd はパスワード認証が有効なので要注意

### Droplet （仮想サーバー） の削除

```
$ doctl compute droplet delete -h
Delete droplet by id or name

Usage:
  doctl compute droplet delete ID [ID|Name ...] [flags]

Aliases:
  delete, d, del, rm


Global Flags:
  -t, --access-token string   API V2 Access Token
  -c, --config string         config file (default is $HOME/.doctlcfg)
  -o, --output string         output format [text|json] (default "text")
      --trace                 trace api access
  -v, --verbose               verbose output
```

```
$ doctl compute droplet delete test01
deleted droplet 17218487
```
