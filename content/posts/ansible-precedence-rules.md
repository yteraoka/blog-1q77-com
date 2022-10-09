---
title: 'Ansible の変数の優先順'
date: Sat, 19 Oct 2013 16:05:07 +0000
draft: false
tags: ['Ansible', 'ansible']
---

[Changes in Ansible Variable Precedence Between v1.2 and v1.3](http://blog.gridkick.com/post/63665128174/changes-in-ansible-variable-precedence-between-v1-2-and) を見たら Ansible の変数の優先順が version 1.2 と 1.3 で変わってるって書いてあるじゃないですか！！ まだ本格導入してないから大丈夫だけど、この手のツールのバージョンアップは慎重に行う必要がありますね。 やらなきゃなぁと思っていた変数の優先度整理をこれを機にやってみました。 [https://github.com/cookrn/ansible\_variable\_precedence](https://github.com/cookrn/ansible_variable_precedence) に変数の優先度確認用の Playbook があったので、これを参考にテストしてみました。 上記の README.md には順序が次のように書かれていましたが、あれ？ちょっと違うんじゃね？というのと、もうちょい詳しく知りたいと思ってテスト用 Playbook を書いてテストしてみました。

> 1.  Register Variables
> 2.  Ansible assigned fact vars
> 3.  Role Dependency Parameters
> 4.  Vars file vars
> 5.  Command line extra var
> 6.  Playbook vars
> 7.  Playbook Role parameter
> 8.  Role var
> 9.  Inventory Host variable
> 10.  Inventory Group variable
> 11.  Role default variable

setup モジュールで設定される facts については ansible\_ prefix が付くし、被らないかなということでテストに含めませんでした。 ちなみに、オレオレ fact を /etc/ansible/facts.d/test.fact に書くとこんな感じで読み込まれました。```
{
    "ansible\_facts": {
        "ansible\_local": {
            "test": {
                "test\_var": "a fact var"
            }
        }
    }
}

```

### 1.3 でのテスト結果

ansible のバージョン 1.3.2 でのテスト結果です。```
$ ansible --version
ansible 1.3.2

```

1.  当該 task 中で register を使って登録した値
2.  コマンドラインオプションで指定した値```
     --extra-vars "name=value"
    ```
3.  (依存先 role においては meta/main.yml の dependencies 内で設定した値)```
    dependencies:
      - role: dep\_role
        test\_var: "set in dependencies"
    ```
4.  依存 role の task の中で register を使って登録した値
5.  playbook ファイルの role 指定するところで設定した値```
      roles:
        - { role: role\_name, var\_name: 123}
    ```
6.  playbook の vars\_file で指定したファイル内で設定した値```
      vars\_file:
        - vars/test.yml
    ```
7.  playbook の vars で指定した値```
      vars:
        test\_var: defined in playbook vars
    ```
8.  当該 role の vars/main.yml で設定した値
9.  依存 role の vars/main.yml で設定した値
10.  inventroy ファイルのホスト変数```
    \[local\]
    localhost test\_var="defined in inventory:host"
    ```複数のグループに所属するために、同一ホストが複数回登場する場合は、最後に設定された変数が有効となる
11.  inventory ファイルのグループ変数```
    \[local:vars\]
    test\_var="defined in inventory:group"
    ```
12.  host\_vars ディレクトリのホスト名ファイルで設定した値
13.  group\_vars ディレクトリのグループ名ファイルで設定した値  
    (複数グループに入っている場合にどれが適用されるかは source code を読まないとわからない。後日読んでみる)
14.  group\_vars/all ファイルで設定した値
15.  当該 role の defaults/main.yml で設定した値
16.  依存 role の defaults/main.yml で設定した値

変数優先度のテスト結果は次の通りです。変数定義する箇所多すぎ。

### 1.2 でのテスト結果

1.2.2 でもテストしてみました。```
$ ansible --version
ansible 1.2.2

```1.2 には dependencies 機能がありません。 role 内の defaults 変数も未サポートっぽい。

1.  当該 task の register で登録した値
2.  コマンドラインオプションで設定した値
3.  playbook ファイルの role 指定するところで設定した値
4.  playbook の vars\_file で指定したファイル内で設定した値
5.  当該 role の vars/main.yml で設定した値
6.  playbook の vars で指定した値
7.  inventroy ファイルのホスト変数
8.  inventory ファイルのグループ変数
9.  host\_vars ディレクトリのホスト名ファイルで設定した値
10.  group\_vars ディレクトリのグループ名ファイルで設定した値
11.  group\_vars/all ファイルで設定した値