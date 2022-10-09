---
title: 'オレオレFortiAnalyzerその3'
date: Tue, 11 Feb 2014 14:58:27 +0000
draft: false
tags: ['FortiGate', 'elasticsearch', 'fluentd', 'kibana3']
---

* [Fluentd + Kibana3 で FortiAnalyzer いらず (更新あり)](/2013/10/fluentd-kibana3-fortianalyzer/)
* [続オレオレFortiAnalyzer](/2013/10/fluentd-kibana3-fortianalyzer-2/)

のさらに続きです。 FortiOS を 4 から 5 にあげたらログのフォーマットというかカラム名(?)が変わったので fluentd plugin もそれに合わせて変更しました。 ついでに GitHub に上げました。 [https://github.com/yteraoka/fluent-plugin-fortigate-log-parser](https://github.com/yteraoka/fluent-plugin-fortigate-log-parser) gem にする予定はないので td-agent だったら /etc/td-agent/plugin/ にコピーして使ってください。 FortiOS 4 で使う場合は

```
fortios_version 4
```

を指定してください。GeoIP (World Map) を使わないなら関係ないですけど。 country\_map\_file オプションを使う場合は [http://dev.maxmind.com/geoip/legacy/geolite/](http://dev.maxmind.com/geoip/legacy/geolite/) から GeoIPCountryCSV.zip をダウンロードして

```
$ ruby mkCountryMap.rb GeoIPCountryWhois.csv > country.map
```

で Japan => JP, United States => US などの変換（フィールドの追加）ができるので Kibana で World Map を使って地図表示できます。 FortiOS 5 からは Web インターフェースからは syslog 設定ができなくなったみたいですね。 そして、CSV 出力時の time のフォーマットがバグってる問題も修正されてませんでした。将来的に syslog 出力なくなったら悲しいな。 Kibana 便利ですよ、誰か FortiAnalyzer と比べてみてください。 # FortiAnalyzer 使ったことないから比べられない...
