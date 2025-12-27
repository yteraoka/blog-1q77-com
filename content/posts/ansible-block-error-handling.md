---
title: 'Ansible の block でエラーハンドリング'
date: Sat, 14 Sep 2019 10:24:18 +0000
draft: false
tags: ['Ansible']
---

Ansible で一連の処理を実行する際に、途中で失敗したらそれまでの変更も元に戻したいといったことがあるかもしれません。そんな場合に使えるのが [Block](https://docs.ansible.com/ansible/latest/user_guide/playbooks_blocks.html) 機能です。Ansible 2.3 （[2017年4月](https://github.com/ansible/ansible/blob/stable-2.3/CHANGELOG.md#23-ramble-on---2017-04-12)）から使える結構古い機能です。

存在は知っていたけど使ったことなかったのでどんなものか試してみます。

block 内の task が失敗した場合に、block 内の以降の処理をスキップして rescue 内の task が実行されます。 rescue 内の task が失敗するとそこでそのホストへの処理は中断されます。

次のように書けば step 2 でコケて rescue の task が実行される

```
\- hosts: all
  gather\_facts: no
  tasks:
    - name: some procedure
      block:
        - name: step 1
          command: /bin/true
        - name: step 2 \# 失敗する
          command: /bin/false
        - name: step 3 \# 前の task が失敗しているため実行されない
          command: /bin/true
      rescue:
        \# block 内がすべて成功していれば rescue 内は実行されない
        - name: rescue 1
          command: /bin/false
          \# 失敗すると継続の処理が実行されないため false にする
          failed\_when: false
        - name: rescue 2
          debug:
            msg: "Rescue 2"
        - name: failed task
          debug:
            \# 失敗した task の情報が ansible\_failed\_task 変数に入っている
            var: ansible\_failed\_task.name
        - name: failed result
          debug:
            \# 失敗した task の結果が ansible\_failed\_result 変数入っている、register で登録されるのと同じ内容
            var: ansible\_failed\_result

```

上記の Playbook を site.yml として保存し、実際に実行してみると次のようになります。（環境変数 `ANSIBLE_STDOUT_CALLBACK` を `yaml` にしているため出力が JSON ではなく YAML になっています）

```
$ ansible-playbook -i localhost, site.yml --connection=local

PLAY \[all\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*

TASK \[step 1\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*
changed: \[localhost\]

TASK \[step 2\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*
fatal: \[localhost\]: FAILED! => changed=true
  cmd:
  - /bin/false
  delta: '0:00:00.007922'
  end: '2019-09-14 08:51:21.915700'
  msg: non-zero return code
  rc: 1
  start: '2019-09-14 08:51:21.907778'
  stderr: ''
  stderr\_lines: \[\]
  stdout: ''
  stdout\_lines: TASK \[rescue 1\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*
changed: \[localhost\]

TASK \[rescue 2\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*
ok: \[localhost\] =>
  msg: Rescue 2

TASK \[failed task\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*
ok: \[localhost\] =>
  ansible\_failed\_task.name: step 2

TASK \[failed result\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*
ok: \[localhost\] =>
  ansible\_failed\_result:
    changed: true
    cmd:
    - /bin/false
    delta: '0:00:00.007922'
    end: '2019-09-14 08:51:21.915700'
    failed: true
    invocation:
      module\_args:
        \_raw\_params: /bin/false
        \_uses\_shell: false
        argv: null
        chdir: null
        creates: null
        executable: null
        removes: null
        stdin: null
        warn: true
    msg: non-zero return code
    rc: 1
    start: '2019-09-14 08:51:21.907778'
    stderr: ''
    stderr\_lines: \[\]
    stdout: ''
    stdout\_lines: \[\]

PLAY RECAP \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*
localhost                  : ok=5    changed=2    unreachable=0    failed=1 
```
