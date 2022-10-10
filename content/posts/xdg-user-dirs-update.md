---
title: 'デスクトップディレクトリを英語に変更'
date: Tue, 25 Jun 2013 16:03:23 +0000
draft: false
tags: ['Linux']
---

OS (Linux Mint) を入れ直してまたググったのでメモ。ホームディレクトリにある日本語ディレクトリを英語に変更するには

```
$ LANG=C xdg-user-dirs-update --force
```

とすることで、英語のディレクトリが作成される。日本語ディレクトリはそのまま残るので不要なら削除する。 設定は `.config/user-dirs.dirse` と `.config/user-dirs.locale` に保存される。 [xdg-user-dirs-update (1)](http://www.unix.com/man-page/all/1/xdg-user-dirs-update/) GUI 版の `xdg-user-dirs-gtk-update` というコマンドもある。

| 日本語       | English   |
|--------------|-----------|
| デスクトップ | Desktop   |
| ダウンロード | Download  |
| テンプレート | Templates |
| 公開         | Public    |
| ドキュメント | Documents |
| 音楽         | Music     |
| 画像         | Pictures  |
| ビデオ       | Videos    |
