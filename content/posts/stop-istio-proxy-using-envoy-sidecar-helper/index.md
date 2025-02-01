---
title: 'envoy-sidecar-helper で Job の終了後に istio-proxy を停止させる'
description: |
  Istio の sidecar が入った Job Pod では envoy がメインのコンテナよりも先に起動し、後から終了しなければ通信エラーが発生する、また、停止をトリガーしてやらないとずっと Job が終了しないという事象が発生する。このための停止時の処理を任せられるのが envoy-sidecar-helper
date: 2022-08-12T20:51:14+09:00
draft: false
tags: ['Istio', 'Kubernetes']
image: cover.png
author: "@yteraoka"
categories:
  - IT
---

## 課題

Istio を導入した環境で Job (CronJob) を実行すると、sidecar としての istio-proxy コンテナを Job 本来の処理が終わった後に istio-proxy コンテナを終了させないといつまで経っても Pod が終了しないという課題があります。 Istio に限らず、Job から生成される Pod の場合、一つでもコンテナが終了せずに残っていれば発生する問題で、例えば Cloud SQL Proxy を sidecar で実行する場合にも同じ問題が発生します。

Istio 環境で動かすことを前提にしたコンテナイメージを作ったり、Helm Chart などのマニフェストを用意する場合コンテナイメージに仕込んだり、Helm の template で Init Container を追加して wrapper script を仕込んだりすることは可能ですが、Deployment ではそんなことを気にする必要がないのに Job だけ特別な対応が必要になるのはなんだか許せないと思うこともあるでしょう。

そんな場合に使えるのが [envoy-sidecar-helper](https://github.com/maksim-paskal/envoy-sidecar-helper) です。

## envoy-sidecar-helper

envoy-sidecar-helper を sidecar として追加してやると、Kubernetes の API サーバーに定期的に Pod の情報を問い合わせ、メインの処理をしているコンテナが終了しているかどうかを監視し、終了していれば envoy を停止させてくれます。 でも、これだって Manifest に追加しないとダメじゃん、というわけではあるのですが、istio-proxy がそうであるように、このコンテナを MutatingWebhook で挿入してやれば良いわけですね。ということで Webhook サーバーを書きました、公開してないですけど...

それでも、全く違いがないかと言われるとそうではなくて Job の ServiceAccount に Pod の参照権限、削除権限が必要になります。

[envoy-sidecar-helper](https://github.com/maksim-paskal/envoy-sidecar-helper) は Istio 専用に書かれたものではなく、envoy 起動するまで他のコンテナが処理を開始するのを待つための仕組みとかを持っていますが、そのために Volume マウントでファイルを共有する必要があり、起動順については Istio が面倒を見てくれるのでその機能は無効にできるようにしてもらいました。
