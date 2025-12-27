---
title: 'Oracle Cloud の Object Storage での Lifecycle Policy 設定'
date: Sun, 06 Dec 2020 13:09:31 +0900
draft: false
tags: ['OracleCloud', 'Advent Calendar 2020']
---

[Advent Calendar 2020 全部オレシリーズ](https://qiita.com/advent-calendar/2020/yteraoka) 6日目です。

前2回の内容で Object Storage に日次のバックアップファイルを保存するようにしましたが、ファイル名に日付を入れるようにしたため、古いものを削除しないと無駄な費用が発生してしまいます。そこで [Lifecycle Policy](https://docs.cloud.oracle.com/ja-jp/iaas/Content/Object/Tasks/usinglifecyclepolicies.htm) を使って古いものを削除する設定を行います。

サービス権限
------

Object Storage サービスが私の Object を削除することになるため、サービスに対してそれを許可するという「[サービス権限](https://docs.cloud.oracle.com/ja-jp/iaas/Content/Object/Tasks/usinglifecyclepolicies.htm#permissions)」設定する必要があります。

サービス権限は[「アイデンティティ」→「ポリシー」](https://cloud.oracle.com/identity/policies)で設定します。グループに対して許可する場合は `Allow group ...` でしたが、サービスであるため `Allow service ...` とします。で対象となるサービスは objectstorage なので objectstorage-<region\_identifier> を指定するようです。東京リージョンの場合は objectstorage-ap-tokyo-1 となります。([リージョンおよび可用性ドメイン](https://docs.cloud.oracle.com/ja-jp/iaas/Content/General/Concepts/regions.htm))

`to manage object-family` では `in` で指定された範囲の Object Storage の管理権限が与えられるようです。([ポリシー・リファレンス](https://docs.cloud.oracle.com/ja-jp/iaas/Content/Identity/Reference/policyreference.htm))

```
Allow service objectstorage-<region_identifier>
 to manage object-family in compartment <compartment_name>
```

`to manage object-family` の代わりに個別の権限も設定出来るということなので次のようにしてみました。

```
Allow service objectstorage-ap-tokyo-1
 to {BUCKET_INSPECT, BUCKET_READ, OBJECT_INSPECT, OBJECT_CREATE, OBJECT_DELETE}
 in tenancy
 where target.bucket.name='blog-1q77-com'
```

Bucket の Lifecycle Policy 設定
----------------------------

[オブジェクト・ストレージ](https://cloud.oracle.com/object-storage/buckets)で対象のバケットを選択し**ライフサイクル・ポリシー・ルール**から**ルールの作成**ボタンをクリックして作成します。Amazon S3 のやつと似た感じですね。

{{< figure src="oci-create-lifecycle-policy.png" >}}
