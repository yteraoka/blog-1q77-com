---
title: "go.mod の更新"
date: 2022-12-27T12:52:31+09:00
tags: ["go"]
draft: false
---

たまに使い捨ての code を書いて放置する程度だと毎回ググってしまうのでメモ。

go.mod の更新は [go get](https://go.dev/ref/mod#go-get) や [go mod tidy](https://go.dev/ref/mod#go-mod-tidy) で行うことができる。

## go の version を更新

go.mod 内の go の version は次のようにして `go mod tidy` の `-go` オプションで指定する。 ([go 1.17 から](https://go.dev/doc/go1.17))

```
go mod tidy -go=1.19
```

## 個別 module の更新

[go get](https://golang.org/ref/mod#go-get) で更新する (help は `go help get`)

```
To add a dependency for a package or upgrade it to its latest version:

        go get example.com/pkg

To upgrade or downgrade a package to a specific version:

        go get example.com/pkg@v1.2.3

To remove a dependency on a module and downgrade modules that require it:

        go get example.com/mod@none

See https://golang.org/ref/mod#go-get for details.
```

単に `go get -u` とすれば全部(?)更新してくれる。`-t` も指定すると test でしか使わない module も対象になる。

> The `-t` flag instructs get to consider modules needed to build tests of packages specified on the command line.

> The `-u` flag instructs get to update modules providing dependencies of packages named on the command line to use newer minor or patch releases when available.

`go get -u` では新しいものの追加は行われるが、不要になった古いものが go.sum に残ったままになっているので `go mod tidy` も実行する。

```
go get -u
go mod tidy
```
