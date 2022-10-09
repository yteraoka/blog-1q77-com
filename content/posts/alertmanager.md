---
title: 'alertmanager の調査'
date: 
draft: true
tags: ['Uncategorized']
---

[Prometheus](https://prometheus.io/) の [alertmanager](https://prometheus.io/docs/alerting/alertmanager/) ([GitHub](https://github.com/prometheus/alertmanager)) を汎用 Alert Manager として使えないかなと調査したメモです。

Docker を使います alertmanger のイメージは [quay.io](https://quay.io/repository/prometheus/alertmanager) にあります(2019-02-24 時点の最新版 v0.16.1 の [Dockerfile](https://github.com/prometheus/alertmanager/blob/v0.16.1/Dockerfile))

[設定ファイルのドキュメント](https://prometheus.io/docs/alerting/configuration/) alertmanager の[設定例](https://github.com/prometheus/alertmanager#example) https://github.com/prometheus/alertmanager/blob/v0.16.1/examples/ha/send\_alerts.sh https://qiita.com/noexpect/items/5faab079fbf700ae7eb3 https://harthoover.com/pretty-alertmanager-alerts-in-slack/ https://github.com/cloudflare/promsaint