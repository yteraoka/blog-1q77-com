---
title: 'モニカジ#3に参加してきた'
date: Mon, 11 Mar 2013 07:47:16 +0000
draft: false
tags: ['Apache', 'monitoring', '勉強会']
---

3月8日(金) [Monitoring Casual Talk #3](http://www.zusaar.com/event/521056) に参加してきました。 参加者全員が発表者というイベントです。ビールを飲みながらのゆるいイベントです。 今回は paperboy&co. さんの主催でした。会場の準備、二次会の準備などありがとうございました。 GMOグループの Friday Night Party がうらやましかった。きれいなお姉さんがお酒を配ってくれるなんて。 私の発表は以前このBlogにも書いた [Apache で Response Header を消しつつその値をログに書き出す](/2013/02/mod_headers-toenv/) について。

**[アプリからの情報を秘密裏にApacheのログに書き出す方法](http://www.slideshare.net/yteraoka1/monitoring-casual-3 "アプリからの情報を秘密裏にApacheのログに書き出す方法")** from **[Yoshinori Teraoka](http://www.slideshare.net/yteraoka1)**

でも、@kazeburo さんから次のようなツッコミがっ！！

{{< x user="kazeburo" id="310012048379621376" >}}

> それ mod\_copy\_headers [#monitoringcasual](https://x.com/search/%23monitoringcasual)
> 
> — masahiro naganoさん (@kazeburo) [2013年3月8日](https://x.com/kazeburo/status/310012048379621376)

{{< x user="kazeburo" id="310012240814284800" >}}

> s/headers/header/
> 
> — masahiro naganoさん (@kazeburo) [2013年3月8日](https://x.com/kazeburo/status/310012240814284800)

ん? mod\_copy\_header? ぐぐったら出てきました。 [mod\_copy\_header ってのを書いた話 Re: Apache上のPerl FastCGIはCustomLogにデータを書くことができるか？](http://blog.nomadscafe.jp/2012/08/mod-copy-header-re-apacheperl-fastcgicustomlog.html) おぉ、こんなものが。これで良いですね。私もひとつのモジュールとして独立化させようかと思いましたが面倒なので諦めてました。 今回のモニカジの中心的な話題はサーバー台数が増えると監視の設定が大変なのでそれをどうやってツールで自動化するかというものでした。 モニカジ参加者のほとんどやTwitterでフォローしてる人とかが年下とわかり少しショックを受けたりもしましたが、また次回もよろしくお願いします。京都へ行きたいところですがちょっと無理ですね。
