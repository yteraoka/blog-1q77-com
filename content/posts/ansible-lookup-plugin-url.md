---
title: 'Ansible で変数を URL から読み込む'
date: Sat, 14 Sep 2019 12:54:17 +0000
draft: false
tags: ['Ansible', 'ansible']
---

外部のサービスとの連携などで IP アドレスを使った設定をすることがあります。この場合に、その相手がテキストや JSON で IP アドレスのリストを公開してくれていれば、Ansible ではその URL から直接変数に取り込むことが可能です。

[Lookup Plugin](https://docs.ansible.com/ansible/latest/plugins/lookup.html) の [url](https://docs.ansible.com/ansible/latest/plugins/lookup/url.html) というやつを使います。試してみましょう。

[Stripe](https://stripe.com/jp) は [Domains and IP Addresses](https://stripe.com/docs/ips) というページで IP アドレスの情報を公開していますが [https://stripe.com/files/ips/ips\_webhooks.txt](https://stripe.com/files/ips/ips_webhooks.txt) や [https://stripe.com/files/ips/ips\_webhooks.json](https://stripe.com/files/ips/ips_webhooks.json) でテキストや JSON で公開してくれています。

次の Playbook を site.yml として保存して実行してみます。

```
\- hosts: all
  gather\_facts: no
  vars:
    text1: "{{ lookup('url', 'https://stripe.com/files/ips/ips\_webhooks.txt') }}"
    text2: "{{ lookup('url', 'https://stripe.com/files/ips/ips\_webhooks.txt', wantlist=True) }}"
    json1: "{{ lookup('url', 'https://stripe.com/files/ips/ips\_webhooks.json') }}"
    json2: "{{ lookup('url', 'https://stripe.com/files/ips/ips\_webhooks.json', split\_lines=False) }}"
  tasks:
    - name: text1
      debug:
        var: text1
    - name: text2
      debug:
        var: text2
    - name: json1
      debug:
        var: json1
    - name: json2
      debug:
        var: json2

``````
$ ansible-playbook -i localhost, site.yml --connection=local

PLAY \[all\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*

TASK \[text1\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*
ok: \[localhost\] =>
  text1: 54.187.174.169,54.187.205.235,54.187.216.72,54.241.31.99,54.241.31.102,54.241.34.107

TASK \[text2\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*
ok: \[localhost\] =>
  text2:
  - 54.187.174.169
  - 54.187.205.235
  - 54.187.216.72
  - 54.241.31.99
  - 54.241.31.102
  - 54.241.34.107

TASK \[json1\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*
ok: \[localhost\] =>
  json1: "{,\\t\\"WEBHOOKS\\":\[,\\t\\t\\"54.187.174.169\\",,\\t\\t\\"54.187.205.235\\",,\\t\\t\\"54.187.216.72\\",,\\t\\t\\"54.241.31.99\\",,\\t\\t\\"54.241.31.102\\",,\\t\\t\\"54.241.34.107\\",\\t\],}"

TASK \[json2\] \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*
ok: \[localhost\] =>
  json2:
    WEBHOOKS:
    - 54.187.174.169
    - 54.187.205.235
    - 54.187.216.72
    - 54.241.31.99
    - 54.241.31.102
    - 54.241.34.107

PLAY RECAP \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*
localhost                  : ok=4    changed=0    unreachable=0    failed=0

```

*   テキストファイルは1行1アドレスのリストですが、text1 の方法では各行がカンマ区切りで1つの文字列として取り込まれました
*   text2 は `wantlist=True` を指定したことで各行を要素としたリストとして取り込まれました
*   json1 は JSON という形式を無視して text1 と同様に各行がカンマ区切りで1つの文字列として取り込まれました
*   json3 は `split_lines=False` と指定したことで JSON の構造を維持した状態で取り込まれました

以上