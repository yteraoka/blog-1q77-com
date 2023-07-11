---
title: 'GitLab のバックアップ'
date: Wed, 05 Jun 2013 14:41:05 +0000
draft: false
tags: ['Linux', 'backup', 'git', 'GitLab']
---

（2013/06/07追記あり） GitLab 環境のバックアップをどうしようかなぁ、KDE の repository が壊れた時の記事で `git clone --mirror` なんてのを見かけたなぁと思ってたら GitLab には `gitlab:backup:create` という rake task があるのを見つけたのでとりあえずこれを設定することにしました。 GitLab のバージョンは 5.2 です。 バックアップファイルの出力先は `config/gitlab.yml` の `gitlab.backup.path` で指定します。デフォルトは相対パスで `tmp/backups` になってます。`/` で始めれば絶対パスになります。 実行時にこのディレクトリに `repositories, db, uploads` ディレクトリが作成されそれぞれが書きだされます。`backup_information.yml` というファイルにバージョンやバックアップ日時などが書かれます。そして `{unix_timestamp}__gitlab_backup.tar` という tar ファイルにまとめられます。3つのディレクトリと `backup_information.yml` は削除されます。 世代管理は `config/gitlab.yml` の `gitlab.backup.keep_time` に残しておきたい期間を秒で設定します。デフォルトは 0 で無期限です。 Git repository のバックアップは

```
git bundle create #{path_to_bundle(project)} --all
```

で行われています。`git bundle` はバックアップに適しているみたいです。速いです。 git bundle についてはこちらのスライドが大変参考になります。 [「Gitによるバージョン管理」の執筆者によるGit勉強会か講演会 / git bundle](https://speakerdeck.com/iwamatsu/git-bundle) [https://speakerdeck.com/iwamatsu/git-bundle](https://speakerdeck.com/iwamatsu/git-bundle) でも、やっぱりリアルタイムでバックアップした方が良いよなぁ [gitのbareリポジトリのバックアップをとる - 馬鹿と天才は紙一重](http://d.hatena.ne.jp/shim0mura/20120914/1347591103) あたりを参考にそのうち考えよう。

### ※ 2013/06/07 追記

`public/uploads` ディレクトリは何もファイルをアップロードしてない状態では作成されていないので、task がエラーで終了します。
