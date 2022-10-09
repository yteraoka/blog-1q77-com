---
title: 'Rancher HA 1コマンドセットアップを Helm 版にした'
date: Wed, 27 Mar 2019 16:49:22 +0000
draft: false
tags: ['Rancher']
---

「[続 Rancher 2.0 の HA 構成を試す](/2018/05/rancher-2-0-ha-install-using-terraform-and-rke/)」で DigitalOcean に Rancher の HA 環境を1コマンドでセットアップするスクリプトの紹介をしていたのですが、そこで使っていた RKE Add-on 方式はもう古いということが[前回](/2019/03/rancher-migrating-from-an-ha-rke-add-on-install/)判明したので [helm](https://helm.sh/) でセットアップするように書き換えました。

RKE Add-on 版では Rancher 2.0.8 までにしか対応していなかったのですが、helm 対応により [GA になったばかり](https://rancher.com/blog/2019/rancher-2-2-hits-ga-milestone/)の [2.2](https://rancher.com/products/rancher/2.2/) も使えます。スクリプトの中では rancher-latest を使うようになっているので今実行すると 2.2 がセットアップされるはずです。2.0.8 と比べた構成の違いとして大きいのは以前は Kubernentes クラスタ内に1コンテナしか起動していなかったのが、複数コンテナに対応していることですね。3台のサーバーで3つのコンテナが起動してました。

自分が使いたいから書いただけですが [Github](https://github.com/yteraoka/rancher-ha-tf-do) にあります。

[https://github.com/yteraoka/rancher-ha-tf-do](https://github.com/yteraoka/rancher-ha-tf-do)