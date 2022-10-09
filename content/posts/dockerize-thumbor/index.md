---
title: 'thumbor の docker 化'
date: Sun, 31 Jan 2016 16:19:24 +0000
draft: false
tags: ['Docker', 'Docker', 'linux', 'thumbor', 'thumbor']
---

Docker については Web や書籍で情報は追いつつも手を動かせていなかったがそろそろやらねばということで、まずは[以前紹介した](/2015/05/using-thumbor-part1/)画像のサムネイル化やクロップ、フィルタ処理を行う [thumbor](https://github.com/thumbor/thumbor) を docker 化してみた。

Dockerfile などは [github](https://github.com/yteraoka/thumbor-docker) に置いてある。

普段は CentOS を使うことが多いが公式 Docker image などでは ubuntu や debian が使われていることが多いようなので ubuntu での image も作ってみた。プライベートの Note PC はずっと Linux mint か Ubuntu だったけど未だに package 名とか apt に慣れない...
thumbor の [.travis.yml](https://github.com/thumbor/thumbor/blob/master/.travis.yml) を参考にして動くようになった。

Thumbor は画像処理エンジンを PIL (Python Image Library), GraphicsMagick (pgmagick), OpenCV の3つから選択できるようになっています。今回の docker image には全部含まれるようにしたので docker run の時の環境変数 (-e) で切り替えられます。（相変わらず pgmagick の build は重い...）

[Makefile](https://github.com/yteraoka/thumbor-docker/blob/master/centos/Makefile) に書いておいたので `make run-pil`, `make run-pgmagick`, `make run-opencv` でそれぞれのエンジンで起動できます。3つ別ポートで起動させれば簡単にそれぞれの比較ができます。

環境変数は ENGINE の切り替えにとどまらず、設定の動的書き換え全般が行えます。

Dockerfile の `CMD` で [thumbor.sh](https://github.com/yteraoka/thumbor-docker/blob/master/centos/thumbor.sh) を指定してあり、`THUMBOR_` で始まる環境変数は `THUMBOR_` を取り除いて設定ファイルに書き出して thumbor を起動するようになっています。設定可能な値は `docker run -i --rm=true thumbor-centos /opt/thumbor/bin/thumbor-config` で確認できます。（ENTRYPOINT を指定すると run 時に変更できないが CMD なら変更可能という学び） 同様に [thumbor-url](https://github.com/thumbor/thumbor/blob/master/thumbor/url_composer.py) コマンドが実行できるので SECURITY\_KEY でのハッシュ付き URL を作ることもできます。

```python
base64.urlsafe_b64encode(hmac.new(security_key, unicode(url).encode('utf-8'), hashlib.sha1).digest())
```

でもできますが。その他 crop とか filter 月の URL 生成のテストができます。すでに docker で動かしていれば docker run の代わりに docker exec でそのインスタンスを使うこともできます。 ENGINE の比較が簡単にできるので [feature or facial detection](https://github.com/thumbor/thumbor/wiki/Enabling-detectors) の効果を見てみたいと思います。 [こちらの画像](https://pixabay.com/ja/%E5%A5%B3%E3%81%AE%E5%AD%90-%E8%B5%A4%E3%81%84%E3%82%B9%E3%82%AB%E3%83%BC%E3%83%95%E3%82%92%E6%8C%81%E3%81%A4%E5%B0%91%E5%A5%B3-%E8%91%A6%E3%81%AE%E5%A5%B3%E3%81%AE%E5%AD%90-%E7%BE%8E%E5%AE%B9-%E3%83%AA%E3%83%BC%E3%83%89-%E7%A7%8B-1107329/)を

```python
DETECTORS = [
  'thumbor.detectors.face_detector',
  'thumbor.detectors.feature_detector'
]
```

とした OpenCV エンジンとそうでないものを比較すると次のようになりました。detection が有効であればサイズ調整時に人物が真ん中に来るようになります。その代わり処理が重い。それを回避するためにまずは detection なしの画像を返しておいて redis などに queue を登録し後のリクエストのために非同期で画像を準備しておく機能もあります。

{{< figure src="girls-1107329_640.jpg" caption="元画像" >}}


<img src="enable-detection.jpg" title="detection あり" width="300" height="300" style="margin-bottom: 2px">
detection あり

<img src="no-detection.jpg" title="detection なし" width="300" height="300" style="margin-bottom: 2px">
detection なし

Thumbor は元画像は処理後の画像をキャッシュする機能がありますが、手前に nginx を置いてキャッシュさせたほうが効率的ですね。そこで nginx の docker を調査していたら [docker-gen](https://github.com/jwilder/docker-gen) とそれを使った [jwilder/nginx-proxy](https://github.com/jwilder/nginx-proxy) という便利ツールがありました。開発環境で便利に使えそうです。

これは別途記事にしたいと思います。
