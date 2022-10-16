---
title: 'oci コマンドでのファイルアップロードと権限の最小化'
date: Sat, 05 Dec 2020 01:18:51 +0900
draft: false
tags: ['OracleCloud', 'advent calendar 2020']
---

[Advent Calendar 2020 全部オレシリーズ](https://qiita.com/advent-calendar/2020/yteraoka) 5日目です。 やっと 20% です... まだ先は長い

前回の「[Oracle Cloud の oci コマンドセットアップ](/2020/12/setup-oci-command/)」で oci コマンドが使えるようになったので、これを使ってファイルを Oracle Cloud の Object Storage にアップロードします。

ファイルのアップロード
-----------

Put するには次のようなコマンドを実行します。もっと多くのオプションがありますが、単純にファイルを保存するだけならこれだけ。すでに存在するものを上書きする場合は `--force` が必要。

```bash
oci os object put \
  --namespace namespace \
  --bucket-name mybucket \
  --name myfile.txt \
  --file /Users/me/myfile.txt
```

`--namespace` は `-ns`、`--bucket-name` は `-bn` という省略形もあります。

Ojbect Storage のネームスペースはテナントごとに割り当てられるっぽく、[「管理」→「テナンシ詳細」](https://cloud.oracle.com/tenancy) で確認できます。しかし、まあこれが覚えられるようなものじゃなくてツライ...

さて、当初の目的はこの wordpress のデータのバックアップです。cron で実行することにしますが、その処理で使うアカウントの権限は最小にしておきたいものです。専用ユーザーを作って必要な権限だけを割り当てることにします。

ユーザーの作成
-------

[「アイデンティティ」→「ユーザー」](https://cloud.oracle.com/identity/users)で IAM ユーザーを作成します。説明にマルチバイト文字列が入れられるのは便利ですね。

{{< figure src="oci-create-user.png" caption="Create User" >}}

グループの作成
-------

次に[「アイデンティティ」→「グループ」](https://cloud.oracle.com/identity/groups)でグループを作成し、先ほど作成したユーザーをそのメンバーとして登録します。

{{< figure src="oci-create-group.png" caption="Create Group" >}}

権限設定
----

次に[「アイデンティティ」→「ポリシー」](https://cloud.oracle.com/identity/policies)でポリシーを作成します。

{{< figure src="oci-create-policy-1.png" caption="Create Policy (1)" >}}

ポリシービルダー欄の「ポリシー・ユース・ケース」で「ストレージ管理」を選択し、「共通ポリシー・テンプレート」で「ユーザーがオブジェクト・ストレージ・バケットにオブジェクトを書き込むことができるようにします」を選択すると、下にポリシー・ステートメントが表示され、「グループ」で先ほど作成したグループを選択して場所でテナント全体(ルート)かコンパートメントを選択するとポリシー・ステートメントが更新されます。

{{< figure src="oci-create-policy-2.png" caption="Create Policy (2)" >}}

これで出来上がったポリシーが次の2つ

```
Allow group wp-backup to read buckets in tenancy
```

```
Allow group wp-backup to manage objects in tenancy
 where any {request.permission='OBJECT_CREATE', request.permission='OBJECT_INSPECT'}
```

1つ目のポリシーでは bucket の一覧が参照可能ですが、特定の bucket 内へ書き込むだけなら不要なので削除します。2つ目のポリシーではテナント内の任意の bucket に対して書き込みができてしまうため、bucket も条件に追加したいです。そうすると次のようになります。

```
Allow group wp-backup to manage objects in tenancy
 where all {
         target.bucket.name='blog-1q77-com',
         any {
           request.permission='OBJECT_CREATE',
           request.permission='OBJECT_INSPECT'
         }
       }
```

**where** に `trget.bucket.name` 条件を追加しました、そして `request.permission` の条件と **AND** になるように `all { }` で囲みました。

AWS の IAM Policy だと「**どのリソースに対して何ができるのか**」を定義し、それを「誰か（ユーザー、グループ、ロール）」に紐づけるわけですが、Orale Cloud の場合は、このポリシー文の中に「誰」を含めるようになっています。今回の例では「`Allow group wp-backup`」とあり、wp-backup グループに対してオブジェクトの書き込み権限を設定するということになっています。これを踏まえたポリシーの名前付けをする必要があります。「ところ変われば・・・」ですね。

さて、これで完了かと思いきや、バックアップファイルの保存先を日付単位にしており、テストで同じ日に複数回実行しようとすると上書きができませんでした。`OBJECT_OVERWRITE` 権限が必要でした、一方、`OBJECT_INSPECT` は無くても問題ありませんでした。でこの2つを入れ替えて、最終的には次のポリシーとなりました。

```
Allow group wp-backup to manage objects in tenancy
 where all {
         target.bucket.name='blog-1q77-com',
         any {
           request.permission='OBJECT_CREATE',
           request.permission='OBJECT_OVERWRITE'
         }
       }
```

Object Storage の権原一覧は「[Details for Object Storage, Archive Storage, and Data Transfer](https://docs.cloud.oracle.com/en-us/iaas/Content/Identity/Reference/objectstoragepolicyreference.htm)」にありました。

* [How Policies Work](https://docs.cloud.oracle.com/en-us/iaas/Content/Identity/Concepts/policies.htm)
* [Securing Object Storage](https://docs.cloud.oracle.com/en-us/iaas/Content/Security/Reference/objectstorage_security.htm)
* [Details for Object Storage, Archive Storage, and Data Transfer](https://docs.cloud.oracle.com/en-us/iaas/Content/Identity/Reference/objectstoragepolicyreference.htm)
