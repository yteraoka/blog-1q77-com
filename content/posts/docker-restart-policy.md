---
title: "Docker Restart Policy"
date: 2023-01-18T16:00:31+09:00
tags: ["Docker"]
draft: true
---

docker を学び直し中です。

https://docs.docker.com/config/containers/start-containers-automatically/ に書かれている内容です。

# Restart policy

docker コンテナなんらかの理由で予期せぬ停止をした場合に自動で restart させたいことがあります。
このために `--restart` オプションがあります。

| Flag | Description |
|------|-------------|
| `no` | 自動で再起動しない (default) |
| `on-failure[:max-retries]` | エラーで終了 (exit code が 0 以外) した場合に自動で再起動する。追加で再起動を試みる回数の上限を指定することも可能 |
| `always` | エラーに限らず終了した場合は自動で再起動する。ただし、手動で停止させた場合は Docker daemon の再起動時のみ自動で起動される |
| `unless-stopped` | `always` と似ているが Docker daemon の再起動時には自動でき起動されない |

## Restart policy details

restart policy を使うにあたっての留意点

- Restart policy はコンテナが正常に起動した後でのみ有効になる。正常に起動とは10秒以上稼働して Docker が監視を開始したことを意味する。これによって、正常に起動しないコンテナがずっと restart され続けることを防ぐ。
- コンテナを手動で停止した場合、Dockerデーモンが再起動するか、コンテナが手動で再起動されるまで、その再起動ポリシーは無視される。そうでないと停止ができない。
- Restart policy は、コンテナにのみ適用されます。Swarm service の再起動ポリシーは別の設定となる。[サービスの再起動に関連するフラグ](https://docs.docker.com/engine/reference/commandline/service_create/)を参照。


## Process manager の使用

Docker 以外のプロセスが Docker コンテナに依存している場合など、Restart policy がニーズに合わない場合には upstart, systemd, supervisor などの process manager を使うこともできる。

Process manager を使う場合は Docker の restart policy での restart を有効にしないこと。

また、コンテナ内で process manager を使用して process の再起動を行うことも可能。しかし、Docker はこれをお勧めしない。




