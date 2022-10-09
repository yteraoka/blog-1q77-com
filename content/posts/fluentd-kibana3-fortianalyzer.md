---
title: 'Fluentd + Kibana3 で FortiAnalyzer いらず (更新あり)'
date: Thu, 10 Oct 2013 14:19:58 +0000
draft: false
tags: ['FortiGate', 'fluentd', 'kibana3', 'syslog']
---

2013-10-15 ちょいと更新 いや、[FortiAnalyzer](http://www.fortinet.co.jp/products/fortianalyzer/) 使ったこと無いんでホントに代わりになるかどうか知らないんですけど、お高いんですよ（ね？）今はクラウド版っつーのもあるみたいですね。 で、FortiAnalyzer が無いとログをマトモに見れないのかなぁなんて思ってたんですけど、どうやって Analyzer にログ送ってるんだろう？って試したら Syslog (UDP) だったんですね。TCP の 514 にも謎のパケットが飛んでるけどそっちは放置。 Syslog だったらファイルに書き出したものを [Fluentd](http://fluentd.org/) でなんとでもなるぞと。 ログのフォーマットは次のような感じで key=value がスペース区切りで並んでいます。value にスペースが含まれる可能性のある場合はクオートされます key="aaa bbb" のように。ただし、 service という項目だけはスペースを含む可能性があるのにクオートされません。でも幸い、この項目にスペースが入るのはカスタム設定で自分でスペースを入れて設定した場合のみなので回避可能です。

```
Oct 10 00:00:00 192.168.1.1 date=2013-10-09 time=23:59:59 devname=FG..... device_id=FG... \
  type=traffic subtype=other pri=warning status=deny vd="root" \
  src=192.168.1.2 srcname=192.168.1.2 src_port=1234 \
  dst=192.168.1.255 dstname=192.168.1.255 \
  dst_country="Reserved" src_country="Reserved" ....
```

これの parser を Fluentd の plugin として書きました。 [https://gist.github.com/yteraoka/6911252](https://gist.github.com/yteraoka/6911252) FortiGate のログはすごく項目が多くて、Kibana3 で見る必要の無い項目は ElasticSearch に入れたくなかったので必要な項目だけに絞るか、不要な項目を削るという機能を入れました。需要なさそうだから gem にしたりしない。/etc/td-agent/plugins/ に置けば使えるので。

> ※ 2013-10-15追記 (1) 書いてる時からヒドいなぁと思いながらいた Loop での gsub! はやっぱりとっても重いので書き直しました。Gist に Bench も載っけておきました。

ここまで来れば、後は [fluent-plugin-elasticsearch](https://github.com/uken/fluent-plugin-elasticsearch) で [ElasticSearch](http://www.elasticsearch.org/) に突っ込んで [Kibana3](http://www.elasticsearch.org/overview/kibana/) で自由自在です。Kibana3 については前回の 「[Kibana3 を使ってみよう](/2013/10/lets-try-kibana3/)」 をどうぞ。 FortiGate のログには src\_country, dst\_country という項目に国名を出力してくれます。でも、2文字の国コードじゃないので [http://dev.maxmind.com/geoip/legacy/geolite/](http://dev.maxmind.com/geoip/legacy/geolite/) あたりからリストをダウンロードして置換してあげれば Kibana3 の World Map 機能が使えそうです。 Syslog は [rsyslog](http://www.rsyslog.com/) の Template 機能で出力先を日別に変わるようにしているのですが、この場合、Fluentd 付属の in\_tail ではそのままでは日をまたげません。でも [fluent-plugin-tail-ex](https://github.com/yosisa/fluent-plugin-tail-ex) ってのがあるよって教えてもらいました。

> [@yteraoka](https://twitter.com/yteraoka) 遅レスすみません。。これ使ってます。 [http://t.co/hNJveaOJMZ](http://t.co/hNJveaOJMZ)
> 
> — 名前 (@majesta0110) [October 3, 2013](https://twitter.com/majesta0110/statuses/385619100078055424)

これは便利そうだという事で試してみたものの、pos\_file が効かないのと、停止時になんかエラーが出るのが気になったので見送りました。詳細は調べてない。またオレオレ plugin を書こうかとも思いましたが、 [fluent-plugin-tail-asis](https://github.com/yteraoka/fluent-plugin-tail-asis) ほど簡単にも書けなさそうだったから symlink を張り替えるスクリプトを書くことで対応しました。ところで、今回は parse 処理は out\_fortigate\_syslog\_parser.rb で行うので tail で parse する必要がないため、使うなら [fluent-plugin-tail-ex-asis](https://github.com/sonots/fluent-plugin-tail-ex-asis) の方がより合っていそうです。（tail-asis 相当の機能は none parser として本家に merge されたので asis の役割は終わりました） rsyslog の Template を使った例

```
$template HostSeparatedDailyLogFile,"/some/where/%syslogfacility-text%/%$YEAR%%$MONTH%%$DAY%/%HOSTNAME%"
*.* ?HostSeparatedDailyLogFile
```

「[Kibana3 を使ってみよう](/2013/10/lets-try-kibana3/)」 の中で触れた ElasticSearch の Template 機能ですがちょうど良い例を見つけました。 [https://gist.github.com/deverton/2970285](https://gist.github.com/deverton/2970285) これを参考にすると良さげです。ElasticSearch には ip っていうタイプもあったので IP アドレスのところはこれを使ってみました。 FortiGate ユーザーのみなさん、FortiAnalyzer 買ってなかったら試してみてください。ではでは。

> ※ 2013-10-15追記 (2) @ipv6labs さんから「区切り文字カンマでロギングすると楽ですよ」と助言をいただき、「え？ CSV 出力って syslog の設定にしかないんじゃないの？そして syslog だと traffic ログって出せないんじゃ？？」って思ってたん出すけどやり取りの中で `config log syslogd filter` で設定できそうなことがわかりました。ありがとうございます。 [log : {disk | fortianalyzer | fortianalyzer2 | fortianalyzer3 | memory | syslogd | syslogd2 | syslogd3 | webtrends | fortiguard} filter](http://docs.fortinet.com/fgt/handbook/cli_html/index.html#page/FortiOS%25205.0%2520CLI/config_log.16.03.html) でもまぁ、カンマ区切りにしても

```
> dns_name="www.googleadservices.com",dns_ip="173.194.38.90,173.194.38.89,173.194.38.77"
> 
>
```

とか、値にもカンマが入るし、 CSV って言っても値が key="value" だし... まぁ、書きなおさなくてもいっかな。 あ、そもそもの問題は key に空白が含まれる可能性があるってやつだからやっぱりカンマ区切りにしておこう。
