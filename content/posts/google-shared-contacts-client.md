---
title: 'Google Apps の共有アドレス帳の操作'
date: Sat, 06 Sep 2014 05:09:54 +0000
draft: false
tags: ['Linux', 'Python', 'googleapps']
---

Google Apps でみんなが使えるアドレス帳を操作しようと思ったら存在するのにウェブの管理画面から操作できないんですよね。 これまた API 使って操作するスクリプトを書こうかと思ったけどこれはめんどくさそうだったから既存のものを探したら [google-shared-contacts-client](https://code.google.com/p/google-shared-contacts-client/) というものが見つかったのでこれを使うことにする。 使い方は簡単 まずは依存ライブラリのインストール

```
$ pip install gdata
```

それから google-shared-contacts-client-1.1.3.tar.gz を展開して shared\_contacts\_profiles.py を実行するだけ

```
$ tar xvf google-shared-contacts-client-1.1.3.tar.gz
$ cd google-shared-contacts-client
$ python shared_contacts_profiles.py
Usage: shared_contacts_profiles.py --admin=EMAIL [--clear] [--import=FILE [--output=FILE]]
  [--export=FILE]
If you specify several commands at the same time, they are executed in in the
following order: --clear, --import, --export regardless of the order of the
parameters in the command line.

Options:
  -h, --help            show this help message and exit
  -a EMAIL, --admin=EMAIL
                        email address of an admin of the domain
  -p PASSWORD, --password=PASSWORD
                        password of the --admin account
  -i FILE, --import=FILE
                        imports an MS Outlook CSV file, before export if
                        --export is specified, after clearing if --clear is
                        specified
  -o FILE, --output=FILE
                        output file for --import; will contain the added and
                        updated contacts/profiles in the same format as
                        --export
  --dry_run             does not authenticate and import contacts/profiles for
                        real
  -e FILE, --export=FILE
                        exports all shared contacts/profiles of the domain as
                        CSV, after clearing or import took place if --clear or
                        --import is specified
  --clear               deletes all contacts; executed before --import and
                        --export if any of these flags is specified too

Nothing to do: specify --import, --export, or --clear
```

とりあえず既存のデータを export して中身をのぞいてみる。 UTF-8 な CSV ファイルなので Excel で開く場合はテキストで読み込ませる。(バージョンによってはそのまま開けるのかな？) 開いてびっくり!! なんと Email address の項目が69個もある!! 更新(import)する時は必要な(使う)列だけあれば良いです。文字コードは UTF-8 じゃないと化けます。エクセルで編集、保存する場合は注意。 ただし、`Action` は必須です。`add`, `update`, `delete` が入ります。`add` 以外の場合は `ID` も必須です。どれを更新、削除するのか指定しないといけませんから。 項目のリストは [https://code.google.com/p/google-shared-contacts-client/wiki/SupportedContactFields](https://code.google.com/p/google-shared-contacts-client/wiki/SupportedContactFields) にあります。使いそうにないものばっかりです。 そして、このコマンドで import したデータはすぐに export 出来ますが、実際にブラウザで Google Apps にアクセスしてみてもすぐには反映されません。かなーり長いことかかるようです。それを知らずに何度も試すと時間を無駄にします...しました。
