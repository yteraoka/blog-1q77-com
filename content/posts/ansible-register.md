---
title: 'Ansible でコマンドの出力を後の task で使う'
date: Wed, 12 Feb 2014 14:10:04 +0000
draft: false
tags: ['Ansible']
---

[Ansible Advent Calendar 2013](http://qiita.com/advent-calendar/2013/ansible) のネタとして書こうとした残骸があったので、書いてみる。 Ansible は task の実行結果を [register](http://docs.ansible.com/playbooks_conditionals.html#register-variables) という設定で変数に保存できます。 rc でコマンドの exit code に、stdout / stderr で標準出力/標準エラーにアクセスできます。```
\# mod\_passenger.so のインストールされているべきパスを取得する
- name: get mod\_passenger.so path
  shell: /opt/ruby-{{ ruby\_version }}/bin/passenger-install-apache2-module --snippet | grep passenger\_module | awk '{print $3}'
  register: mod\_passenger\_path
  changed\_when: False

# 先の結果を利用して mod\_passenger.so の存在確認を行う
- name: check mod\_passenger.so installed
  command: test -f {{ mod\_passenger\_path.stdout }}
  register: mod\_passenger\_installed
  failed\_when: mod\_passenger\_installed.rc not in \[0, 1\]
  changed\_when: False

# mod\_passenger.so がまだ存在しなかったら build する
- name: build mod\_passenger.so
  environment:
    PATH: "/opt/apache\_{{ httpd\_version }}/bin/:/bin:/usr/bin:/usr/local/bin"
  command: >
    /opt/ruby-{{ ruby\_version }}/bin/passenger-install-apache2-module
    --apxs2-path /opt/apache\_{{ httpd\_version }}/bin/apxs --auto
    creates={{ mod\_passenger\_path.stdout }}
  when: mod\_passenger\_installed.rc == 1

# httpd.conf に書く passenger の設定を取得する
- name: get passenger snippet
  command: >
    /opt/ruby-{{ ruby\_version }}/bin/passenger-install-apache2-module
    --snippet
  changed\_when: False
  register: passenger\_snippet

# template で先の snippet を使う
- name: httpd.conf
  template: >
    src=httpd.conf.j2
    dest=/opt/apache\_{{ httpd\_version }}/conf/httpd.conf
    owner=root group=root mode=0644
  notify: restart httpd

```httpd.conf.j2 の中で次の様に register で保存した値を使うことができます。```
{{ passenger\_snippet.stdout }}
{% if passenger\_snippet.stdout %}
PassengerPoolIdleTime 1200
PassengerMaxPoolSize 5
#PassengerPreStart http://localhost/
{% endif %}

````changed_when: False` はコマンドが exit code = 0 で終了すると changed として扱われて、「えっなんか変更された？」ってちょっとビビるのを回避するためです。 `failed_when: mod_passenger_installed.rc not in [0, 1]` は test コマンドでファイルが存在しなかった場合に failed として扱われて「ドキッ」としないためです。`ignore_errors: True` としても赤字で表示されちゃうので。