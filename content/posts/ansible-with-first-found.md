---
title: '#ansible の copy/template で例外対応'
date: Wed, 06 Nov 2013 05:05:45 +0000
draft: false
tags: ['Ansible']
---

例外対応って言っても、stacktrace 出すとかじゃないです。ほとんどのサーバーでは共通なんだけど、一部のサーバーでだけ変えたい設定への対応方法です。 変数の値だけで対応できる範囲なら、グループやデフォルトで設定する値をホストなどの変数で上書きしてあげればOKデスね。 こんな感じで

```yaml
test_src_filename: "default"
```

```yaml
test_src_filename: "host01"
```

```yaml
- copy: src={{test_src_filename}}.conf dest=/etc/aaa/bbb.conf
```

でも、それでは難しいって場合は `with_first_found` ってのが使えるんです。

[Selecting Files And Templates Based On Variables](http://www.ansibleworks.com/docs/playbooks_conditionals.html#selecting-files-and-templates-based-on-variables) で見つけました。

でも試したら、ここに書いてある通りでは動かなかったので [source code](https://github.com/ansible/ansible/blob/devel/lib/ansible/runner/lookup_plugins/first_found.py) を見て試してみました。

copy 元ファイルや template ファイルをリストで指定して、最初に見つかったファイルが使われるんです。 きっと使いたい場面が出てきますよね。

例

```yaml
- copy: src={{item}} dest=/some/where/test.conf
  with_first_found:
    - files:
        - "{{ ansible_hostname }}.conf"
        - default.conf
      skip: true
```

この例のように files に変数を使う場合はクオートする必要がありました。シングルクオートでもダブルクオートでも可。 `skip: true` を付けるとマッチするファイルが見つけられなかった場合もエラーとはならず skip されます。この例の場合は default.conf にはマッチするように用意するはずですが、特定のホストでしか必要の無いファイルだったりする場合に使えますね。 `ignore_errors: true` でもエラー時にそこで停止せずに先に進めますが、この場合は register で登録した結果は failed です（ここを書き換える方法もありますが）。 source code のコメントにあるように探すディレクトリも paths: で複数指定できますし、files にディレクトリを含めることも可能です。 次はこれを template で試してみます。

```yaml
- template: src={{item}} dest=/some/where/test.conf
  with_first_found:
    - files:
        - '{{ansible_hostname}}.conf.j2'
        - default.conf.j2
```

これでイケそうなものですが、なぜかファイル名が None で、role の template directory と ansible の root directory を探しにいってしまい、そんなのねーよとなってしまいます。

```yaml
- template: src={{item}} dest=/some/where/test.conf
  with_first_found:
    - files:
        - '/home/ytera/ansible/roles/test/templates/{{ansible_hostname}}.conf.j2'
        - /home/ytera/ansible/roles/test/templates/default.conf.j2
```

もしくは

```yaml
- template: src={{item}} dest=/some/where/test.conf
  with_first_found:
    - files:
        - '{{ansible_hostname}}.conf.j2'
        - default.conf.j2
      paths:
        - /home/ytera/ansible/roles/test/templates/
```

とすることで期待の動作をしてくれました。うむむ、ソースを読みとかないとダメか。 なんか Python で書かれているにしてはやけに書き方にバリエーションがありますね Ansible って。

次回は [fileglob](https://github.com/ansible/ansible/blob/devel/lib/ansible/runner/lookup_plugins/fileglob.py) を試してみたいと思います。指定のディレクトリ下のファイルを一括でコピーできそうです。
