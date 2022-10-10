---
title: 'Ansible でユーザーを一括作成する'
date: Mon, 19 Aug 2013 14:54:40 +0000
draft: false
tags: ['Ansible']
---

Ansible でユーザーアカウントを一括で作成する方法です。 [user モジュール](http://yteraoka.github.io/ansible-tutorial/ansible-in-detail.html#module-user) では次のようにして OS アカウントを作成することができますが、沢山のユーザーを作成したい場合どう書くのが良いのでしょうか。

```yaml
- user: name=john comment="John Doe" uid=1040 group=admin
```

次のように `with_items` を使うことで loop 処理ができますが、これでは uid や group、コメントが指定できません。

```yaml
- user: name={{item}}
  with_items:
    - john
    - bob
    - alice
```

`with_items` にはハッシュのリストを指定することもできるので

```yaml
- user: name={{item.name}} uid={{item.uid}} comment="{{item.comment}}" group={{item.group}}
  with_items:
    - { name: 'john',  uid: 1001, group: 'users', comment: 'John Doe' }
    - { name: 'bob',   uid: 1002, group: 'users', comment: 'スポンジ Bob' }
    - { name: 'alice', uid: 1003, group: 'users', comment: '不思議の国の Alice' }
```

さらに、変数は group\_vars などのディレクトリに別ファイルで作成することで

```yaml
users:
  - { name: 'john',  uid: 1001, group: 'users', state: 'present', comment: 'John Doe' }
  - { name: 'bob',   uid: 1002, group: 'users', state: 'present', comment: 'スポンジ Bob' }
  - { name: 'alice', uid: 1003, group: 'users', state: 'present', comment: '不思議の国の Alice' }
```

```yaml
- user: name={{item.name}} uid={{item.uid}} comment="{{item.comment}}" group={{item.group}} state={{item.state}}
  with_items: users
```

こんな感じでどうでしょう？ [External Inventory Scripts](http://www.ansibleworks.com/docs/api.html#external-inventory-scripts) を使うことでもっとうまく管理することができるかもしれない。
