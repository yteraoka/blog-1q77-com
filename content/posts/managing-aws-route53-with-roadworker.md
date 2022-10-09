---
title: 'AWS Route53 の管理に Roadworker を試した'
date: Wed, 15 Jan 2014 15:43:04 +0000
draft: false
tags: ['AWS', 'Route53', 'Ruby', 'roadworker']
---

DNS を AWS Route53 で管理するにあたり、ブラウザでポチポチやるのはやっぱり誤操作が怖いし、履歴の管理ができないよなぁということで [Roadworker](https://bitbucket.org/winebarrel/roadworker) を試してみました。

### インストール

インストールは gem install だけ

```
$ gem install roadworker --no-ri --no-rdoc
```

Bundler を使う場合は

```
$ cat <<_EOD_ > Gemfile
source 'https://rubygems.org'
gem 'roadworker'
_EOD_
$ bundle install --path bundle
$ bundle exec roadwork
```

な感じで。 次に Route53 の Action を許可した IAM ユーザーを用意し、環境変数 (`AWS_SECRET_ACCESS_KEY`, `AWS_ACCESS_KEY_ID`) をセットします。

### Export

既に Route53 を利用中なら次のように `-e` を指定することで設定を export することができます。Roadworker の定義ファイルはデフォルトが `Routefile` なので `-o Routefile` と指定することでこのファイルに書き出せます。 `-o` を指定しなかった場合は標準出力に出力されます。

```
$ roadwork -e -o Routefile
```

複数 zone を管理する場合は zone ごとにファイルを分けると管理しやすいかもしれません。これも既に利用中の場合、`-e` に加え、`--split` を指定すると zone 毎にファイルを分けて export してくれます。

```
$ roadwork -e --split
```

この場合、`-o` を指定せずとも `Routefile` に書き出されます。（`-o` で別ファイルを指定することもできます） 内容は次のようになります。

```
require 'example.com.route'
require 'example.net.route'
```

```
hosted_zone "example.com." do
  rrset "www.example.com.", "A" do
    ttl 300
    resource_records(
      "93.184.216.119"
    )
  end

  rrset "example.com.", "TXT" do
    ttl 300
    resource_records(
      "\"v=spf1 redirect=_spf.google.com\""
    )
  end
end
```

```
hosted_zone "example.net." do
  rrset "www.example.net.", "A" do
    ttl 300
    resource_records(
      "93.184.216.119"
    )
  end

  rrset "example.net.", "SPF" do
    ttl 300
    resource_records(
      "\"v=spf1 redirect=_spf.google.com\""
    )
  end
end
```

### DNS のルックアップ結果と Routefile を比較する

`-t` オプションを指定することで、実際に DNS サーバーに問い合わせた結果と比較します。

```
$ roadwork -t
```

zone 毎にファイルを分けた場合は `-f` でファイルを指定することで当該 zone だけを対象にテストできます。 **気になる点**  
TXT や SPF レコードの先頭、末尾の「"」を取り除いた上に連続するスペースを一つにまとめてから比較しているのがちょっと気になりました。quoted string なんだからそのまま比較するべきじゃないかな。「"」も取り除く必要はなさそう。

### DRY RUN

AWS に設定を反映させるには `-a` (apply) オプションを指定しますが、まずは `--dry-run` をつけて何が変更されるのかを確認しましょう。

```
$ roadwork -a --dry-run
Apply `Routefile` to Route53 (dry-run)
No change
```

ここの No change は差分がないという意味ではなく設定を変更しなかったという意味です。ここでは `--dry-run` なので当然 No change ですね。

### 反映

`-a` で反映させます。 更新内容も表示されてとっても便利です。例は A レコードの TTL だけ変更してみたもの。

```
$ roadwork -a 
Apply `Routefile` to Route53
Update ResourceRecordSet: www.example.com. A
  set ttl=600
```

### zone の追加・削除

roadwork コマンドだけで zone の追加・削除も行えます。Routefile に zone を追加する（別ファイルならファイル作って Routefile で require）だけで apply (`-a`) すれば zone が追加されます。 www.example.com の A レコードを含む example.com zone を追加した例

```
$ roadwork -a --dry-run
Apply `Routefile` to Route53 (dry-run)
Create HostedZone: example.com (dry-run)
Create ResourceRecordSet: www.example.com A (dry-run)
No change

$ roadwork -a
Apply `Routefile` to Route53
Create HostedZone: example.com
Create ResourceRecordSet: www.example.com A
```

とっても簡単に追加できて便利です。削除も同様にファイルから消して apply すれば zone が削除されます。これはちょっと怖いです。そのため `--force` を付けないと zone ごと消す処理は実行されません。他の変更は反映されます。

```
$ roadwork -a --dry-run
Apply `Routefile` to Route53 (dry-run)
Undefined HostedZone (pass `--force` if you want to remove): example.com. (dry-run)
No change

$ roadwork -a 
Apply `Routefile` to Route53
Undefined HostedZone (pass `--force` if you want to remove): example.com.
No change
```

そこで、 route53:DeleteHostedZone Action を IAM に付与しないようにしてみたのですが、zone を削除する処理ではまず zone 内の全てのレコードを消した後に zone を消すようになっているので次のようなエラーになるものの空っぽの zone が残るだけで結局全部消えてしまいます。

```
$ roadwork -a --force
Apply `Routefile` to Route53
Delete HostedZone: example.com.
Delete ResourceRecordSet: www.example.com. A
User: arn:aws:iam::********:user/roadworker is not authorized to perform: route53:DeleteHostedZone on resource: arn:aws:route53:::hostedzone/********
```

でもまあ `--force` をあえて付けない限り消えないから大丈夫かな。 それより、Git や Subversion で管理するものの git pull や svn up を忘れて古いレコードを反映してしまうのが怖いかも。`--dry-run` と同様の処理後に `Y/n` のプロンプトが出て `Y` って入力しないと反映しないようにしたほうが安心かなぁ。 もしくは、リビジョン番号みたいな TXT レコードを作って、それがより大きな値に更新されてないと反映しないとかかな。

### ハマった・・・

自前の BIND 管理から Route53 への移行で、移行中に `-t` のテストを試していてハマってしまいました。（全部私が悪いのですが） テストのために Roadworker で AWS に TXT と SPF を追加してみてテストしたら、ちょうどこの2つだけエラーになるんです。Ruby の net/dns がこの2つに対応してないということがわかり、[dnsruby を使って書きなおしてみました](https://gist.github.com/yteraoka/8bb7855811e16bcf6adf)。だがしかし、その後 Roadworker に含まれる net-dns-ext.rb が net/dns を拡張して対応済みなことに気づく。原因は試していたサーバーが当該ドメインを持っているコンテンツサーバーに問い合わせるようになっていたから Route53 に問い合わせていなかったというオチでした orz... 移行中ということでコンテンツサーバーにも zone が残った状態でした。 （はい、キャッシュサーバーとコンテンツサーバーを分けろよという話ですね）

### SOA と NS レコードは？

Amazon が自動で設定してくれるので管理する必要がないということで、標準では Export されたりしませんし、Routefile にも書きません。でも NS レコードはレジストラでネームサーバー指定するとき必要ですよね。そんな時は `--with-soa-ns` を付けて export すれば出てきます。もちろん AWS Console に行けば確認できます。

```
$ roadwork -e --with-soa-ns
```

zone 毎に違う NS レコードなので要注意。

### まとめ

Roadworker 大変便利なので Route53 使うなら是非使いましょう。菅原さんありがとう。

### 菅原さんのスライド

**[AWSをコードで定義する](//www.slideshare.net/winebarrel/aws-28524918 "AWSをコードで定義する")** from **[Sugawara Genki](//www.slideshare.net/winebarrel)**
