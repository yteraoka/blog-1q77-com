---
title: "RPM の install, uninstall 時に実行される script の確認"
date: 2022-11-11T08:38:02+09:00
draft: false
tags: ["Linux"]
---

ある RPM Package のインストール、アンインストール時にどんな処理が行われているのか確認したいことがある

そんな時な `rpm` コマンドの `--scripts` オプションを使用する

```
rpm -qp --scripts ./some.rpm
```
