---
title: 'RailsアプリをSub-URIで動かす'
date: Mon, 11 Mar 2013 14:10:41 +0000
draft: false
tags: ['Ruby', 'Rails']
---

Rails 3 アプリを各Webサーバー (Thin, Unicorn, Passenger) で Sub-URI で使う方法 （Qiita に書いたけど反応なくてさみしいので転載）

### Thin

```
thin --prefix /subdir start
```

とすると /subdir で動作はするが css や js のリンクが変わらない prefix 指定では `RAILS_RELATIVE_URL_ROOT` はセットされないので、起動時に環境変数としてセットし、config.ru で

```ruby
map ActionController::Base.config.relative\_url\_root || "/" do
  run Test::Application
end
```

（`ENV['RAILS_RELATIVE_URL_ROOT']` の値が `ActionController::Base.config.relative_url_root` にセットされます。） とすることで css や js のリンク先が変わる、ただし、prefix と併用するとアプリは /subdir/subidr/ での動作となり、css や js のリンク先は /subdir/ になってしまう。 期待通りに動作させるためには prefix 指定無しで `RAILS_RELATIVE_URL_ROOT` をセットし、config.ru で `RAILS_RELATIVE_URL_ROOT` を扱う必要がある。 `thin --prefix /subdir` と

```ruby
config.assets.prefix = '/subdir/assets'
```

の組み合わせでも動作した。`RAILS_RELATIVE_URL_ROOT` は使わない。

### Unicorn

unicorn の場合は `--path /subdir` を指定して起動させると `RAILS_RELATIVE_URL_ROOT` がセットされるので config.ru で `RAILS_RELATIVE_URL_ROOT` を使ってやると動作する

### Passenger (Rack)

DocumentRoot にアプリの public ディレクトリを subdir という名前でシンボリックリンクをはり、

```ruby
RackBaseURI /subdir
```

とすることで

```
RAILS_RELATIVE_URL_ROOT=/subdir
RACK_BASE_URI=/subdir
```

がアプリに渡される。`config.ru` で `RAILS_RELATIVE_URL_ROOT` を扱うと Thin で両方指定した場合と同じように /subdir/subdir/ となってしまうため、config.ru で `RAILS_RELATIVE_URL_ROOT` を全く扱わないか `RACK_BASE_URI` に何かセットされていたら `RAILS_RELATIVE_URL_ROOT` を無視するという設定にする必要がある。

```ruby
if ! ENV['RACK_BASE_URI'] && ENV['RAILS_RELATIVE_URL_ROOT']
  map ENV['RAILS_RELATIVE_URL_ROOT'] || "/" do
    run Test::Application
  end
else
  run Test::Application
end
```

みたいな。

### Passenger (非Rack)

RackBaseURI の代わりに RailsBaseURI を使う

```
RailsBaseURI /subdir
```

こうすると `config.ru` は使われなくなり、`RAILS_RELATIVE_URL_ROOT` だけがセットされる。そして、これで期待の動作をする。

### まとめ

実は Ruby ドシロウトです。 Rails (Rack) ってこういうものなんでしょうか？ わざわざ `--prefix` とか `--path` なんてオプションがあるのにそれだけではうまくいかない。アプリの書き方で対応可能？ どの Web サーバーでも書き換えたりしないで動かせればいいのにと思いました。 ツッコミお待ちしております。
