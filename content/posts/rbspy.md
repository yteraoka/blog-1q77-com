---
title: "rbspy で ruby の stacktrace を flamegraph にする"
date: 2022-12-28T20:26:10+09:00
tags: ["Ruby"]
draft: false
---

中身をよく知らない Rails アプリでどこが遅いのかな？と思って [rbspy](https://rbspy.github.io/) ([github](https://github.com/rbspy/rbspy)) を試してみたのでメモ。

とりあえず使って flamegraph を書き出してみたんだけどそもそも flamegraph がどういうものなのか分かってなくて困ったのでドキュメントを読んでみた。


## インストール

mac では Homebrew でインストールできる。

```
brew install rbspy
```

コンテナ (debian:latest) 内で `cargo install rbspy` したらエラーになった。

```
root@8079def2e27e:/# cargo install rbspy
    Updating crates.io index
  Downloaded rbspy v0.15.0
error: failed to parse manifest at `/root/.cargo/registry/src/github.com-1ecc6299db9ec823/rbspy-0.15.0/Cargo.toml`

Caused by:
  failed to parse the `edition` key

Caused by:
  this version of Cargo is older than the `2021` edition, and only supports `2015` and `2018` editions.
```

なので build してみた。

```bash
git clone https://github.com/rbspy/rbspy.git /var/tmp/rbspy
cd /var/tmp/rbspy
git checkout v0.15.0
cargo build
cp target/debug/rbspy /usr/local/bin/rbspy
```

## 起動中のプロセスにアタッチする

```
rbspy record --pid $PID
```

Ctrl-C で停止すると `$HOME/.cache/rbspy/` にデータ `{YYYY-MM-DD}-{random}.raw.gz` と
`{YYYY-MM-DD}-{random}.flamegraph.svg` が保存される。

`*.raw.gz` の方は後から `rbspy report` コマンドに渡すことで SVG を出力できる。
gzip されたテキストで1行目以外は JSON で stacktrace が入っている。


## rbspy とは

rbspy は対象のプロセスの stacktrace を定期的に取得して、
それぞれのタイミングで何が実行されていたのかを記録し、
それを flamegraph やテキストで出力してくれる。

実行中のテキスト出力は次のようなもの。

```
% self  % total  name
  3.05    10.09  each_child_node
  2.52    31.14  block (2 levels) in on_send
  2.17    14.31  do_parse
  1.76     3.28  cop_config
  1.70     2.29  block (2 levels) in <class:Node>
  1.41     1.41  end_pos
```

数値は計測期間全体の中で占める割合(登場回数)。
total はその関数が別の関数を呼び出しているもの(stacktrace の末端じゃない)を含む値。


## flamegraph とは

rbspy ドキュメントの「[Using flamegraphs](https://rbspy.github.io/profiling-guide/using-flamegraphs.html)」
で解説されている。

知っておくべき重要なこととして次の3つが書かれている。

- **X軸は時間ではない**
- SVG には Javascript が含まれていてインタラクティブに動作数るし Ctrl-F で検索できる
- **関数が何回呼び出されたかはわからない、その関数に費やされた時間がわかるだけである**
  - [ruby-prof](https://github.com/ruby-prof/ruby-prof) という trace profiler があり、これであれば回数を正確に知ることができる (rbspy は sampling profiler である)

ここでは言及されていなかったがサンプリング (デフォルトでは100Hz) のタイミングで実行中でない関数は見つからない。
実行時間が短いものは無視される方が嬉しいかもしれない。(`--flame-min-width` で flamegraph に含める最小のパーセンテージの指定も可能)

再起呼び出しの多いコードには flamegraph は向かないとも書かれている。

## おまけ

Python 版の [py-spy](https://github.com/benfred/py-spy) というものもある
