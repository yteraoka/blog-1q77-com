---
title: 'AWX (OSS 版 Ansible Tower) を試す'
date: Fri, 23 Mar 2018 13:22:38 +0000
draft: false
tags: ['Ansible']
---

### インストール

CentOS 7 で [Installing AWX](https://github.com/ansible/awx/blob/devel/INSTALL.md) にある Docker を使ったインストールで試します。 必要なパッケージのインストール

```
$ sudo yum -y install git ansible docker python-docker-py
```

docker daemon の起動

```
$ sudo systemctl start docker
$ sudo systemctl enable docker
```

AWX リポジトリを clone して、installer ディレクトリにある install.yml を ansible-playbook で実行する なにもいじらないで実行すれば docker でのインストールになる

```
$ git clone https://github.com/ansible/awx.git
$ cd awx/installer
$ sudo ansible-playbook -i inventory install.yml
```

playbook が完走すると awx, memcached, RabbitMQ, PostgreSQL のコンテナが起動しています

```
$ sudo docker ps
CONTAINER ID        IMAGE                     COMMAND                  CREATED              STATUS              PORTS                                NAMES
eca1ee848e82        ansible/awx_task:latest   "/tini -- /bin/sh ..."   About a minute ago   Up About a minute   8052/tcp                             awx_task
e57ea0f64383        ansible/awx_web:latest    "/tini -- /bin/sh ..."   2 minutes ago        Up 2 minutes        0.0.0.0:80->8052/tcp                 awx_web
aeadac6dc4fe        memcached:alpine          "docker-entrypoint..."   5 minutes ago        Up 5 minutes        11211/tcp                            memcached
b3777fcbf06a        rabbitmq:3                "docker-entrypoint..."   5 minutes ago        Up 5 minutes        4369/tcp, 5671-5672/tcp, 25672/tcp   rabbitmq
5da460e26ea0        postgres:9.6              "docker-entrypoint..."   6 minutes ago        Up 6 minutes        5432/tcp                             postgres
```

これで port 80 にアクセスすると DB の migration が始まって、完了後に使えるようになります。

{{< figure src="awx-upgrading.png" >}}

ログイン画面が表示されたら ID: admin Password: password でアクセスできます。
ダッシュボード画面

{{< figure src="awx-dashboard.png" caption="AWX DASHBOARD" >}}

### 使ってみる

ちょっと最初はわかりにくい 上から順にいくと、`PROJECTS` で playbook のリポジトリを設定します。Git や Mercurial、Subversion の repository を指定したり、ローカルファイルシステムのディレクトリを指定します。

次に `CREDENTIALS` で ansible でセットアップするサーバーにアクセスするための SSH の秘密鍵やユーザー名を登録する。

`INVENTORIES` で `ansible-playbook` コマンドの `-i` で指定する inventory ファイル相当のホスト情報を設定する。プロジェクトのリポジトリにインベントリファイルが含まれる場合はそれを指定することも可能です。

ここまでできたら `TEMPLATES` でこれらのオブジェクトを組み合わせてどのホストに対してどの Playbook を実行するのかを定義する 設定例として入ってる Demo Project の設定内容 ([https://github.com/ansible/ansible-tower-samples](https://github.com/ansible/ansible-tower-samples) が登録されています)

{{< figure src="awx-demo-project.png" caption="AWX Demo Project" >}}

INVENTORIESに「My Inventory」という名前で3台のホスト(node-1, node-2, node-3)を設定してみたところ

{{< figure src="aws-inventory-hosts.png" caption="AWX Inventory Hosts" >}}

Demo Project を先の3台のホスト(Inventory)に対して実行するための Template 設定。この環境は Vagrant で構築してるので Vagrant という名前で CREDENTIALS に SSH の秘密鍵を登録してあります。Demo Project で指定されたリポジトリ内の `hello_world.yml` という Playbook を実行するようになっています

{{< figure src="awx-test-template.png" caption="AWX Test Template" >}}

Template の一覧画面、ロケットアイコンをクリックすると実行されます

{{< figure src="awx-templates.png" caption="AWX Templates" >}}

実行結果画面

{{< figure src="awx-jobs.png" caption="AWX Jobs" >}}

### lightbulb の playbook を実行してみる

[https://github.com/ansible/lightbulb](https://github.com/ansible/lightbulb) に Ansible の学習用コンテンツがあります。ここの examples 下にある playbook を AWX で実行してみます。

まずは [apache-simple-playboook](https://github.com/ansible/lightbulb/tree/master/examples/apache-simple-playbook) を使ってみます。

lightbulb プロジェクトを作成します

{{< figure src="awx-project-lightbulb.png" caption="AWX Project lightbulb" >}}

`Get latest SCM revsion` という雲に下矢印のアイコンをクリックするとリポジトリのファイルが取得され、Template 作成時に playbook の YAML をリストから選択できるようになります

{{< figure src="awx-projects.png" caption="AWX Projects" >}}

`apache-simple-playbook/site.yml` を実行するテンプレートを作成します

{{< figure src="awx-template-simple-apache.png" caption="AWX Simple Apache Template" >}}

apache-simple-playbook は `web` グループのホストに対して実行するようになっているため Inventory 設定で web グループに参加させます

{{< figure src="awx-inventory-web-group.png" caption="AWX Inventory web group" >}}

実行された Job の情報

{{< figure src="awx-simple-apache-job.png" caption="AWX Simple Apache Job" >}}

ansible-playbook の出力はテキストでダウンロードも可能です

```
Identity added: /tmp/awx_17_8I3LZB/credential_2 (/tmp/awx_17_8I3LZB/credential_2)


PLAY [Ensure apache is installed and started] **********************************

TASK [Gathering Facts] *********************************************************
ok: [node-3]
ok: [node-1]
ok: [node-2]

TASK [Ensure httpd package is present] *****************************************
changed: [node-1]
changed: [node-3]
changed: [node-2]

TASK [Ensure latest index.html file is present] ********************************
changed: [node-3]
changed: [node-1]
changed: [node-2]

TASK [Ensure httpd is started] *************************************************
changed: [node-1]
changed: [node-3]
changed: [node-2]

PLAY RECAP *********************************************************************
node-1                     : ok=4    changed=3    unreachable=0    failed=0   
node-2                     : ok=4    changed=3    unreachable=0    failed=0   
node-3                     : ok=4    changed=3    unreachable=0    failed=0   
```

### その他、より高度な使い方

AWX へのログイン認証には `Azure AD`, `GitHub`, `GitHub Org`, `GitHub Team`, `Google OAuth2`, `LDAP`, `RADIUS`, `SAML`, `TACACS+` が使えるようになっています。

ユーザーごとの権限設定も可能で、どの playbook を誰が実行できるようにするかを制御できます。サーバーへ SSH したり sudo する権限が無い人でもサーバーへのログイン情報は AWX で管理されているため playbook を使った設定変更などは行えるようになります。

NOTIFICATION 設定では `Email`, `Slack`, `Twilio`, `Pagerduty`, `HipChat`, `Webhook`, `Mattermost`, `IRC` を使った通知設定が可能になっています。

CREDENTIALS ではさまざまなタイプの認証情報が登録でき、その中に Vault もあり、TEMPLATE には複数の Credentials が設定できるため Ansible Vault も認証情報を追加すれば問題なく使えるようです。

INVENTORIES では SOURCE という設定があり `Sourced from a Project`, `Amazon EC2`, `Google Compute Engine`, `Microsoft Azure Resource Manager`, `VMware vCenter`, `Red Hat Satellite 6`, `Red Hat CloudForms`, `OpenStack`, `Red Hat Virtualization`, `Ansible Tower`, `Custom Script` があり、これらからホスト情報を簡単に取得して Inventory として使えるようになっているようです。 実行時に都度変数を指定するために Ansible では `vars_prompt` でプロンプトを表示して入力させることができますが、AWX (Ansible Tower) ではこれが使えず、代わりに Template で `Survey` を設定します。

Ansible Tower って日本語ドキュメントもそろってるんですね、さすが Red Hat さん [http://docs.ansible.com/ansible-tower/](http://docs.ansible.com/ansible-tower/) 昔の自分が同じタイトルの記事を書いてたことを見つけてしまった

* [Ansible AWX を試す その1 #ansible](/2013/08/ansible-awx-part1/)
* [Ansible AWX を試す その2 #ansible](/2013/08/ansible-awx-part2/)

Ansible Tower はもともと AnsibleWorks AWX という名前だったのですね。

ansibleworks.com ドメインが保育士求人サイトによって買われてるのか...
