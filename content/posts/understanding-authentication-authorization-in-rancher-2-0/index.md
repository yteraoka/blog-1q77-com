---
title: 'Understanding Authentication & Authorization In Rancher 2.0'
date: Tue, 29 May 2018 15:13:28 +0000
draft: false
tags: ['Rancher']
---

Rancher 2.0 を使うメリットとして GUI でポチポチすることで helm から簡単にデプロイできたり、ポチポチ Ingress Controller の設定を行ったりできることもありますが、そのためには誰がどのリソースに対して何を行えるのかを制御できる必要があります。「[Understanding Authentication & Authorization In Rancher 2.0](https://rancher.com/blog/2018/2018-05-04-authentication-authorization-rancher2/)」に Rancher 2.0 の認証・認可についての説明がありました。Rancher 2.0 導入のメリットはココが大きいんじゃないかなと思っている。 **マルチクラウド＆マルチクラスターで統一した認証・認可ができます**

{{< figure src="rancher20-auth.png" alt="Rancher の Project" >}}

### Project

Rancher 2.0 には Kubernetes には無い **Project** というレイヤーがあります。**Project** は **namespace** の集合です。そしてこの **Project** に対して **Policy** を設定します。Policy は RBAC, Network acccess, Pod security, Quota を管理します。

### Template

**roleTemplates**, **clusterRoleTemplateBindings**, **projectRoleTemplateBindings** を使って同じ設定を簡単に使い回せます。管理者が作成したこれらのテンプレートを Cluster や Project のオーナーが使う（ユーザーに割り当てる）ことができます。

### Owner

ユーザーは自分のクラスタを作成し、その所有者となることができます。そして、他のユーザーやグループにクラスタの権限を設定できます。クラスタのメンバーとなったユーザーはプロジェクトを作成しそのオーナーになる。そして、また別のユーザーをプロジェクトのメンバーやオーナーとして招待することができます。プロジェクトメンバーはネームスペースを作成してワークロードをデプロイすることができます。

### podSecurityPoicy

どんなコンテナをデプロイ可能にするかを制御するために kubernetes には podSecurityPolicies がありますが、Rancher はこれの使いやすさを大きく改善しています。podSecurityPoicy テンプレートを管理でえきます。特権の使用を制限したり、使用可能な Capability を制限したり、使用可能な Volume Type を制限したり、ホストのファイルシステムへのアクセスを制限したりできます。 クラスタ所有者はプロジェクトごとに例外を管理することもできます。

### 認証

現状では Active DIrectory と GitHub での認証だけですが、今後 2.1 などで増えていく計画のようです（Rancher 1.x では Active Directory, Azure AD, GitHub, OpenLDAP, Shibboleth に対応しています）

### マルチクラウド

GKE (Google), AKS (Azure), EKS (AWS) はたまたオンプレの自前クラスタのどれを使っていても Rancher 経由で統一的に管理できます。それぞれにユーザーや権限を個別に管理する必要がないのです。 まあ、私も使うかどうかわかりませんけどね。
