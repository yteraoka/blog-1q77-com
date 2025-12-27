---
title: '無料版の公開された Sophos Anti-Virus for Linux を Linux Mint で試す'
date: Fri, 22 May 2015 14:40:50 +0000
draft: false
tags: ['Linux', 'sophos', 'virus']
---

「[ソフォス、無料版 Linux アンチウイルス製品を個人向けに提供開始](https://www.sophos.com/ja-jp/press-office/press-releases/2015/05/sophos-av-for-linux-free-edition.aspx)」ということなので早速手元の Linux Mint にインストールしてみました。 環境はこれ

```
$ cat /etc/lsb-release
DISTRIB_ID=LinuxMint
DISTRIB_RELEASE=17
DISTRIB_CODENAME=qiana
DISTRIB_DESCRIPTION="Linux Mint 17 Qiana"
```

```
$ cat /etc/os-release 
NAME="Ubuntu"
VERSION="14.04.1 LTS, Trusty Tahr"
ID=ubuntu
ID_LIKE=debian
PRETTY_NAME="Ubuntu 14.04.1 LTS"
VERSION_ID="14.04"
HOME_URL="http://www.ubuntu.com/"
SUPPORT_URL="http://help.ubuntu.com/"
BUG_REPORT_URL="http://bugs.launchpad.net/ubuntu/"
```

```
$ uname -a
Linux vaio 3.13.0-24-generic #47-Ubuntu SMP Fri May 2 23:30:00 UTC 2014 x86_64 x86_64 x86_64 GNU/Linux
```

Sophos のサイトからインストーラ「sav-linux-free-9.9.tgz」をダウンロードします。 中身はこんな感じ

```
$ tar ztf sav-linux-free-9.9.tgz 
sophos-av/
sophos-av/sav.tar
sophos-av/talpa.tar
sophos-av/uncdownload.tar
sophos-av/install.sh
```

それではインスールします

```
$ cd sophos-av
$ sudo ./install.sh

Sophos Anti-Virus
=================
Copyright (c) 1989-2015 Sophos Limited. All rights reserved.

Sophos Anti-Virus インストーラへようこそ。Sophos Anti-Virus には、オンアクセススキャナ、
オンデマンドコマンドラインスキャナ、Sophos Anti-Virus デーモン、および Sophos Anti-Virus
GUI があります。

オンアクセススキャナ           ファイルがアクセスされると検索し、未感染の場合のみアクセスを許可
オンデマンドスキャナ           コンピュータの全体または一部を直ちに検索
Sophos Anti-Virus デーモン  Sophos Anti-Virus にコントロール、ログ、メール警告機能を
                          提供するバックグラウンドプロセス
Sophos Anti-Virus GUI     Web ブラウザ経由でアクセスするユーザーインターフェース


「Enter」キーを押して、使用許諾契約書を表示してください。そして、 を押してスクロールダウン
してください。

(使用許諾契約書は省略)

ライセンス内容に同意しますか？ はい(Y)/いいえ(N) [N]
> Y

Sophos Anti-Virus のインストール先を指定してください。 [/opt/sophos-av]
> 

オンアクセス検索を有効にしますか？ はい(Y)/いいえ(N) [Y]
> 

パスワードが入力されなかったため、Sophos Anti-Virus GUI を無効にしています。
有効にするには、/opt/sophos-av/bin/savsetup を実行してください。
ソフォスは、Sophos Anti-Virus での自動アップデートの設定をお勧めします。

ソフォスから直接アップデートしたり（要アカウント情報）、自社サーバー（ディレクトリや Web
サイト（アカウント情報が必要な場合もあります））からアップデートすることができます。

オートアップデートの種類を選択してください: ソフォス(s)/自社サーバー(o)/なし(n) [s]
> 

ソフォスから直接アップデートしています。
SAV for Linux の無償バージョン (f) と サポート対応付きバージョン (s) のどちらをインストールしますか？ [s]
> f
Sophos Anti-Virus for Linux の無償バージョンに対して、サポート対応は提供されていません。
無償ツールのフォーラムは次のサイトを参照してください。http://openforum.sophos.com/
ソフォスからアップデートを行うためにプロキシが必要ですか？ はい(Y)/いいえ(N) [N]
> 

Sophos Anti-Virus をインストールしています....
適切なカーネルサポートを選択しています...
Sophos Anti-Virus が起動すると、カーネルサポートを見つけるためアップデートします。 
これによって大幅な遅れが発生することがあります。
Sophos Anti-Virus は、インストール終了後、開始されました。
 Adding system startup for /etc/init.d/sav-protect ...
   /etc/rc0.d/K20sav-protect -> ../init.d/sav-protect
   /etc/rc1.d/K20sav-protect -> ../init.d/sav-protect
   /etc/rc6.d/K20sav-protect -> ../init.d/sav-protect
   /etc/rc2.d/S20sav-protect -> ../init.d/sav-protect
   /etc/rc3.d/S20sav-protect -> ../init.d/sav-protect
   /etc/rc4.d/S20sav-protect -> ../init.d/sav-protect
   /etc/rc5.d/S20sav-protect -> ../init.d/sav-protect
 Removing any system startup links for /etc/init.d/sav-rms ...
 Removing any system startup links for /etc/init.d/sav-web ...

インストールが完了しました。
ご使用のコンピュータは Sophos Anti-Virus で保護されるようになりました。

警告: ソフォスがバイナリカーネルモジュールを提供していないカーネル環境で Sophos
Anti-Virus を稼動しています。したがって、カーネルモジュールはローカルでコンパイル
されました。対応するプラットフォームとカーネルについてはサポートデータベースの文章
14377 を参照してください。 
```インストールできました、プロセスをみるとこんな感じ```
$ pstree -Apa 3710
savd,3710 etc/savd.cfg
  |-savscand,5948 --incident=unix://tmp/incident...
  |   |-{savscand},5949
  |   |-{savscand},5950
  |   |-{savscand},5951
  |   |-{savscand},5952
  |   |-{savscand},5953
  |   |-{savscand},5954
  |   |-{savscand},5960
  |   |-{savscand},5961
  |   |-{savscand},5962
  |   |-{savscand},5963
  |   |-{savscand},5964
  |   |-{savscand},5965
  |   \`-{savscand},5966
  |-savscand,5959 --incident=unix://tmp/incident socketpair://45/46 ...
  |   |-{savscand},5967
  |   |-{savscand},5968
  |   |-{savscand},5969
  |   |-{savscand},5970
  |   |-{savscand},5971
  |   |-{savscand},5980
  |   |-{savscand},5981
  |   |-{savscand},5982
  |   |-{savscand},5983
  |   |-{savscand},5984
  |   |-{savscand},5985
  |   \`-{savscand},5986
  |-{savd},3713
  |-{savd},3714
  |-{savd},3716
  \`-{savd},5947
```

ではテスト用の Virus である [Eicar](http://www.eicar.org/83-0-Anti-Malware-Testfile.html) を試してみます。 次の文字列を vi で eicar というファイルとして保存してみます。

```
X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*
```

すると次のようなウインドウが出てきました。

{{< figure src="eicar-detected.png" alt="EICAR Detected" >}}

Linux Mint (Cinnamon) のファイルマネージャである [Nemo](http://en.wikipedia.org/wiki/Nemo_(file_manager)) で eicar ファイルのあるフォルダを開いても表示されます。 インストール時に GUI が無効になっていると表示されていたので、これを有効にしてみます。

```
パスワードが入力されなかったため、Sophos Anti-Virus GUI を無効にしています。
有効にするには、/opt/sophos-av/bin/savsetup を実行してください。
```

```
$ sudo /opt/sophos-av/bin/savsetup
Sophos Anti-Virus 対話型 環境設定へようこそ


[1] 自動アップデートの環境設定
[2] Sophos Anti-Virus GUI 環境設定
[q] 終了
実行する操作を選択してください。 [1]
> 2

Sophos Anti-Virus GUI デーモンを有効にしますか？ はい(Y)/いいえ(N) [N]
> Y

Sophos Anti-Virus GUI デーモンを設置するポート番号を入力してください。 [8081]
> 

Sophos Anti-Virus GUI デーモンへのアクセスに使用するユーザー名を入力してください。 [admin]
> 

Sophos Anti-Virus GUI デーモンへのアクセスに使用するパスワードを入力してください。
> 
同じパスワードを再入力してください。
> 
 Adding system startup for /etc/init.d/sav-web ...
   /etc/rc0.d/K20sav-web -> ../init.d/sav-web
   /etc/rc1.d/K20sav-web -> ../init.d/sav-web
   /etc/rc6.d/K20sav-web -> ../init.d/sav-web
   /etc/rc2.d/S20sav-web -> ../init.d/sav-web
   /etc/rc3.d/S20sav-web -> ../init.d/sav-web
   /etc/rc4.d/S20sav-web -> ../init.d/sav-web
   /etc/rc5.d/S20sav-web -> ../init.d/sav-web

```

有効になりました。 http://localhost:8081/ にアクセスします。次のような管理ツールでした。

{{< figure src="Sophos-Anti-Virus-GUI-Home.png" alt="Home" >}}

{{< figure src="Sophos-Anti-Virus-GUI-Control.png" alt="Control" >}}

{{< figure src="Sophos-Anti-Virus-GUI-Search.png" alt="Search" >}}

{{< figure src="Sophos-Anti-Virus-GUI-Exception.png" alt="Exception" >}}

{{< figure src="Sophos-Anti-Virus-GUI-Alert.png" alt="Alert" >}}

{{< figure src="Sophos-Anti-Virus-GUI-LogViewer.png" alt="Log Viewer" >}}

自動駆除、自動削除を有効にしてみる GUI の「検索」タブから「感染アイテムを自動駆除する」、「感染アイテムを自動削除する」を有効にした後、再度 eicar にアクセスしてみると次のように表示され削除されました。

{{< figure src="eicar-deleted.png" alt="Deleted" >}}

ESET も Linux のデスクトップ版を提供予定のようで現在先行評価版（無料）が公開されています。法人向けなので正規版は当然有償でしょう。 [ESET NOD32アンチウイルス for Linux Desktop V4.0 先行評価版プログラム公開のご案内](http://canon-its.jp/eset/eavl/index.html)
