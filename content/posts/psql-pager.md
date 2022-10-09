---
title: 'psql での pager 設定'
date: Thu, 08 Mar 2018 15:53:43 +0000
draft: false
tags: ['PostgreSQL']
---

PostgreSQL の psql コマンドではクエリの結果表示に pager（more とか less とか）が使われますが PAGER 環境変数での設定以外に変更する方法があったのでメモ。 わざわざ psql を終了して PAGER をセットし直して再度 psql を実行することとはオサラバです。

```
\setenv PAGER less
```

で pager を less にできます。 pager 使用の有効・無効を切り替えるには `\pset` を使います。PAGER を cat にしたりしなくても良いです。

```
  \pset [NAME [VALUE]]   set table output option
                         (NAME := {border|columns|expanded|fieldsep|fieldsep_zero|
                         footer|format|linestyle|null|numericlocale|pager|
                         pager_min_lines|recordsep|recordsep_zero|tableattr|title|
                         tuples_only|unicode_border_linestyle|
                         unicode_column_linestyle|unicode_header_linestyle})
```

`\pset pager` で pager の toggle となります。実行するたびに有効と無効に順に切り替わります。 `\pset pager on`, `\pset pager off` と on / off を明示すれば指定した方になります。
