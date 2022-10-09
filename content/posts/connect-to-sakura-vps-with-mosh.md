---
title: 'さくらのVPSに mosh で接続'
date: Wed, 19 Dec 2012 13:48:49 +0000
draft: false
tags: ['Linux', 'mosh']
---

iPhone アプリの [iSSH](https://itunes.apple.com/jp/app/issh-ssh-vnc-console/id287765826?mt=8) が [mosh](http://mosh.mit.edu/) をサポートしたというのでさくらインターネットで借りてる [VPS](http://vps.sakura.ad.jp/) に mosh でログインできるようにしてみました。 VPS は CentOS 6 で epel リポジトリに mosh があったので```
sudo yum install mosh

```VPS で UDP 60000 - 61000 ポートを開放 (ポートは変更可能)```
sudo iptables -A INPUT -m udp -p udp --dport 60000:61000 -j ACCEPT (たとえば)

```まずは手元の Linux Mint 14.1 からログインできるように```
sudo apt-get install mosh

```SSH の設定は ~/.ssh/config で Host vps として設定済み```
mosh vps

```次に iSSH からの接続テスト、でも LANG が C だとダメらしく /etc/sysconfig/i18n で LANG=en\_US.UTF=8 にして再起動したらつながりました。 Linux から接続すると mosh-server の引数で LANG が設定されてるけど、iSSH だと設定されてないのが原因っぽい```
$ ps -ef | grep mosh
ytera     1720     1  0 22:18 ?        00:00:01 mosh-server new -s -c 8 -l LANG=ja\_JP.UTF-8
ytera     2033     1  0 22:45 ?        00:00:00 mosh-server new

```

[![iSSH - SSH / VNC Console](http://a1927.phobos.apple.com/us/r1000/119/Purple/v4/0a/ff/07/0aff072e-5425-7033-24c1-7e026f5c9079/icon.png "iSSH - SSH / VNC Console")](https://itunes.apple.com/jp/app/issh-ssh-vnc-console/id287765826?mt=8&uo=4)

[iSSH - SSH / VNC Console](https://itunes.apple.com/jp/app/issh-ssh-vnc-console/id287765826?mt=8&uo=4)  
Zinger-Soft  
価格： 850円 [![iTunesで見る](http://ax.phobos.apple.com.edgesuite.net/ja_jp/images/web/linkmaker/badge_appstore-sm.gif)](https://itunes.apple.com/jp/app/issh-ssh-vnc-console/id287765826?mt=8&uo=4)  
posted with [sticky](http://sticky.linclip.com/linkmaker/) on 2012.12.19  

iSSH は SSH Tunnel + RemoteDesktop も簡単にできるし、Bluetooth keyboard で Ctrl key も使えてとっても便利。 アプリとしてはちょっと高めだけど価格なりの価値はあります。安いのを沢山試すくらいならこれでOK

*   [Jun Mukai's blog: mosh (mobile shell)の論文を読んでみた](http://blog.jmuk.org/2012/04/mosh-mobile-shell.html)
*   [#16 「moshは確かにイノベーション」 tech.kayac.com Advent Calendar 2012 | tech.kayac.com - KAYAC engineers' blog](http://tech.kayac.com/archive/16_advent_calender_2012.html)