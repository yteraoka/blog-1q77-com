---
title: 'FortiGate さんごめんなさい、悪いのは rsyslog でした'
date: Fri, 20 Mar 2015 15:49:37 +0000
draft: false
tags: ['FortiGate', 'fluentd']
---

その昔 「[続オレオレFortiAnalyzer](/2013/10/fluentd-kibana3-fortianalyzer-2/)」という記事を書きました。 何故か FortiGate のログの時刻フォーマットに余計なスペース(0x20)が入ってて困るという話。 ががが！！今日見てみたらスペースが入ってなかったのです。あれ？ FortiOS の更新してないのになぜ？あっ、rsyslog から syslog-ng に変えたせいかっ！ ということで、再度 rsyslog で確認してみるとやっぱり `date=2015-03-20,time=12: 34:56` となる。 どうやら rsyslog は tag が必須なのかログメッセージの最初のコロン(:)までをタグとして扱い、 `tag: msg` というフォーマットで書きだすようです。 確かに tcpdump で見ても送られてくるデータにこのスペースは含まれていませんでした。 そう、FortiGate さんのバグではなかったのです。ごめんなさい。 つーことで gem を更新しました。 [https://rubygems.org/gems/fluent-plugin-fortigate-log-parser](https://rubygems.org/gems/fluent-plugin-fortigate-log-parser)
