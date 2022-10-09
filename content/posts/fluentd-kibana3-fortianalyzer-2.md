---
title: '続オレオレFortiAnalyzer'
date: Sat, 19 Oct 2013 02:18:40 +0000
draft: false
tags: ['FortiGate', fluentd']
---

[Fluentd + Kibana3 で FortiAnalyzer いらず](/2013/10/fluentd-kibana3-fortianalyzer/) の続きです。 前回、CSVフォーマットに対応しようと書いたので対応させてみました。Parser はまたベンチマークとってみたところ、CSVじゃないバージョンよりも軽くなってました。 これも Gist に置いてあります。 [https://gist.github.com/yteraoka/7043113](https://gist.github.com/yteraoka/7043113) ただ、 CSV フォーマットにも罠がありました！ strptime になぜかコケる...

```
Oct 19 00:00:00 fortigate date=2013-10-18,time=23: 59:59,...
```

ん？んんん？時と分の間に謎の空白が！！

### FortiGate の Syslog 設定について

Webインターフェースでは Syslog に traffic ログや webfilter ログを出力する設定が無いのですが、CLI で操作することで出力することができます。 Syslog も FortiAnalyzer 用出力もそれぞれ3つの出力設定が可能です。 [fortigate-cli-40-mr3.pdf](http://208.91.113.73/fgt/handbook/40mr3/fortigate-cli-40-mr3.pdf)

* syslogd
* syslogd2
* syslogd3
* fortianalyzer
* fortianalyzer2
* fortianalyzer3

2,3 は GUI からアクセスできません。GUI からアクセスできる syslogd も traffic ログなどを設定する項目は GUI に無いので、これは触らないことにしておいて syslogd2 を使ってこれらのログを出力することにします。

```
$ show log syslogd2 setting
config log syslogd2 setting
    set status enable
    set server "10.20.30.40"
    set csv enable
    set facility local6
end
```

syslog (2じゃない) の出力項目の確認をしてみます。

```
$ show log syslogd filter
config log syslogd filter
    set email disable
    set traffic disable
    set web disable
    set infected disable
end
```

email, traffic, web, infected が disable にされています。だから syslog2 では filter は空っぽにしておけば全部出せます。

### strptime の cache

strptime って実は結構重い処理だったということで、最近、Fluentd の TextParser には strptime の結果を cache する仕組みが入りました。FortiGate のログも traffic ログや webfilter ログを出してると秒間そこそこの量のログが吐き出されます。こういう場合は cache が欲しいです。追加してみよう。

### パフォーマンス面

30,000〜50,000 lines / min くらいでは特に問題は発生していないですね。 不要な項目は ElasticSearch に送らないようにしているので 5GB のログファイルから生成される ElasticSearch のインデックスファイルは 1GB 程度。 ElasticSearch のサーバーは KVM Guest で 2GB RAM、 JVM の heap は 1GB. KVM Host の Storage は RAID5 でそんなに速くない。CPU は Xeon 5570 で 2 vCPU 割り当てている。でも CPU はあまり使われていない。 特に困ったこともないのでチューニングもしていない。 syslog サーバーでの Fluentd の CPU 使用率は高い。
