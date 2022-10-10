---
title: 'Oracle Cloud の oci コマンドセットアップ'
date: Thu, 03 Dec 2020 15:37:57 +0000
draft: false
tags: ['OracleCloud', 'advent calendar 2020']
---

[Advent Calendar 2020 全部オレシリーズ](https://qiita.com/advent-calendar/2020/yteraoka) 4日目です。

[Oracle Cloud の無料枠でこのブログを運用する](/2020/09/setup-wordpress-using-docker-compose/)ことにしたわけですが、docker-compose で起動させるようにしたものの、バックアップ設定を後回しにしていました。でもデータが飛んでしまうと悲しいのでそろそろやることにしました。

Oracle Cloud の Object Storage は S3 互換の API が存在するとのことで、s3cmd を使おうかと思ったのですが、まあよーわからん。

ひとまずは oci コマンドが使えるようにしてみます。

Mac での oci コマンドのインストールは Homebrew でいけました。([oci コマンドのインストール](https://docs.cloud.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm#InstallingCLI))

```bash
brew install oci-cli
```

`oci setup config` コマンドで初期設定を行います。

```bash
$ oci setup config
    This command provides a walkthrough of creating a valid CLI config file.

    The following links explain where to find the information required by this
    script:

    User API Signing Key, OCID and Tenancy OCID:

        https://docs.cloud.oracle.com/Content/API/Concepts/apisigningkey.htm#Other

    Region:

        https://docs.cloud.oracle.com/Content/General/Concepts/regions.htm

    General config documentation:

        https://docs.cloud.oracle.com/Content/API/Concepts/sdkconfig.htm


Enter a location for your config [/Users/teraoka/.oci/config]: 
Enter a user OCID: ocid1.user.oc1..aaaaaaaanaeng2up6fae5ievee7waech3soo1oephahvieshee5ain5ceaga
Enter a tenancy OCID: ocid1.tenancy.oc1..aaaaaaaazoo7urooxee3to2shuha5roo2roh6pha0vooxohr9eiwee5nohy9
Enter a region (e.g. ap-chiyoda-1, ap-chuncheon-1, ap-hyderabad-1, ap-melbourne-1, ap-mumbai-1, ap-osaka-1, ap-seoul-1, ap-sydney-1, ap-tokyo-1, ca-montreal-1, ca-toronto-1, eu-amsterdam-1, eu-frankfurt-1, eu-zurich-1, me-dubai-1, me-jeddah-1, sa-saopaulo-1, uk-cardiff-1, uk-gov-cardiff-1, uk-gov-london-1, uk-london-1, us-ashburn-1, us-gov-ashburn-1, us-gov-chicago-1, us-gov-phoenix-1, us-langley-1, us-luke-1, us-phoenix-1, us-sanjose-1): ap-tokyo-1
Do you want to generate a new API Signing RSA key pair? (If you decline you will be asked to supply the path to an existing key.) [Y/n]: 
Enter a directory for your keys to be created [/Users/teraoka/.oci]: 
Enter a name for your key [oci_api_key]: 
Public key written to: /Users/teraoka/.oci/oci_api_key_public.pem
Enter a passphrase for your private key (empty for no passphrase): 
Private key written to: /Users/teraoka/.oci/oci_api_key.pem
Fingerprint: 2c:48:de:0e:a1:4f:af:1d:b0:02:c3:99:64:9b:d8:cd
Config written to /Users/teraoka/.oci/config


    If you haven't already uploaded your API Signing public key through the
    console, follow the instructions on the page linked below in the section
    'How to upload the public key':

        [https://docs.cloud.oracle.com/Content/API/Concepts/apisigningkey.htm#How2](https://docs.cloud.oracle.com/Content/API/Concepts/apisigningkey.htm#How2)
```

**user OCID** は Web Console の [「アイデンティティ」→「ユーザー」](https://cloud.oracle.com/identity/users) で、 **tenancy OCID** は [「管理」→「テナンシ詳細」](https://cloud.oracle.com/tenancy) で確認できます。なんか無駄に長い感じがしますね...

最後に秘密鍵 (oci\_api\_key.pem) と公開鍵 (oci\_api\_key\_public.pem) のペアが `~/.oci` ディレクトリ内に作成されました。この公開鍵を Oracle Cloud の[「アイデンティティ」→「ユーザー」](https://cloud.oracle.com/identity/users)で、「APIキー」に登録します。

設定は `~/.oci/config` に書かれています。設定項目は [SDK and CLI Configuration File](https://docs.cloud.oracle.com/en-us/iaas/Content/API/Concepts/sdkconfig.htm#File_Entries) に説明があります。AWS のやつみたいに複数 profile の設定を書くことができるようです。

```
$ cat ~/.oci/config
[DEFAULT]
user=ocid1.user.oc1..aaaaaaaanaeng2up6fae5ievee7waech3soo1oephahvieshee5ain5ceaga
fingerprint=96:6e:8d:9c:fb:a2:e8:e9:16:a3:68:f3:d6:d4:fd:06
key_file=/Users/teraoka/.oci/oci_api_key.pem
tenancy=ocid1.tenancy.oc1..aaaaaaaazoo7urooxee3to2shuha5roo2roh6pha0vooxohr9eiwee5nohy9
region=ap-tokyo-1
```

Object Storage の bucket 一覧を取得してみる。

```
$ oci os bucket list
Usage: oci os bucket list [OPTIONS]

Error: Missing option(s) --compartment-id.
```

`--compartment-id` ってのが必須らしい。**comparment-id** を取得するには `oci iam compartment list` で良さそう。[用語集](https://docs.cloud.oracle.com/ja-jp/iaas/Content/General/Reference/glossary.htm)によると**コンパートメント**とは「**組織の管理者から権限を付与された特定のグループのみがアクセスできる関連リソースのコレクション**」だそうです。デフォルトで root って呼ばれるコンパートメントが存在するんですけどそれを root という名前で使うことはできないんですね。

```
$ oci iam compartment list
{
  "data": [
    {
      "compartment-id": "ocid1.tenancy.oc1..aaaaaaaaiew1xaph0vei0thainoh9ikiod6fuxooquoo7ohxe9ahsh8booju",
      "defined-tags": {},
      "description": "xxxx",
      "freeform-tags": {},
      "id": "ocid1.compartment.oc1..aaaaaaaaque9quoowais0riey1ahcahniemahahquac3tu2jahogh4ees0la",
      "inactive-status": null,
      "is-accessible": null,
      "lifecycle-state": "ACTIVE",
      "name": "ManagedCompartmentForPaaS",
      "time-created": "2019-09-21T03:24:43.546000+00:00"
    }
  ]
}
```

長っ！

```
$ oci os bucket list --compartment-id ocid1.tenancy.oc1..aaaaaaaaiew1xaph0vei0thainoh9ikiod6fuxooquoo7ohxe9ahsh8booju
{
  "data": [
    {
      "compartment-id": "ocid1.tenancy.oc1..aaaaaaaaiew1xaph0vei0thainoh9ikiod6fuxooquoo7ohxe9ahsh8booju",
      "created-by": "ocid1.saml2idp.oc1..aaaaaaaaaiepeezeuwaijoo6xaivootahthiikiewauvahnga8eh4iequaej/xxxxxxxx@gmail.com",
      "defined-tags": null,
      "etag": "c8a9ff5e-bc4e-4141-8344-bb6aba10d7cd",
      "freeform-tags": null,
      "name": "blog-1q77-com",
      "namespace": "aeph4tie2ahm",
      "time-created": "2020-11-29T10:42:11.442000+00:00"
    }
  ]
}

```

めんどくさ... `--compartment-id` を[環境変数](https://docs.cloud.oracle.com/en-us/iaas/Content/API/SDKDocs/clienvironmentvariables.htm#CLI_Environment_Variables)か[設定ファイル](https://docs.cloud.oracle.com/en-us/iaas/Content/API/Concepts/sdkconfig.htm#File_Entries)に書ければ良いのですが、そんな設定は見当たらないですね...

ただ、bucket 内の object 一覧の取得時には指定の必要がないんですね。

```bash
oci os object list --bucket-name _BUCKET-NAME_
```

os サブコマンドは Object Storage の省略形。

次回は backup 用ユーザーの作成と、バックアップ用の最小権限設定を行って、object の put を行うところまでを書こうと思います。

その後、bucket に対する lifecycle 設定で古いファイルを自動で削除する設定を書こうかなと。

(記事中の id などはランダムに生成したものに置き換えています)
