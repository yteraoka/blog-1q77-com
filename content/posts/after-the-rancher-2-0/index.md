---
title: 'Rancher 2.0.8 までの変更点まとめ'
date: Mon, 10 Sep 2018 16:51:26 +0000
draft: false
tags: ['Kubernetes', 'Rancher']
---

Rancher 2.1 の話がぜんぜん聞こえてこないなーどうなってるのかな？と思って GitHub の [releases](https://github.com/rancher/rancher/releases) ページを覗いてみたらいつの間にか 2.0.8 がリリースされていました。

ということで各バージョンでの変更点を見てみましょう。

### v2.0.1 (2018/5/23)

[releases/tag/v2.0.1](https://github.com/rancher/rancher/releases/tag/v2.0.1)

* Workloads/Services/Namespaces を YAML で import/export できるようになった [#12371](https://github.com/rancher/rancher/issues/12371)
* RoleTemplates に `protected` 状態が追加された [#13418](https://github.com/rancher/rancher/issues/13418)
* CLI に複数の機能が追加された [#12831](https://github.com/rancher/rancher/issues/12831), [#13101](https://github.com/rancher/rancher/issues/13101), [#13235](https://github.com/rancher/rancher/issues/13235), [#13390](https://github.com/rancher/rancher/issues/13390), [#13518](https://github.com/rancher/rancher/issues/13518)

### v2.0.2 (2018/5/24)

[releases/tag/v2.0.2](https://github.com/rancher/rancher/releases/tag/v2.0.2)

* 2.0.1 で GitHub 認証が動作しなくなってしまったことの修正 [#13665](https://github.com/rancher/rancher/issues/13665)
* [アップグレードとロールバックをサポート](https://rancher.com/docs/rancher/v2.x/en/upgrades/)

### v2.0.3 (2018/6/23)

[releases/tag/v2.0.3](https://github.com/rancher/rancher/releases/tag/v2.0.3)

* Oauth provider として AzureAD が追加された [#12942](https://github.com/rancher/rancher/issues/12942)
* クラスタ作成時のオプション([RKE configuration options](http://staging.rancher.com/docs/rke/v0.1.x/en/config-options/)) 指定がフルサポートされた [#13816](https://github.com/rancher/rancher/issues/13816), [#13076](https://github.com/rancher/rancher/issues/13076), [#13115](https://github.com/rancher/rancher/issues/13115)
* AKS の更新への対応 (multi K8S versions, DNS prefix, private network and subnet) [#13395](https://github.com/rancher/rancher/issues/13395)
* CLI の強化 [#13701](https://github.com/rancher/rancher/issues/13701)
* 多くのバグフィックス
* 更新後に ingress が正しく機能しなくなる既知の問題がある、ワークアラウンドは ingress の再作成 [#13611](https://github.com/rancher/rancher/issues/13611)

### v2.0.4 (2018/6/26)

[releases/tag/v2.0.4](https://github.com/rancher/rancher/releases/tag/v2.0.4)

* カタログの更新が出来なかった問題の修正 [#14186](https://github.com/rancher/rancher/issues/14186), [#14183](https://github.com/rancher/rancher/issues/14183)
* 更新後に ingress が正しく機能しなくなる既知の問題がある、ワークアラウンドは ingress の再作成 [#13611](https://github.com/rancher/rancher/issues/13611)

### v2.0.5 (2018/7/8)

[releases/tag/v2.0.5](https://github.com/rancher/rancher/releases/tag/v2.0.5)

* 新規クラスタ作成時のデフォルトネットワークプロバイダが `canal` から `flannel` に変更されたため、ネットワークポリシーを使いたい場合は `canal` を指定する必要がある
* 認証プロバイダとして `OpenLDAP` がサポートされた、ただし、匿名バインディングのみ [#13814](https://github.com/rancher/rancher/issues/13814)
* 認証プロバイダとして `FreeIPA` がサポートされた [#13815](https://github.com/rancher/rancher/issues/13815)
* ノードの `cordon`/`uncordon` がサポートされた。`cordon` 状態では新たな Pod がスケジュールされない。`drain` は既存 Pod を停止して別のノードへ移動させるが `cordon` は既存 Pod には影響しない [#13623](https://github.com/rancher/rancher/issues/13623)
* AKS 対応の強化。advanced networking options が使えるようになった [#14164](https://github.com/rancher/rancher/issues/14164)
* CLI の強化
* バグ修正

既知の問題

* Active Directory のグループ再帰検索がデフォルトで無効になった [#14369](https://github.com/rancher/rancher/issues/14369), [#14482](https://github.com/rancher/rancher/issues/14482)
* RacherOS, CoreOS, boot2docker のようなパーシステントディレクトリを持たない OS では更新時に証明書が見つからなくてコケる [#14454](https://github.com/rancher/rancher/issues/14454)
* 2.0.5 と 2.0.6 で Active Directory を使っている場合、サービスアカウントの ID でにドメインも指定しなければならなくなった [#14708](https://github.com/rancher/rancher/issues/14708)

### v2.0.6 (2018/7/12)

[releases/tag/v2.0.6](https://github.com/rancher/rancher/releases/tag/v2.0.6)

* Active Directory と OpenLDAP でネストされたグループの検索が遅い問題が解消された。AzureAD と FreeIPA にこの問題はなかった [#14482](https://github.com/rancher/rancher/issues/14482)
* RancherOS, CoreOS, boot2docker などで更新にコケる問題が解消された [#14454](https://github.com/rancher/rancher/issues/14454)
* OpenLDAP で匿名バインドしか使えなかった問題が解消された [#12729](https://github.com/rancher/rancher/issues/12729), [#14456](https://github.com/rancher/rancher/issues/14456)
* デフォルトのネットワークプロバイダが `canal` に戻された [#14462](https://github.com/rancher/rancher/issues/14462)

### v2.0.7 (2018/8/13)

[releases/tag/v2.0.7](https://github.com/rancher/rancher/releases/tag/v2.0.7)

* パフォーマンス改善 [#14372](https://github.com/rancher/rancher/issues/14372), [#14402](https://github.com/rancher/rancher/issues/14402), [#14409](https://github.com/rancher/rancher/issues/14409)
* `canal` のネットワークポリシーがデフォルトで無効になった [#14462](https://github.com/rancher/rancher/issues/14462)
* [PING Federate](https://www.pingidentity.com/) (SAML?) が認証プロバイダに追加された [#11169](https://github.com/rancher/rancher/issues/11169)
* ADFS が認証プロバイダに追加された [#14609](https://github.com/rancher/rancher/issues/14609)
* ユーザーの初回ログイン時に割り当てられるデフォルトロールを設定できるようになった [#12737](https://github.com/rancher/rancher/issues/12737)
* Rancher API の監査ログを取得可能になった [#12733](https://github.com/rancher/rancher/issues/12733)
* `System Project` というプロジェクトが追加され、Rancher や Kubernetes 自身のネームスペースはここに入るようになった [#12706](https://github.com/rancher/rancher/issues/12706)
* `restricted` と `unrestricted` という2つのデフォルト Pod security policy が追加された [#12832](https://github.com/rancher/rancher/issues/12832)
* RKE のクラスタに Metric サーバーをデプロイ可能になった [#13745](https://github.com/rancher/rancher/issues/13745)
* GKE, EKS のより良い管理のためにフィールドが追加された [#14566](https://github.com/rancher/rancher/issues/14566), [#13789](https://github.com/rancher/rancher/issues/13789)
* Kubernetes 1.11 がサポートされ [#13837](https://github.com/rancher/rancher/issues/13837)、1.8 での新規作成がサポートがサポートされなくなった [#14517](https://github.com/rancher/rancher/issues/14517)
* Docker machine が v0.15.0 に更新され、cn-northwest-1 リージョンがサポートされた [#11192](https://github.com/rancher/rancher/issues/11192)
* NGINX ingress controller が v1.16 に更新された [#13294](https://github.com/rancher/rancher/issues/13294)
* Helm が v2.9.1 に更新された [#14023](https://github.com/rancher/rancher/issues/14023)
* 多数のバグフィックス

### v2.0.8 (2018/8/25)

[releases/tag/v2.0.8](https://github.com/rancher/rancher/releases/tag/v2.0.8)

* Kubernetes 1.11.1 には正しい Cipher Suite が含まれていなかったため 1.11.2 に更新しましょう [#15120](https://github.com/rancher/rancher/issues/15120)
* Etcd の起動に10秒以上かかる場合に単一サーバーでのセットアップに失敗する可能性があった問題の修正 [#15077](https://github.com/rancher/rancher/issues/15077)
* 他バグ修正

### まとめ？

てな感じです。認証プロバイダの追加は運用面では大きいですかね。2.0.8 での認証プロバイダ選択画面は次のようになっています

{{< figure src="rancher-208-authentication.png" >}}

RKE クラスタ作成時のオプション選択はこんな感じ

{{< figure src="rancher-208-customize-cluster-options.png" >}}

ドキュメントも揃ってきてますかね

* [Rancher 2.0](https://staging.rancher.com/docs/rancher/v2.x/en/)
* [RKE](https://staging.rancher.com/docs/rke/v0.1.x/en/)
