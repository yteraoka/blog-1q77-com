---
title: '#ansible の copy/template で例外対応'
date: Wed, 06 Nov 2013 05:05:45 +0000
draft: false
tags: ['Ansible', 'ansible']
---

例外対応って言っても、stacktrace 出すとかじゃないです。ほとんどのサーバーでは共通なんだけど、一部のサーバーでだけ変えたい設定への対応方法です。 変数の値だけで対応できる範囲なら、グループやデフォルトで設定する値をホストなどの変数で上書きしてあげればOKデスね。 こんな感じで```
test\_src\_filename: "default"

``````
test\_src\_filename: "host01"

``````
\- copy: src={{test\_src\_filename}}.conf dest=/etc/aaa/bbb.conf

```でも、それでは難しいって場合は with\_first\_found ってのが使えるんです。 [Selecting Files And Templates Based On Variables](http://www.ansibleworks.com/docs/playbooks_conditionals.html#selecting-files-and-templates-based-on-variables) で見つけました。 でも試したら、ここに書いてある通りでは動かなかったので [source code](https://github.com/ansible/ansible/blob/devel/lib/ansible/runner/lookup_plugins/first_found.py) を見て試してみました。 copy 元ファイルや template ファイルをリストで指定して、最初に見つかったファイルが使われるんです。 きっと使いたい場面が出てきますよね。 例```
\- copy: src={{item}} dest=/some/where/test.conf
  with\_first\_found:
    - files:
        - "{{ ansible\_hostname }}.conf"
        - default.conf
      skip: true

```この例のように files に変数を使う場合はクオートする必要がありました。シングルクオートでもダブルクオートでも可。 `skip: true` を付けるとマッチするファイルが見つけられなかった場合もエラーとはならず skip されます。この例の場合は default.conf にはマッチするように用意するはずですが、特定のホストでしか必要の無いファイルだったりする場合に使えますね。 `ignore_errors: true` でもエラー時にそこで停止せずに先に進めますが、この場合は register で登録した結果は failed です（ここを書き換える方法もありますが）。 source code のコメントにあるように探すディレクトリも paths: で複数指定できますし、files にディレクトリを含めることも可能です。 次はこれを template で試してみます。```
\- template: src={{item}} dest=/some/where/test.conf
  with\_first\_found:
    - files:
        - '{{ansible\_hostname}}.conf.j2'
        - default.conf.j2

```これでイケそうなものですが、なぜかファイル名が None で、role の template directory と ansible の root directory を探しにいってしまい、そんなのねーよとなってしまいます。```
\- template: src={{item}} dest=/some/where/test.conf
  with\_first\_found:
    - files:
        - '/home/ytera/ansible/roles/test/templates/{{ansible\_hostname}}.conf.j2'
        - /home/ytera/ansible/roles/test/templates/default.conf.j2

```もしくは```
\- template: src={{item}} dest=/some/where/test.conf
  with\_first\_found:
    - files:
        - '{{ansible\_hostname}}.conf.j2'
        - default.conf.j2
      paths:
        - /home/ytera/ansible/roles/test/templates/

```とすることで期待の動作をしてくれました。うむむ、ソースを読みとかないとダメか。 なんか Python で書かれているにしてはやけに書き方にバリエーションがありますね Ansible って。 次回は [fileglob](https://github.com/ansible/ansible/blob/devel/lib/ansible/runner/lookup_plugins/fileglob.py) を試してみたいと思います。指定のディレクトリ下のファイルを一括でコピーできそうです。