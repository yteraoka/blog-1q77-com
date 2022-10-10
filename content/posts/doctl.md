---
title: 'doctl'
date: Sun, 21 Aug 2016 07:31:40 +0000
draft: false
tags: ['DigitalOcean', 'doctl']
---

DigitalOcean のコマンドラインツール [doctl](https://github.com/digitalocean/doctl) の使い方 1ヶ月ほど前からなんでだか使えないなぁと思ってたら削除した token が環境変数に残ってたからだった... どうして気づかなかったんだろうか

### インストール

go で書かれているので GitHub の release ページからバイナリをダウンロードして PATH の通ったところに置く 2016/8/20 現在での最新版は 1.4.0

### 初期設定

事前に DigitalOcean のサイトで token を取得して、doctl auth init で token を入力します（自動でブラウザ起動するやつは無くなったのかな？）

```
$ doctl auth init
DigitalOcean access token: ****************************************************************

Validating token: OK
```

1.4.0 から設定ファイルが `$HOME/.doctlcfg` から `$HOME/.config/doctl/config.yaml` に変わり、内容も大幅に増えています compute.ssh.ssh-key-path で doctl compute ssh の際のデフォルトの private key を指定できます compute.ssh.ssh-user ではその際の ssh ユーザーを指定できます。標準のイメージから起動する場合、CentOS や Ubuntu は root でログインすることになりますが、CoreOS の場合は core です。実行時のオプションで指定すれば設定ファイルの値よりも優先されます doctl compute ssh --ssh-user core <droplet> droplet.create.image, droplet.create.size, droplet.create.enable-private-networking, droplet.create.ssh-keys など droplet.create.\* では doctl compute droplet create の際のデフォルト値を設定できます droplet 作成時のオプションをいくつも設定するのは面倒なのでこれは便利 テストで使う場合はいつも日本から近そうなシンガポールの DC を使うので droplet.create.region: "sgp1" とします doctl コマンドはいちいち長すぎて tab 補完が効いても面倒なので適当な alias を設定しました

```bash
alias docreate="doctl compute droplet create"
alias dols="doctl compute droplet ls"
alias dossh="doctl compute ssh"
alias dorm="doctl compute droplet delete"
alias doimgs="doctl compute image list-distribution"
```
