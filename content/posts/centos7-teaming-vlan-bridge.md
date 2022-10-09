---
title: 'CentOS 7 の Teaming + VLAN + Bridge でハマる'
date: Sat, 14 May 2016 11:26:02 +0000
draft: false
tags: ['Linux', 'Network', 'linux', 'systemd']
---

CentOS 7 にて```
em1 ---+             +--- vlan2 --- br0
       +--- team0 ---+
em2 ---+             +--- vlan3 --- br1

```という Teaming で冗長化したインターフェースを VLAN で分割してそれぞれを Bridge にするというネットワーク構成にしようとして、2014年末頃には期待通りにどうさせず、次のようにつぶやいてたら

> team + vlan + bridge 構成にしようとすると NetworkManager が邪魔をするんですよねえ / “RHEL7/CentOS7 NetworkManager徹底入門” [http://t.co/zc2WHznEB8](http://t.co/zc2WHznEB8)
> 
> — yteraoka (@yteraoka) [2015年1月18日](https://twitter.com/yteraoka/status/556616999803969536)

中井さんが調べて Bugzilla に登録したりしてくださり、まとめページまでつくっていただけたので2016年に再チャレンジしたときにはすんなりできました。ありがとうございます。

> teaming + tag vlan + bridge がすんなりできた、ありがたや / “RHEL7/CentOS7のnmcliコマンドでBonding/VLAN/ブリッジを組み合わせる方法 - めもめも” [https://t.co/ZbSZOAJi8J](https://t.co/ZbSZOAJi8J)
> 
> — yteraoka (@yteraoka) [2016年4月13日](https://twitter.com/yteraoka/status/720106581300547584)

ががが、テスト用の環境でセットアップした際には期待通りに動作していたはずなのに実環境に持って行ったらなぜか vlan が片方だけしか Up しないという問題が発生...

> CentOS7のteaming-vlan-bridge構成で起動時にvlanが1つbring upでtimeoutする謎  
> nmcli d で connecting (prepare) と表示されており nmcli d connect vlan2 とするとつながる
> 
> — yteraoka (@yteraoka) [2016年4月21日](https://twitter.com/yteraoka/status/722974379210989568)

```
$ sudo systemctl status network.service -l
● network.service - LSB: Bring up/down networking
   Loaded: loaded (/etc/rc.d/init.d/network)
   Active: failed (Result: exit-code) since Thu 2016-04-21 09:31:10
JST; 1min 35s ago
     Docs: man:systemd-sysv-generator(8)
  Process: 11093 ExecStop=/etc/rc.d/init.d/network stop (code=exited,
status=0/SUCCESS)
  Process: 11775 ExecStart=/etc/rc.d/init.d/network start
(code=exited, status=1/FAILURE)

Apr 21 09:31:09 localhost network\[11775\]: Bringing up interface vlan-vlan2:  Error: Timeout 90 sec expired.
Apr 21 09:31:09 localhost network\[11775\]: \[FAILED\]
Apr 21 09:31:09 localhost network\[11775\]: Bringing up interface vlan-vlan3:  Connection successfully activated (D-Bus active path: /org/freedesktop/NetworkManager/ActiveConnection/14)
Apr 21 09:31:09 localhost network\[11775\]: \[  OK  \]
Apr 21 09:31:09 localhost network\[11775\]: Bringing up interface bridge-br0:  \[  OK  \]
Apr 21 09:31:10 localhost network\[11775\]: Bringing up interface bridge-br1:  \[  OK  \]
Apr 21 09:31:10 localhost systemd\[1\]: network.service: control process exited, code=exited status=1
Apr 21 09:31:10 localhost systemd\[1\]: Failed to start LSB: Bring up/down networking.
Apr 21 09:31:10 localhost systemd\[1\]: Unit network.service entered failed state.
Apr 21 09:31:10 localhost systemd\[1\]: network.service failed.

```調べたところ L2 switch との相性の問題なのかちょっと待ってから inteface を up させれば良いということが判明したので次のように service を作成して対応しました。 `/etc/systemd/system/wait-vlan-ready.service````
\[Unit\]
Description=Wait for VLAN ready state
Before=network.service

\[Service\]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sleep 20

\[Install\]
WantedBy=multi-user.target
``````
sudo systemctl daemon-reload
sudo systemctl enable wait-vlan-ready
````Before=network.servce` としてあるので network サービスを起動させる前に20秒 sleep することになります。