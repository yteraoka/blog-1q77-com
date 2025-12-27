---
title: 'GitHub Actions での goreleaser と Docker Image の Push'
date: Sat, 11 Apr 2020 15:25:05 +0000
draft: false
tags: ['Docker', 'GitHub', 'Go']
---

go でちょっとした調査用ツールを書いたのでついでに [goreleaser](https://goreleaser.com/) を使ってみたのと、コンテナでも使いたかったので Docker Image を作って Registory への Push も [GitHub Actions](https://help.github.com/en/actions) でやってみたメモです。

goreleaser
----------

goreleaser は **.goreleaser.yml** ファイル (-f, --config= で指定も可能) で設定を行います。`goreleaser init` で土台となるファイルを生成してくれます。1からファイルを作ってしまうならローカルに goreleaser コマンドをインストールする必要はありません。`goreleaser check` でファイルの validation を行ってはくれますが。

init で作られるファイルは次の通り。(goreleaser のバージョンは 0.131.1)

```yaml
# This is an example goreleaser.yaml file with some sane defaults.
# Make sure to check the documentation at http://goreleaser.com
before:
  hooks:
    # You may remove this if you don't use go modules.
    - go mod download
    # you may remove this if you don't need go generate
    - go generate ./...
builds:
- env:
  - CGO_ENABLED=0
archives:
- replacements:
    darwin: Darwin
    linux: Linux
    windows: Windows
    386: i386
    amd64: x86_64
checksum:
  name_template: 'checksums.txt'
snapshot:
  name_template: "{{ .Tag }}-next"
changelog:
  sort: asc
  filters:
    exclude:
    - '^docs:'
    - '^test:'
```

「[Customization · GoReleaser](https://goreleaser.com/customization/)」に各項目の説明があります。**archives.replacements** は必須ではないけれども `uname` コマンドの出力に合わせる感じですかね。GitHub Actions で使う方法も [ドキュメント](https://goreleaser.com/actions/) にあります。Action は [Marcketplace](https://github.com/marketplace/actions/goreleaser-action) にあります。([source](https://github.com/goreleaser/goreleaser-action))

結果、次のような **.goreleaser.yml** になりました。

```yaml
before:
  hooks:
    - go mod download
builds:
  - goos: # default では linux と darwin だけだけど windows 用のバイナリも作るようにしてみる
      - linux
      - darwin
      - windows
    goarch: # default では 386 と amd64 だけど今更 32bit は不要かなと
      - amd64
    ldflags: # code 側で version の更新が不要で便利
      - -s -w
      - -X main.version={{.Version}}
      - -X main.commit={{.ShortCommit}}
      - -X main.date={{.Date}}
    env:
      - CGO_ENABLED=0
archives:
  - format: binary # 複数ファイルの zip とかじゃなくて単一のバイナリファイル配布にする (展開が面倒)
    replacements:
      darwin: Darwin
      linux: Linux
      windows: Windows
      386: i386
      amd64: x86_64
    format_overrides: # Windows だけは zip にする (exe をダウンロードさせるのは都合が悪い)
      - goos: windows
        format: zip
checksum:
  name_template: checksums.txt
snapshot:
  name_template: "{{ .Tag }}-next"
changelog:
  skip: true
```

GitHub Actions の workflow の方は次のようになりました。ほぼ、ドキュメントのままです。違いは go-version くらいかな。これを **.github/workflows** ディレクトリ内の任意の .yaml (.yml) ファイルとして保存します。

```yaml
name: release
on:
  push:
    tags:
      - "*"
jobs:
  goreleaser:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      - name: Unshallow
        run: git fetch --prune --unshallow
      - name: Setup Go
        uses: actions/setup-go@v1
        with:
          go-version: 1.14.2
      - name: Run GoReleaser
        uses: goreleaser/goreleaser-action@v1
        with:
          version: latest
          args: release --rm-dist
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

今回は使いませんでしたが [homebrew-tap](https://goreleaser.com/homebrew/) にも対応してるんですね。

Docker Image の Push
-------------------

以前にも GitHub Actions で Docker Hub へ Push するという設定を行ったことはありましたが、その時は workflow ファイルに docker コマンドを並べていました。今回再度調査していて [docker/build-push-action@v1](https://github.com/docker/build-push-action) ([Markcetplace](https://github.com/marketplace/actions/build-and-push-docker-images)) っていう Action の存在を知ったのでこちらを使いました。

GitHub Actions のドキュメント「[Publishing Docker images - GitHub Help](https://help.github.com/en/actions/language-and-framework-guides/publishing-docker-images)」にはサンプルとして次のような設定が掲載されています。

```yaml
name: Publish Docker image
on:
  release:
    types: [published]
jobs:
  push_to_registry:
    name: Push Docker image to Docker Hub
    runs-on: ubuntu-latest
    steps:
      - name: Check out the repo
        uses: actions/checkout@v2
      - name: Push to Docker Hub
        uses: docker/build-push-action@v1
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}
          repository: my-docker-hub-namespace/my-docker-hub-repository
          tag_with_ref: true
```

`on` の trigger で release が published になったら、となっています。上の設定で goreleaser が publish してくれているという理解でしたが、なぜかこちらの workflow が実行されませんでした。詳しく調べたわけではないですが、どうやら [goreleaser の action](https://github.com/goreleaser/goreleaser-action) ではこれが使えないようです。[create-a-release action](https://github.com/marketplace/actions/create-a-release) ([source](https://github.com/actions/create-release)) だったら使えるのかな。

ということで GitHub への code の push を trigger に実行するようにしました。master branch の場合は image の tag が latest になるようです。

```yaml
on:
  push:
    branches:
      - '*'
    tags:
      - '*'
```

後は repository を自分のものにして、docker のログイン情報を secrets として登録すれば終わりです。Docker Hub の場合は自分のログインパスワードとは別に token を発行してパスワードとして設定します。

以上
