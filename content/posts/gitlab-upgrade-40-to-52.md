---
title: 'GitLabを4.0から5.2にアップグレードしたメモ'
date: Wed, 29 May 2013 13:57:58 +0000
draft: false
tags: ['Linux', 'git', 'gitlab']
---

（2013/06/07追記あり） GitLabがgitoliteからgitlab-shellに切り替えてからそこそこ時間も経ったし、5.2でforkがサポートされということなのでアップグレードしてみました。 [Gitリポジトリ管理ツール「GitLab 5.2」リリース、フォーク機能などを追加](http://sourceforge.jp/magazine/13/05/23/180000) いくつかハマりどころがあったのでメモっておきます。 全体的な流れは [https://github.com/gitlabhq/gitlabhq/tree/master/doc/update](https://github.com/gitlabhq/gitlabhq/tree/master/doc/update) にあるように順番にひとつずつアップグレードしていきます。

### ひとつめのハマりどころ、「Wiki の切り替え」

4.2 から 5.0 への変更点に Wiki の管理が RDB (MySQL) から Git に変更となるということで

```
bundle exec rake gitlab:wiki:migrate RAILS_ENV=production
```

という処理があるのですが

```
rake aborted!
incompatible character encodings: UTF-8 and ASCII-8BIT
```

となって止まってしまいます。ググってみると同じ問題にぶつかった人が沢山いました。そして

```
bundle exec rake gitlab:wiki:migrate safe_migrate=true
RAILS_ENV=production
```

と、`safe_migrate=true` をつけることで回避できることが判りました。

*   [Task gitlab:wiki:migrate fails](https://github.com/gitlabhq/gitlabhq/issues/3312)
*   [Add a safe migration mode to the wiki migrator.](https://github.com/gitlabhq/gitlabhq/pull/3719)

**がぁぁぁ、Wikiの問題はこれだけではありませんでした。** RDB の時にはページ間のリンクは title とは別に slug という column の値を使っていましたが Git 管理へ移す処理で title を使う様に変わっていました。かつ、アルファベットと数字(だけ?)がページのファイル名となるようになることで、「あいうえお」というマルチバイトだけの title の場合はページのファイル名が空っぽとなりエラー。「あああABCいいい」は「Abc」がファイル名となりリンク切れとなっていました。(slug じゃなくなってる時点でリンク切れですけど) そして、Web UI ではページのファイル名を変更できないので git で clone & push する必要がありました。

### ふたつめの問題「Gitのバージョン」

5.0 まで来たので次は 5.1 に挑戦。そして、アクセスしてみると「**ゲゲゲゲッ**」リポジトリ内のファイルを見ようとすると**エラー**

```
Completed 500 Internal Server Error in 170ms

ActionView::Template::Error (undefined method `committed_date' for nil:NilClass):
    4: 
    5:   :plain
    6:     var row = $("table.table_#{@hex_path} tr.file_#{hexdigest(file_name)}");
    7:     row.find("td.tree_time_ago").html('#{escape_javascript time_ago_in_words(commit.committed_date)} ago');
    8:     row.find("td.tree_commit").html('#{escape_javascript render("tree/tree_commit_column", commit: commit)}');
  app/views/refs/logs_tree.js.haml:7:in `block in _app_views_refs_logs_tree_js_haml___423991908861600613_57326520'
  app/views/refs/logs_tree.js.haml:1:in `each'
  app/views/refs/logs_tree.js.haml:1:in `_app_views_refs_logs_tree_js_haml___423991908861600613_57326520'
```

そして、こんなわかりやすいエラーは「きっと 5.2 にすれば直ってるはずだ」と思い 5.2 にしてみたが同じエラーが出る... またまたググってみたらやっぱり同じ問題に遭遇しいている人が沢山いました。

*   [Can not browse project files](https://github.com/gitlabhq/gitlabhq/issues/3666)

git のバージョンは 1.7.10 以降が必要らしいです。しかし、CentOS 6 の yum で入るのは

```
git-1.7.1-3.el6_4.1.x86_64
```

でダメなので source をダウンロードしていれて解決。ちょうど 1.8.3 が出たところだったのでこれを入れました。 [分散バージョン管理システム「Git 1.8.3」がリリース](http://sourceforge.jp/magazine/13/05/28/193000) はー、長かった。

### ※ 2013/06/07 追記

[GitLab のバックアップ](/2013/06/backup-gitlab-data/) を書いていて気づいたのだが upgrade を毎回別ディレクトリに clone や zip の展開で行なっていたら `public/uploads` のファイルが置き去りになっていました。 `git fetch` & `git checkout` でない方法で更新してる場合はお気をつけください。
