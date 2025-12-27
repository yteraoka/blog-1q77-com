---
title: 'AnsibleでGCEサーバーをセットアップする'
date: Wed, 02 Jul 2014 15:29:09 +0000
draft: false
tags: ['Ansible', 'GCE', 'Google']
---

{{< x user="ansible" id="482323942427099136" >}}

> A quick demo of Ansible and GCE [http://t.co/6rqxSt41NL](http://t.co/6rqxSt41NL)
> 
> — Ansible (@ansible) [2014, 6月 27](https://x.com/ansible/statuses/482323942427099136)

という tweet を見て、Docker Meetup で GCE の $500 分クーポンをもらっていたのを思い出したので試してみました。

ブラザから操作してみる
-----------

まずは、Ansible を使わないでブラウザからインスタンスを立ち上げてみます。[https://console.developers.google.com/](https://console.developers.google.com/) Web Console から手動でインスタンスを立ち上げるには、プロジェクトを作成・選択し、画面左にあるメニューから「COMPUTE」→「COMPUTE ENGINE」→「VMインスタンス」→「Spin up VMs fast」で「Create an instance」 次のような入力・選択項目がありました。

*   名前
*   メタデータ （任意の名前と値）
*   HTTPトラフィックを許可する
*   HTTPSトラフィックを許可する
*   ゾーン
    *   asia-east1-a
    *   asia-east1-b
    *   europe-west1-a
    *   europe-west1-b
    *   us-centra11-a
    *   us-central1-b
*   マシンタイプ
    *   f1-micro (vCPU 1 個、メモリ 0.6 GB)
    *   n1-standard-1 (vCPU 1 個、メモリ 3.8 GB)
    *   g1-small (vCPU 1 個、メモリ 1.7 GB)
    *   n1-highcpu-2 (vCPU 2 個、メモリ 1.8 GB)
    *   n1-highcpu-4 (vCPU 4 個、メモリ 3.6 GB)
    *   n1-highcpu-8 (vCPU 8 個、メモリ 7.2 GB)
    *   n1-highcpu-16 (vCPU 16 個、メモリ 14.4 GB)
    *   n1-highmem-2 (vCPU 2 個、メモリ 13 GB)
    *   n1-highmem-4 (vCPU 4 個、メモリ 26 GB)
    *   n1-highmem-8 (vCPU 8 個、メモリ 52 GB)
    *   n1-standard-1 (vCPU 1 個、メモリ 3.8 GB)
    *   n1-standard-2 (vCPU 2 個、メモリ 7.5 GB)
    *   n1-standard-4 (vCPU 4 個、メモリ 15 GB)
    *   n1-standard-8 (vCPU 8 個、メモリ 30 GB)
    *   n1-standard-16 (vCU 16 個、メモリ 60 GB)
*   ブートソース
    *   イメージからディスクを新規作成
    *   スナップショットからディスクを新規作成
    *   既存のディスク
*   イメージ
    *   backports-debian-7-wheezy-v20140619
    *   debian-7-wheezy-v20140619
    *   centos-6-v20140619
    *   sles-11-sp3-v20140609
    *   rhel-6-v20140619
*   ディスクタイプ
    *   Standard Persistent Disk
    *   SSD Persistent Disk
*   ネットワーク
    *   default （最初から存在するネットワーク 10.240.0.0/16 だった）
    *   新規作成
*   外部IP
    *   エフェメラル
    *   新しい静的IPアドレス

SSH でログインしてみる
-------------

インスタンス起動後のログインには [gcutil](https://developers.google.com/compute/docs/gcutil/) が必要でした。 インストールは簡単

```
$ curl https://sdk.cloud.google.com | bash
```

インストールしたらログインする必要があります。

```
$ gcloud auth login
```

ログインしたらプロジェクトを指定します

```
$ gcloud config set project  
```

インスタンスを確認してみます

```
$ gcutil listinstances
+------------+--------------+---------+----------------+-----------------+
| name       | zone         | status  | network-ip     | external-ip     |
+------------+--------------+---------+----------------+-----------------+
| instance-1 | asia-east1-b | RUNNING | 10.240.249.235 | 107.167.xxx.yyy |
+------------+--------------+---------+----------------+-----------------+
```

次のコマンドで ssh 接続できます

```
$ gcutil ssh instance-1
```

SSH 接続に先だって `~/.ssh/google_compute_engine` の公開鍵がコピーされます。この鍵がまだ作成されていない場合はここで作成されます。 zone や project も指定できます

```
$ gcutil --service_version="v1" --project="プロジェクトID" ssh --zone="asia-east1-b" "インスタンス名"
```

公開鍵がコピーされた後は普通に ssh コマンドで接続できます。 コマンドラインでインスタンスの作成なども結構簡単にできるみたいです。

*   [Google Compute Engine を使ってみる(1) プロジェクト作成から Google Cloud SDK インストールまで #gcloud #gce](http://jitsu102.hatenablog.com/entry/2014/05/18/183133)
*   [Google Compute Engine を使ってみる(2) インスタンスの起動と削除 #gcloud #gce](http://jitsu102.hatenablog.com/entry/2014/07/01/072422)

Ansible でやってみる
--------------

それでは Ansible でセットアップしてみましょう。[GoogleCloudPlatform/compute-video-demo-ansible](https://github.com/GoogleCloudPlatform/compute-video-demo-ansible) リポジトリを使わせていただきます。

```
$ git clone https://github.com/GoogleCloudPlatform/compute-video-demo-ansible.git
```

Ansible の他に apache-libcloud が必要となるので pip でインストールします。

```
$ sudo pip install apache-libcloud
```

[Google Deveopers Console](https://console.developers.google.com/project/appyt/apiui/credential) の 「APIS & AUTH」→「認証情報」で「新しいクライアントIDを作成」からサービスアカウントを作成します。この過程でキーが生成されます。パスフレーズは `notasecret` になっています。 これを `~/gce-privatekey.p12` として保存したとします。pkcs12 フォーマットでは Ansible (libcloud) で扱えないため PEM に変換します。

```
$ openssl pkcs12 -in ~/gce-privatekey.p12 \
  -passin pass:notasecret -nodes -nocerts \
  | openssl rsa -out ~/gce-privatekey.pem
```

Ansible の Playbook で使う変数を設定します。 GCE の inventory で必要になる設定は `gce.ini` に書きます。すでに libcloud を使っていれば `secrets.py` に設定済みかもしれませんが、私はお初なので `gce.ini` の `gce_service_account_email_address`, `gce_service_account_pem_file_path`, `gce_project_id` を設定しました。`gce_service_account_email_address` は web console で作成したサービスアカウントのものです。`gce_service_account_pem_file_path` は先ほど PEM に変換したもの。 次にケチってインスタンスタイプを f1-micro に変えます。

```
$ sed -i 's/n1-standard-1/f1-micro/g' gce_vars/machines
```

zone (リージョン) も us から asia に変更します。

```
$ sed -i 's/us-central1/asia-east1/g' \
  gce_vars/lb gce_vars/zonea gce_vars/zoneb cleanup.yml
```

さて、ここからがハマりポイントでした。インベントリファイルであろう `ansible_hosts` に書いてあるのはこれだけです。

```
[local]
127.0.0.1

[gce_instances]
myinstance[1:4]
```

んんん？ myinstance1,2,3,4 のIPアドレスとかはどうやって知るの？ instance の作成までは local へ接続して行うので可能なのですが web.yml にある Web サーバーセットアップができません。 これはどうやら gce.py というインベントリスクリプトを使うらしい。 が、[plugins/inventory/gce.py](https://github.com/ansible/ansible/blob/devel/plugins/inventory/gce.py) は Ansible の GitHub リポジトリにはあるのに pip でインストールされたファイルの中にはありません... ムムム。ないものはしかたないので GitHub から `gce.py` だけダウンロードして使いました。 これはこういうものらしい。

{{< x user="r_rudi" id="483986662322475008" >}}

> [@yteraoka](https://x.com/yteraoka) inventoryのファイルはインストールされないはずです。githubからダウンロードする必要があるかと思います。
> 
> — shirou - しろう (@r\_rudi) [2014, 7月 1](https://x.com/r_rudi/statuses/483986662322475008)

それでは `-i` で gce.py を指定して実行してみよう。Dynamic Inventory ってやつですね。

```
$ export GCE_INI_PATH=./gce.ini
$ chmod a+x gce.py
$ ansible-playbook -i gce.py site.yml
```

あれ... ダメじゃん gce.py で取得できる情報には `local` というグループも `gce_instances` というグループもないんですね。 なんと、Ansible は `-i` でディレクトリを指定すると複数のインベントリファイル、スクリプトの内容をマージしてくれるんですね。[Using Multiple Inventory Sources](http://docs.ansible.com/intro_dynamic_inventory.html#using-multiple-inventory-sources) ということで

```
$ mkdir inventory
$ mv ansible_hosts inventory/
$ mv gce.py inventory/
```

そんでもってついでに `ansible_hosts` はちょいといじっておきます

```
[local]
127.0.0.1 ansible_connection=local

[gce_instances]
myinstance[1:4] ansible_ssh_private_key_file=/home/xxx/.ssh/google_compute_engine
```

何を変えたかというと、localhost への接続に SSH を使う必要はないので `ansible_connection` を `local` に変更。GCE インスタンスには `~/.ssh/google_compute_engine` の公開鍵がコピーされるので ssh 接続時にはこの秘密鍵を使うように `ansible_ssh_private_key_file` を設定。

新しいインスタンスで毎回 host key の確認をするのは面倒なので環境変数 `ANSIBLE_HOST_KEY_CHECKING` を `False` にします。

```
$ export GCE_INI_PATH=./gce.ini
$ export ANSIBLE_HOST_KEY_CHECKING=False
$ ansible-playbook -i inventory site.yml
```

これでやっと動きます。4つのインスタンスが Web サーバーとしてセットアップされ、1つのロードバランサーの下にセットされます。ロードバランサーのIPアドレスを調べてアクセスしてみましょう。

終わったら `cleanup.yml` を使って消しておきましょう。

```
$ export GCE_INI_PATH=./gce.ini
$ export ANSIBLE_HOST_KEY_CHECKING=False
$ ansible-playbook -i inventory cleanup.yml
```

`gcutil` ってコマンドラインでいろいろできて便利ですね

気になった方はお試しあれ。

でも今回試した Playbook は全部のインスタンスに Global IP アドレスがふられちゃいます。VPN 接続して private address だけでやるか SSH の踏み台サーバーを立ててそこを経由させるようなことも必要かな。
