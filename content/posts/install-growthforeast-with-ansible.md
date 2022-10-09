---
title: 'Ansible で Growthforecast をインストールする方法'
date: Wed, 14 Aug 2013 16:08:50 +0000
draft: false
tags: ['Ansible']
---

最近 Ansible ブームな私としては [Docker で Growthforecast をインストールする方法](http://blog.64p.org/entry/2013/08/14/185519) を見ると、Ansible でもやりたくなってしまうのです。ということで、サクッと GrowthForecast をインストールする Playbook をちゃちゃっと書いてみました。 まだブラッシュアップの余地はありますし、CentOS 向けのところしか書いてない。 Debian / Ubuntu とか他の Linux Distribution 用のところは誰かよろしく。Gentoo だとオレオレ ebuild 書けばこんなのいらない？ 今回の Playbook は AWX のインストーラーを参考にしたので [Ansible AWX を試す その2 #ansible](/2013/08/ansible-awx-part2/) が参考になります。 Playbook は GitHub ( [https://github.com/yteraoka/growthforecast-playbook](https://github.com/yteraoka/growthforecast-playbook) ) にあげておいたので次のようにすれば GrowthForecast が CentOS 6 で使えるようになります。

```
$ git clone https://github.com/yteraoka/growthforecast-playbook.git
$ cd growthforecast-playbook
$ ansible-playbook -i hosts site.yml
```

Ansible のインストール方法は [Ansible Tutorial](http://yteraoka.github.io/ansible-tutorial/) あたりを読んでいただければ良いのではないかと。 ACアダプタ無しの Ultrabook で試してると perl の compile や cpanm GrowthForecast に時間がかかりすぎるわぁ... あら、なんか graph のフォントの問題があるかな。
