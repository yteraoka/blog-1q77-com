---
title: 'KVMでnwfilterを使ってトラッフィクを制御する'
date: Wed, 04 Mar 2015 15:38:26 +0000
draft: false
tags: ['KVM', 'Linux', 'nwfilter']
---

仮想サーバーとして KVM を使用していますが、同居 VM のトラフィックが無視できなくなったのでなんとかできないかと調査したところ nwfilter というものがあったのでこれで制御することにしました。 [libvirt: Network Filters](https://libvirt.org/formatnwfilter.html)

### nwfilter の一覧を確認

`nwfilter-list` サブコマンドで定義済みフィルターの一覧が確認できます。

```
$ sudo virsh nwfilter-list
UUID                                  Name                 
----------------------------------------------------------------
85626774-2856-297d-983f-fecb05dc8b0d  allow-arp
b84e8f59-4fd8-add9-def1-894340211cb4  allow-dhcp
a316dd94-c7c1-6aa2-2aa1-e2177ae08639  allow-dhcp-server
643613e5-3c4e-2380-8d6a-20550faf0234  allow-incoming-ipv4
40ed48cb-aaf3-bdc0-3638-b7e081820984  allow-ipv4
eb6b8d68-92a9-7d1c-7344-aaa8c3ca9284  clean-traffic
c2165185-ad1f-0831-8ecc-03e6a3a458d6  no-arp-ip-spoofing
4a3faac2-fb68-be19-2d47-279428ddd1dd  no-arp-mac-spoofing
bfd9a7ab-8890-2aed-54ae-af4ea6316d20  no-arp-spoofing
28fc5edb-e04d-3aaa-66d9-a39d4557dde7  no-ip-multicast
5fb20664-40ca-e724-fd66-9f67c312270f  no-ip-spoofing
acd88779-283a-f7f0-f821-7552baa49690  no-mac-broadcast
48e0b0dc-6b2e-56ac-034f-da0a4b1d110e  no-mac-spoofing
ee18e17e-b539-e365-71e2-4d34613556c1  no-other-l2-traffic
ae70065b-b6b7-841e-5af9-5c9c9ad1ccf4  no-other-rarp-traffic
724421c2-add7-09b2-de72-c6e171579769  qemu-announce-self
5ac97619-ab7f-15b1-c05a-1c18d4d669c5  qemu-announce-self-rarp
```

### フィルターの定義内容を確認する

このフィルターの定義内容は `nwfilter-dumpxml` で確認できます

```
$ sudo virsh nwfilter-dumpxml clean-traffic
 eb6b8d68-92a9-7d1c-7344-aaa8c3ca9284 
```

`<filterref>` は `filter` 名の別のフィルターがそこに読み込まれます。 `<filterref filter='no-mac-spoofing'/>` には次の内容が入ります。

```
$ sudo virsh nwfilter-dumpxml no-mac-spoofing
 48e0b0dc-6b2e-56ac-034f-da0a4b1d110e 
```

### フィルターをゲストに適用する

`virsh edit domain` で対象ゲストの設定を編集します。 ネットワークインターフェース (`<interface>`) の中に `<filterref>` を書きます。


パラメータの不要なフィルターの場合は `<filterref filter='filtername'/>` だけとなります。
"`IP`" は <ip address='192.168.122.5' prefix='24'/> を <interface> に書くことでも指定できるようです。ない場合は最初のパケットから抽出されるようです。

`clean-taffic` は source MAC アドレスや IP アドレスを偽装したパケットを通さないようにするフィルターです。

### 新しくフィルターを定義する

今回やりたかったのはそのゲストと関係ないとトラフィックが流れてくるのを止めたかったので `clean-taffic` を参考に自作してみます。

multicast は通すけど IPv4 のその他は自分の IP アドレス宛でなかったら drop します。

```
sudo virs nwfilter-define my-allow-ipv4.xml
sudo virs nwfilter-define my-clean-traffic.xml
```

後は各 Guest の interface 設定に追記します。 
