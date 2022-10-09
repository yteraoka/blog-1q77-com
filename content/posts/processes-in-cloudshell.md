---
title: 'CloudShell のプロセス'
date: Tue, 31 Dec 2019 14:55:12 +0000
draft: false
tags: ['GCP']
---

GCP の Cloud Shell を触ってみて、ふとどんな環境で動いてるんだろう？と気になったのでちょっと調べてみた。

Cloud Shell とは
--------------

[Cloud Shell](https://cloud.google.com/shell/) はブラウザから shell にアクセス可能な Linux コンテナ環境で[多くの言語](https://cloud.google.com/shell/docs/how-cloud-shell-works#language_support) (Java, Go, Python, Node.js, Ruby, PHP, .NET Core) と gcloud や gsutil などはもちろん他にも [多くのツール](https://cloud.google.com/shell/docs/how-cloud-shell-works#tools)（Emacs も Vim も入ってる）を含んでおり、イメージは毎週更新されるようです。

Linux Distribution は debian で、apt でパッケージを追加することも可能。常に必要なら後述の ~/.customize\_environment に書いておく。

```
$ cat /etc/os-release
PRETTY\_NAME="Debian GNU/Linux 9 (stretch)"
NAME="Debian GNU/Linux"
VERSION\_ID="9"
VERSION="9 (stretch)"
VERSION\_CODENAME=stretch
ID=debian
HOME\_URL="https://www.debian.org/"
SUPPORT\_URL="https://www.debian.org/support"
BUG\_REPORT\_URL="https://bugs.debian.org/"

```

root 権限あるし、任意の Docker コンテナ実行できるし[ファイルのアップロード、ダウンロード](https://cloud.google.com/shell/docs/uploading-and-downloading-files)もできるしエディタとして VS Code みたいな [Theia](https://theia-ide.org/) も使える便利環境です。インスタンスは通常 g1-small （0.5 vCPU, 1.7GB メモリ）ですが、ブーストモードで n1-standard-1 （1 vCPU, 3.75GB メモリ）にすることも可能。ブーストモードの詳細は知らない。

### Open in Cloud Shell

[Open in Cloud Shell](https://cloud.google.com/shell/docs/open-in-cloud-shell) 機能を使えばワンクリックで指定の Docker コンテナ環境に git repository を clone してブラウザ内のエディタで開くことが出来ます。

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://ssh.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https%3A%2F%2Fgithub.com%2Fyteraoka%2Fflask-sample.git&cloudshell_open_in_editor=app%2Fapp.py)

Cloud Shell を立ち上げて次のコマンドを実行するのと同じした。

```
cloudshell\_open --repo\_url "https://github.com/yteraoka/flask-sample.git" --page "editor" --open\_in\_editor "app/app.py"

```

ちなみに `alias edit='cloudshell edit-files'` が設定されているため `edit some-exist-file` とするだけで Theia で開くことが出来ます。`dl` という alias もあって簡単にファイルをダウンロード出来ます。

### Web Preview

Cloud Shell 内で 8080/tcp を listen したサーバーを起動させて [Web Preview](https://cloud.google.com/shell/docs/using-web-preview) 機能を使えばブラウザでアクセスすることが出来ます。

ドキュメントにあるようにアプリを書いて実行することもできるし、次のように docker container で 8080 をマップすることでも対応可能。

```
docker run -d -p 8080:80 nginx

```

### ストレージ

5GB ある /home 配下は永続化され、新しいコンテナに切り替わってもデータは引き継がれます。120日間アクセスが無いとこのストレージは削除されます。

### 料金

[無料](https://cloud.google.com/shell/pricing)らしい。

プロセスを見てみる
---------

さて、どんな環境かということで ps コマンドで確認してみると次のようになっていました。

```
username@cloudshell:~ (project-id)$ ps auxwwf
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.0  0.1  17976  2876 ?        Ss   12:23   0:00 /bin/bash /google/scripts/onrun.sh sleep infinity
root           8  4.6  0.1 250116  2200 ?        Ssl  12:23   0:00 /usr/sbin/rsyslogd
root          81  0.0  0.1  69960  3172 ?        S<s  12:23   0:00 /usr/sbin/sshd -p 22 -o AuthorizedKeysFile=/etc/ssh/keys/authorized\_keys
root         294  0.0  0.3  86552  6476 ?        S<s  12:23   0:00  \\\_ sshd: username \[priv\]
username     298  0.0  0.2  86552  4352 ?        S<   12:23   0:00      \\\_ sshd: username@pts/0
username     299  0.0  0.1  11176  3044 pts/0    S<s+ 12:23   0:00          \\\_ bash -c if \[ -f /google/devshell/start-shell.sh \]; then   /google/devshell/start-shell.sh  38771  'project-id'  ''  '1363912993'  false else  touch /var/run/google/devshell/38771 &&  bash --login fi
username     301  0.0  0.1  11192  2896 pts/0    S<+  12:23   0:00          |   \\\_ /bin/bash /google/devshell/start-shell.sh 38771 project-id  1363912993 false
username     306  0.0  0.1  19332  3064 pts/0    S<+  12:23   0:00          |       \\\_ tmux new-session -A -D -n cloudshell -s 1363912993
username     300  0.0  0.0  12688  1724 ?        S<s  12:23   0:00          \\\_ /usr/lib/openssh/sftp-server
root         156  1.6  3.8 376044 66772 ?        Sl   12:23   0:00 /usr/bin/dockerd -p /var/run/docker.pid --mtu=1460 --registry-mirror=https://asia-mirror.gcr.io
root         170  0.5  2.4 496136 42304 ?        Ssl  12:23   0:00  \\\_ containerd --config /var/run/docker/containerd/containerd.toml --log-level info
username     289  3.6  1.1  58580 20368 ?        S    12:23   0:00 /usr/bin/python /usr/bin/supervisord -n -c /google/devshell/supervisord.conf -u username --pidfile=/var/run/supervisor.pid --logfile=/var/log/supervisord.log
username     365  2.2  0.9  43128 17304 ?        S    12:23   0:00  \\\_ /usr/bin/python /google/devshell/send\_heartbeats.py
root         290  0.0  0.0  25384  1504 ?        S    12:23   0:00 logger -t supervisord
root         293  0.0  0.0   4188   612 ?        S    12:23   0:00 sleep infinity
username     308  0.0  0.1  27940  3280 ?        S<s  12:23   0:00 tmux new-session -A -D -n cloudshell -s 1363912993
username     309  1.8  0.3  23080  6712 pts/1    S<s  12:23   0:00  \\\_ -bash
username     383  0.0  0.1  38304  3200 pts/1    R<+  12:24   0:00      \\\_ ps auxwwf
username@cloudshell:~ (project-id)$

```

PID 1 で onrun.sh が実行されており何らかのコンテナで実行されてるっぽい。sleep コマンドの引数に infinity なんて使い方ができるんですね。([sleep infinity で無限に待つ - @tmtms のメモ](https://tmtms.hatenablog.com/entry/201909/sleep-infinity))

onrun.sh の中では rsyslogd を実行した後に環境変数 ONRUM で指定されたコマンドを順に実行し、その後、引数で指定されたコマンド（sleep infinity）が実行されます。環境変数 ONRUN には /google/devshell/startup.sh /google/scripts/wrapdocker.sh /google/devshell/start-supervisord.sh が入っていました。（以下、環境変数による細かい振る舞いは省略）

### startup.sh

*   ログイン関連で必要となるファイルを [vmtouch](https://hoytech.com/vmtouch/) コマンドでキャッシュに乗っける
*   ~/.customize\_environment が存在すれば実行する（これは初回起動時のみ）  
    [Environment customization](https://cloud.google.com/shell/docs/configuring-cloud-shell#environment_customization)
*   useradd コマンドでユーザーを作成する（docker, adm, sudo グループに所属）
*   sshd の起動  
    AuthorizedKeysFile=/etc/ssh/keys/authorized\_keys と指定されており、ここには [Theia](https://theia-ide.org/) 用とおぼしき公開鍵も入っていました
*   /etc/environment への環境変数の設定
*   Google Cloud SDK 設定

### wrapdocker.sh

環境変数 DISABLE\_DIND が空でなければ何もしない。

*   stdin / stdout / stderr 以外の file descripter を閉じる（fork で引き継いだやつとかかな？）
*   DOCKER\_OPTS を /etc/default/docker に追記
*   service docker start で docker daemon を起動させる

### start-supervisord.sh

*   supervisord を起動させる

supervisord では /google/devshell/send\_heartbeats.py を実行する。send\_heartbeats.py は1分おきに ssh.cloud.google.com にあるエンドポイントに対してハートビートリクエストを送る。

### その他

/google/devshell/start-shell.sh ってどこから実行してるのかな？って悩んでたのだけれどこれは単に ssh してから実行してるのかな。

まとめ
---

セッションは最長12時間であるとか、[いくつかの制限](https://cloud.google.com/shell/docs/limitations)はありますが、ブラウザさえあれば使える便利な環境が無料で使えるんです。もちろん GCP 関係ない作業にも使える。

調査することで sleep に infinity が指定可能であるとか vmtouch や mountpoint コマンドというものがあるということを知ることができました。やったね！