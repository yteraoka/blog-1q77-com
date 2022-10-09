---
title: 'OpenDJ で Multi domain (Multi BaseDN)'
date: Tue, 22 Oct 2013 02:58:13 +0000
draft: true
tags: ['未分類']
---

久々に OpenDJ を触ったのでメモ。 既に OpenDJ を replication で運用している環境に、BaseDN を追加する方法。 BaseDN の追加は Control-Panel.bat (Windows の場合) で GUI を使って簡単にできますが、Replication は BaseDN 単位なので既存の BaseDN とは別に設定しなければなりません。手順は最初の BaseDN と同じですけど、なかなかやらないのでメモ。