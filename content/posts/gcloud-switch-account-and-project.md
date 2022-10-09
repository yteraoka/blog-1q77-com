---
title: 'gcloud でアカウントやプロジェクトを切り替える'
date: Sat, 25 Jan 2020 08:46:59 +0000
draft: false
tags: ['GCP', 'GCP', 'gcloud']
---

Google Cloud SDK の [gcloud](https://cloud.google.com/sdk/docs/) で複数のプロジェクトを切り替えたり、さらには複数アカウントを切り替えながら使う方法を調べた。

gcloud init
-----------

`gcloud init` としてブラウザで OAuth2 認証して、プロジェクトとデフォルトのゾーンを選択して設定が作成される。

これは default という configuration が作られていて `gcloud config configurations list` で確認することができる。gcloud の設定ファイルは `~/.config/gcloud` 配下に作られている。

```
$ gcloud config configurations list
NAME     IS_ACTIVE  ACCOUNT               PROJECT            DEFAULT_ZONE       DEFAULT_REGION
default  True       **********@gmail.com  my-project-******  asia-northeast1-b  asia-northeast1
```

ここで表示されている格値は `gcloud config get-value` で確認できる。

```
$ gcloud config get-value account
**********@gmail.com

$ gcloud config get-value project
my-project-****

$ gcloud config get-value compute/zone
asia-northeast1-b

$ gcloud config get-value compute/region
asia-northeast1
```

region や zone はサービスごとの設定の様で上の DEFAULT\_ZOONE, DEFAULT\_REGION は compute のものである。他は us になってたり未指定だったりする。

```
$ gcloud config get-value functions/region
us-central1

$ gcloud config get-value run/region  
(unset)
```

アカウント
-----

認証済みのアカウントは `gcloud auth list` で確認できる。

```
$ gcloud auth list
   Credentialed Accounts
ACTIVE  ACCOUNT
*       **********@gmail.com

To set the active account, run:
    $ gcloud config set account `ACCOUNT`
```

ここで `gcloud auth login` とすれば別のアカウントも追加することができ、その後アカウントを切り替えながら使うことができる。

```
gcloud auth list                    
   Credentialed Accounts
ACTIVE  ACCOUNT
        **********@gmail.com
*       xxxxxxxxxx@example.com

To set the active account, run:
    $ gcloud config set account `ACCOUNT`
```

`gcloud auth login` すると次のような warning が表示された。gsutil とかアプリで使うための json のやつが必要な場合は別途コマンド実行してねということのよう。

```
WARNING: `gcloud auth login` no longer writes application default credentials.
If you need to use ADC, see:
  gcloud auth application-default --help
```

ところで、`gcloud auth login` で新たに別アカウントでログインしたら default 設定のアカウントが切り替わってしまった。

```
$ gcloud config configurations list
NAME     IS_ACTIVE  ACCOUNT                 PROJECT            DEFAULT_ZONE       DEFAULT_REGION
default  True       xxxxxxxxxx@example.com  my-project-******  asia-northeast1-b  asia-northeast1
```

これは `gcloud config set` で変更することができる。

```
$ gcloud config set account **********@gmail.com
Updated property [core/account].
```

が、私の欲しいのはこれじゃないんですね。アカウントとプロジェクトをセットにして切り替えたい。

使わなくなったアカウントは revoke で削除することができます。

```
gcloud auth revoke [ACCOUNTS ...] [--all] [GCLOUD_WIDE_FLAG ...]

```

アカウントを省略すると今 active になっているアカウントが revoke されます。

gcloud config configurations
----------------------------

前項の「アカウントとプロジェクトをセットにして切り替えたい」を実現するための仕組みが configurations でした。

```
$ gcloud config configurations       
ERROR: (gcloud.config.configurations) Command name argument expected.

Available commands for gcloud config configurations:

      activate                Activates an existing named configuration.
      create                  Creates a new named configuration.
      delete                  Deletes a named configuration.
      describe                Describes a named configuration by listing its
                              properties.
      list                    Lists existing named configurations.

For detailed information on this command and its flags, run:
  gcloud config configurations --help
```

create で新しいのを作って activate で切り替えます。

tutorial という configuration を作ってみます。

```
$ gcloud config configurations create tutorial
Created [tutorial].
Activated [tutorial].
```

新しく作られた物が active になっていますが、`--no-activate` をつけて実行すればこれは抑制できます。

```
$ gcloud config configurations list
NAME      IS_ACTIVE  ACCOUNT               PROJECT            DEFAULT_ZONE       DEFAULT_REGION
default   False      **********@gmail.com  my-project-******  asia-northeast1-b  asia-northeast1
tutorial  True
```

でも新しく作った方でアカウントやプロジェクトを指定するので active になってくれた方が便利かな。

```
$ gcloud auth list
$ gcloud config set account xxxxxxxxxx@example.com

$ gcloud projects list | grep tutorial
$ gcloud config set project tutorial-xxxxxxx

$ gcloud compute zones list | grep asia-northeast
$ gcloud config set compute/zone asia-northeast1-b
$ gcloud config set compute/region asia-northeast1

```

これで次の様になる。

```
$ gcloud config configurations list               
NAME      IS_ACTIVE  ACCOUNT                 PROJECT            DEFAULT_ZONE       DEFAULT_REGION
default   False      **********@gmail.com    my-project-******  asia-northeast1-b  asia-northeast1
tutorial  True       xxxxxxxxxx@example.com  tutorial-xxxxxxx   asia-northeast1-b  asia-northeast1
```

後は `gcloud config configurations activate xxx` で切り替えることができる。project id が覚えにくくても好きな名前をつけて切り替えられるし、プロジェクトによって region が違っても一緒に切り替えられる。
