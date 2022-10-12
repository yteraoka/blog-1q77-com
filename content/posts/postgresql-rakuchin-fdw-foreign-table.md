---
title: 'PostgreSQL 楽ちん FDW Foreign Table 作成'
date: Sat, 19 Sep 2015 08:51:39 +0000
draft: false
tags: ['PostgreSQL']
---

PostgreSQL には他のDBのテーブルを参照（更新もできる）できるようにする Foreign Data Wrapper (FDW) という機能が搭載されています。 これよりも前に dblink がありましたが、仕組み上パフォーマンス的に厳しく使いにくさがありました。FDW ではかなり良くなっています。PostgreSQL 以外の DB と接続することも可能です。 PostgreSQL9.3 開発と運用を支える新機能 [http://enterprisezine.jp/dbonline/detail/5620](http://enterprisezine.jp/dbonline/detail/5620) PostgreSQL 標準の replication は DB 全体での同期しかなく、レプリカは参照しかできませんから分析用のサーバーとして使おうにも書き込むことができません。将来的には論理 replication ができるようになりそうです。特定のテーブルだけとか。 [http://www.postgresql.org/docs/9.4/static/logicaldecoding.html](http://www.postgresql.org/docs/9.4/static/logicaldecoding.html) WAL を decode して必要なものだけ取り出す感じ。Oracle の LogMiner 的な。 DB まるごと FDW でアクセスしたいと言われた場合、テーブル一個ずつ手作業で作成するのは非常にしんどいので便利なツール転がってないかなと調べてみたらやっぱりありました。感謝感謝。 [http://www.postgresonline.com/journal/archives/322-Generating-Create-Foreign-Table-Statements-for-postgres\_fdw.html](http://www.postgresonline.com/journal/archives/322-Generating-Create-Foreign-Table-Statements-for-postgres_fdw.html) それではこの便利ツールを使った場合の流れをメモ

### 概要

例として apple と orange というデータベースを作成し、それぞれDBと同じ名前のユーザーを作成。 apple には pgbench を使ってテーブルを作成（どんなテーブルを作るか考えるの面倒なので）。 orange には apple のテーブルを参照する FOREIGN TABLE を作成する 環境は CentOS 7 と PostgreSQL 9.4

### PostgreSQL と pgbench (contrib) をインストール＆起動

```
$ sudo yum install -y http://yum.postgresql.org/9.4/redhat/rhel-7-x86_64/pgdg-centos94-9.4-1.noarch.rpm
$ sudo yum install -y postgresql94-server postgresql94-contrib
$ sudo -u postgres /usr/pgsql-9.4/bin/initdb -E utf8 --no-locale -D /var/lib/pgsql/9.4/data
$ sudo systemctl enable postgresql-9.4
$ sudo systemctl start postgresql-9.4
```

### ユーザーとデータベースの作成

```
$ sudo -u postgres /usr/pgsql-9.4/bin/psql -c "create user apple password 'ringo'"
$ sudo -u postgres /usr/pgsql-9.4/bin/psql -c "create user orange password 'mikan'"
```

```
$ sudo -u postgres /usr/pgsql-9.4/bin/createdb -E utf8 -O apple apple
$ sudo -u postgres /usr/pgsql-9.4/bin/createdb -E utf8 -O orange orange
```

/var/lib/pgsql/9.4/data/pg\_hba.conf の書き換えと反映。 初期設定ではローカルからのアクセスにパフワードが不要となっているので postgres ユーザ以外は必要にしておく。

```
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             postgres                                trust
local   all             all                                     md5
# IPv4 local connections:
host    all             postgres        127.0.0.1/32            trust
host    all             all             127.0.0.1/32            md5
# IPv6 local connections:
host    all             postgres        ::1/128                 trust
host    all             all             ::1/128                 md5
```

```
$ sudo systemctl reload postgresql-9.4
```

### apple DB にテーブルを作成する

pgbench の初期化モードで。

```
$ /usr/pgsql-9.4/bin/pgbench -i -U apple apple
```

```
$ /usr/pgsql-9.4/bin/psql -U apple
apple=> \d
             List of relations
 Schema |       Name       | Type  | Owner 
--------+------------------+-------+-------
 public | pgbench_accounts | table | apple
 public | pgbench_branches | table | apple
 public | pgbench_history  | table | apple
 public | pgbench_tellers  | table | apple
(4 rows)
```

orange ユーザーが apple のテーブルを SELECT できるようにする

```
$ /usr/pgsql-9.4/bin/psql -U apple
apple=> GRANT SELECT ON pgbench_accounts, pgbench_branches, pgbench_history, pgbench_tellers TO orange;
GRANT
```

### orange DB にて FOREIGN TABLE を使う準備をする

CREATE EXTENSION は postgres (特権) ユーザーで実行する必要がある

```
$ sudo -u postgres /usr/pgsql-9.4/bin/psql orange
orange=# CREATE EXTENSION postgres_fdw;
CREATE EXTENSION
orange=# \dew
                      List of foreign-data wrappers
     Name     |  Owner   |       Handler        |       Validator        
--------------+----------+----------------------+------------------------
 postgres_fdw | postgres | postgres_fdw_handler | postgres_fdw_validator
(1 row)
```

CREATE SERVER と CREATE USER MAPPING で apple DB への接続情報を定義する。これも postgres ユーザーで行う。 ここでは誰でも FOREIGN TABLE を参照できるように public で USER MAPPING を指定しました。 USER MAPPING という名前からもわかるように、これは orange DB へのログインユーザーに対して apple DB へどのログインIDでアクセスするかを設定します。権限の異なるアカウントを使い分けることであるアカウントでは更新可能だが、別のアカウントでは更新不可などと制限できる。 orange ユーザーでなく apple ユーザーとしてアクセスさせることも可能で、そうすると今回の例の場合 FOREIGN TABLE 側から更新することも可能となる。（FOREIGN TABLE に対する GRANT も必要）

```
$ sudo -u postgres /usr/pgsql-9.4/bin/psql orange
orange=# CREATE SERVER apple FOREIGN DATA WRAPPER postgres_fdw OPTIONS (
orange(#     dbname 'apple',
orange(#     host 'localhost',
orange(#     port '5432'
orange(# );
CREATE SERVER
orange=# CREATE USER MAPPING FOR public SERVER apple OPTIONS (user 'orange', password 'mikan');
CREATE USER MAPPING
```

### apple DB にて便利 function を定義する

```
# /usr/pgsql-9.4/bin/psql -U apple 
apple=> CREATE OR REPLACE FUNCTION script_foreign_tables(param_server text
apple(>  , param_schema_search text
apple(>  , param_table_search text, param_ft_prefix text) RETURNS SETOF text
apple-> AS 
apple-> $$
apple$> -- params: param_server: name of foreign data server
apple$> --        param_schema_search: wildcard search on schema use % for non-exact
apple$> --        param_ft_prefix: prefix to give new table in target database 
apple$> --                        include schema name if not default schema
apple$> -- example usage: SELECT script_foreign_tables('prod_server', 'ch01', '%', 'ch01.ft_');
apple$>   WITH cols AS 
apple$>    ( SELECT cl.relname As table_name, na.nspname As table_schema, att.attname As column_name
apple$>     , format_type(ty.oid,att.atttypmod) AS column_type
apple$>     , attnum As ordinal_position
apple$>       FROM pg_attribute att
apple$>       JOIN pg_type ty ON ty.oid=atttypid
apple$>       JOIN pg_namespace tn ON tn.oid=ty.typnamespace
apple$>       JOIN pg_class cl ON cl.oid=att.attrelid
apple$>       JOIN pg_namespace na ON na.oid=cl.relnamespace
apple$>       LEFT OUTER JOIN pg_type et ON et.oid=ty.typelem
apple$>       LEFT OUTER JOIN pg_attrdef def ON adrelid=att.attrelid AND adnum=att.attnum
apple$>      WHERE 
apple$>      -- only consider non-materialized views and concrete tables (relations)
apple$>      cl.relkind IN('v','r') 
apple$>       AND na.nspname LIKE $2 AND cl.relname LIKE $3 
apple$>        AND cl.relname NOT IN('spatial_ref_sys', 'geometry_columns'
apple$>           , 'geography_columns', 'raster_columns')
apple$>        AND att.attnum > 0
apple$>        AND NOT att.attisdropped 
apple$>      ORDER BY att.attnum )
apple$>         SELECT 'CREATE FOREIGN TABLE ' || $4  || table_name || ' ('
apple$>          || string_agg(quote_ident(column_name) || ' ' || column_type 
apple$>            , ', ' ORDER BY ordinal_position)
apple$>          || ')  
apple$>    SERVER ' || quote_ident($1) || '  OPTIONS (schema_name ''' || quote_ident(table_schema) 
apple$>      || ''', table_name ''' || quote_ident(table_name) || '''); ' As result        
apple$> FROM cols
apple$>   GROUP BY table_schema, table_name
apple$> $$ language 'sql';
CREATE FUNCTION
```

### CREATE FOREIGN TABLE の生成

コピペしやすいように `\t`, `\a` で psql の出力を調整している。

```
$ /usr/pgsql-9.4/bin/psql -U apple
apple=> \t
Tuples only is on.
apple=> \a
Output format is unaligned.
apple=> SELECT script_foreign_tables('apple', 'public', '%', 'public.ft_');
CREATE FOREIGN TABLE public.ft_pgbench_accounts (aid integer, bid integer, abalance integer, filler character(84))  
   SERVER apple  OPTIONS (schema_name 'public', table_name 'pgbench_accounts'); 
CREATE FOREIGN TABLE public.ft_pgbench_branches (bid integer, bbalance integer, filler character(88))  
   SERVER apple  OPTIONS (schema_name 'public', table_name 'pgbench_branches'); 
CREATE FOREIGN TABLE public.ft_pgbench_history (tid integer, bid integer, aid integer, delta integer, mtime timestamp without time zone, filler character(22))  
   SERVER apple  OPTIONS (schema_name 'public', table_name 'pgbench_history'); 
CREATE FOREIGN TABLE public.ft_pgbench_tellers (tid integer, bid integer, tbalance integer, filler character(84))  
   SERVER apple  OPTIONS (schema_name 'public', table_name 'pgbench_tellers'); 
apple=> 
```

実際には次のようにファイルに書きだしたほうが便利 (psql 内での `\o create_foreign_table.sql` でも可)。

```
psql -At -c "SELECT script_foreign_tables('apple', 'public', '%',
'public.ft_')" > create_foreign_table.sql
```

`script_foreign_tables` の引数は `SELECT script_foreign_tables('apple', 'public', '%', 'public.ft_');`

| # | 実行例の値  | 説明                                                                   |
|---|-------------|------------------------------------------------------------------------|
| 1 | apple       | CREATE FOREIGN TABLE で指定する SERVER                                 |
| 2 | public      | apple DB での対象テーブルの schema                                     |
| 3 | %           | apple DB での対象テーブルを絞るための LIKE 条件 (% の場合は全てとなる) |
| 4 | public.ft\_ | CREATE TABLE 時の prefix (public.ft\_ であれば public schema に ft\_{original\_table\_name} という TABLE が作成される)。 public. であれば同じ名前の TABLE が作成される |

### CREATE FOREIGN TABLE

postgres ユーザーで orange DB に貼り付けて (もしくはファイルを読み込ませて) FOREIGN TABLE を作成する

```
$ sudo -u postgres /usr/pgsql-9.4/bin/psql orange
orange=# CREATE USER MAPPING FOR public SERVER apple OPTIONS (user 'orange', password 'mikan');
CREATE USER MAPPING
orange=# CREATE FOREIGN TABLE public.ft_pgbench_accounts (aid integer, bid integer, abalance integer, filler character(84))  
orange-#    SERVER apple  OPTIONS (schema_name 'public', table_name 'pgbench_accounts'); 
CREATE FOREIGN TABLE
orange=# CREATE FOREIGN TABLE public.ft_pgbench_branches (bid integer, bbalance integer, filler character(88))  
orange-#    SERVER apple  OPTIONS (schema_name 'public', table_name 'pgbench_branches'); 
CREATE FOREIGN TABLE
orange=# CREATE FOREIGN TABLE public.ft_pgbench_history (tid integer, bid integer, aid integer, delta integer, mtime timestamp without time zone, filler character(22))  
orange-#    SERVER apple  OPTIONS (schema_name 'public', table_name 'pgbench_history'); 
CREATE FOREIGN TABLE
orange=# CREATE FOREIGN TABLE public.ft_pgbench_tellers (tid integer, bid integer, tbalance integer, filler character(84))  
orange-#    SERVER apple  OPTIONS (schema_name 'public', table_name 'pgbench_tellers');
CREATE FOREIGN TABLE
orange=# 
```

postgres ユーザーで作成しているため、必要なユーザーがアクセス可能なように GRANT して上げる必要がある。これも大量にあるとつらいので次のようなクエリで対応する (FOREIGN TABLE は pg\_stat\_user\_tables から取得できなかった)

```sql
SELECT 'GRANT SELECT ON ' || relname || ' TO orange;'
  FROM pg_catalog.pg_class
 WHERE relkind = 'f';
```

### PostgreSQL 9.5 から FDW がもっと便利に

IMPORT FOREIGN SCHEMA を使えば簡単に source database の schema をコピーして foreign table が作れるようになるみたいです。

[http://www.postgresql.org/docs/9.5/static/sql-importforeignschema.html](http://www.postgresql.org/docs/9.5/static/sql-importforeignschema.html)

**[PostgreSQL 9.5 新機能紹介](//www.slideshare.net/hadoopxnttdata/postgresql-95-new-features-nttdata "PostgreSQL 9.5 新機能紹介")** from **[NTT DATA OSS Professional Services](//www.slideshare.net/hadoopxnttdata)**

以上
