---
title: 'Istio 導入への道 – 図解'
date: 2020-03-19T16:13:28+00:00
draft: false
tags: ['Istio', 'Kubernetes']
author: "@yteraoka"
image: cover.png
categories:
  - IT
---

[Istio シリーズ](/tags/istio/) 第10回です。

## 図解

そろそろ図解してみようと思ったのだが...  
正確に描くのは非常に難しい、そのうち Argo CD + Argo rollouts についても書くので Argo CD が描画する図を見る方が良いかもしれない。

一応貼っておく。Service 間通信では Gateway は関係なかったり、ServiceEntry が入ってなかったり、Pod と Envoy の関係も見えないけど...

{{< figure src="Istio-chart.png" >}}

* * *

## Istio 導入への道シリーズ

* [Istio 導入への道 (1) – インストール編](/2020/03/istio-part1/)
* [Istio 導入への道 (2) – サービス間通信編](/2020/03/istio-part2/)
* [Istio 導入への道 (3) – VirtualService 編](/2020/03/istio-part3/)
* [Istio 導入への道 (4) – Fault Injection 編](/2020/03/istio-part4/)
* [Istio 導入への道 (5) – OutlierDetection と Retry 編](/2020/03/istio-part5/)
* [Istio 導入への道 (6) – Ingress Gatway 編](/2020/03/istio-part6/)
* [Istio 導入への道 (7) – 外部へのアクセス / ServiceEntry 編](/2020/03/istio-part7/)
* [Istio 導入への道 (8) – 外部へのアクセスでも Fault Injection 編](/2020/03/istio-part8/)
* [Istio 導入への道 (9) – gRPC でも Fault Injection 編](/2020/03/istio-part9/)
* Istio 導入への道 (10) – 図解
* [Istio 導入への道 (11) – Ingress Gateway で TLS Termination 編](/2020/03/istio-part11/)
