---
title: 'Docker 使うなら石川さんごめんなさいしてる場合ではない'
date: Wed, 01 Feb 2017 05:51:40 +0000
draft: false
tags: ['CentOS', 'Docker', 'Docker', 'SELinux', 'SELinux']
---

Docker を Kubernetes や Swarm でサービスを実行する場合は JSON や YAML などで事前に定義したものを実行するだけなので知っているけどそれほど脅威ではありませんでしたが docker を便利コマンドや batch として自由に任意のコマンドを実行したいと言われるととたんに **\-v /:/rootfs** とか、**\--privileged** されたらどうしようという壁にぶち当たるわけです。 しかし、安全に使えたら便利なのでなんとかならないかなと CentOS 7 の公式リポジトリの Docker なら SELinux でなんとかする方法があるかもしれないなと調べてみました。 公式リポジトリの docker は古いんじゃないかと疑ってましたが 1.12.5 だったのでこれなら悪くない。クラスタの方では 1.11.1 使ってるし。```
$ rpm -q docker
docker-1.12.5-14.el7.centos.x86\_64

```storage driver を devicemapper にしないと警告が出るやつも **docker-storage-setup** で簡単に変更できた。

*   [https://github.com/projectatomic/docker-storage-setup](https://github.com/projectatomic/docker-storage-setup)
*   [第8章 DOCKER フォーマットコンテナーを使用したストレージの管理](https://access.redhat.com/documentation/ja/red-hat-enterprise-linux-atomic-host/7/paged/getting-started-with-containers/chapter-8-managing-storage-with-docker-formatted-containers)

kickstart の後処理で SELinux を無効にしてしまっていたので戻します。ごめんなさい。🙇```
$ sudo sed -i 's/^SELINUX=.\*$/SELINUX=enforcing/' /etc/selinux/config
$ sudo touch /.autorelabel
$ sudo shutdown -r now

```さて、SELinux が有効な docker 環境が出来たので早速例のコマンドを試してみます。 (実際には SELinux を有効にした後に docker のインストール以降を行っています)```
\# docker run -it -v /:/rootfs ubuntu bash
root@c78efbd64991:/# cat /rootfs/etc/shadow
cat: /rootfs/etc/shadow: Permission denied
root@c78efbd64991:/# echo test >> /rootfs/etc/passwd
bash: /rootfs/etc/passwd: Permission denied

```/etc/passwd には書き込めないし、/etc/shadow は中身を見ることすらできません。素晴らしい。 audit.log を確認してみる```
\# grep denied /var/log/audit/audit.log
type=AVC msg=audit(1485879393.821:7029): avc:  denied  { read } for  pid=10530 comm="cat" name="shadow" dev="dm-0" ino=67685 scontext=system\_u:system\_r:svirt\_lxc\_net\_t:s0:c217,c489 tcontext=system\_u:object\_r:shadow\_t:s0 tclass=file
type=AVC msg=audit(1485879415.350:7030): avc:  denied  { append } for  pid=10500 comm="bash" name="passwd" dev="dm-0" ino=67691 scontext=system\_u:system\_r:svirt\_lxc\_net\_t:s0:c217,c489 tcontext=system\_u:object\_r:passwd\_file\_t:s0 tclass=file

```**しかーし！**これでも **\--privileged** をつけてしまうと制限が効かなくなり /etc/shadow だって書き換えられちゃいます。libc.so だって消せちゃう。(昔々、何を思ったのかこれを消しちまった人がいるんですよー、なぁにぃ？！やっちまったなぁ！)```
\# docker run -it -v /:/rootfs --rm --privileged ubuntu bash
root@36103222099e:/# cd /rootfs/
root@36103222099e:/rootfs# echo aaa > etc/shadow
root@36103222099e:/rootfs# cat etc/shadow
aaa
root@36103222099e:/rootfs# rm lib64/libc-2.17.so 
root@36103222099e:/rootfs# 

```きゃー😱 ところで、docker.com にあるインストール手順などでは **usermod -aG docker username** で docker グループに参加させれば docker.sock にアクセスできて sudo 要らずで便利だよと書かれている。しかしながら Enterprise 仕様の RHEL とその仲間の Fedora, CentOS ではこれが出来ません。```
\# ls -l /var/run/docker.sock 
srw-rw----. 1 root root 0 Feb  1 11:18 /var/run/docker.sock

```証跡が残らないので sudo を使えという方針のようです。

*   [Why we don't let non-root users run Docker in CentOS, Fedora, or RHEL](http://www.projectatomic.io/blog/2015/08/why-we-dont-let-non-root-users-run-docker-in-centos-fedora-or-rhel/)

**sudo** を使おうが使うまいが例のオプションが指定できてしまっては困るのでなんとか防ぐ方法を見つけたい。**man sudoers** を読んでみた。「**!**」をつければ除外できるようである。```
%users ALL=(root) NOPASSWD: /usr/bin/docker, \\
                            !/usr/bin/docker \* --privileged \*, \\
                            !/usr/bin/docker \* --security-opt\* \*, \\
                            !/usr/bin/docker \* --cap-add\* \*

```こうすることで **\--privileged** をつけては docker コマンドを実行できなくなりました```
$ sudo docker run -it --rm -v /:/rootfs --privileged ubuntu bash
Sorry, user ytera is not allowed to execute '/bin/docker run -it --rm -v /:/rootfs --privileged ubuntu bash' as root on localhost.localdomain.

```いぇい！😎 抜け道があったらぜひ教えてください ただ、SELinux を有効にしたことで次のように```
$ mkdir $HOME/work
$ sudo docker run -it --rm -v $HOME/work:/work ubuntu bash
root@8dffed1e3583:/# ls work
ls: cannot open directory 'work': Permission denied
root@8dffed1e3583:/# echo test > work/test.txt
bash: work/test.txt: Permission denied
root@8dffed1e3583:/# 

```全然ホスト側のディスクにアクセスできません 😢 (/etc 配下は ReadOnly でアクセスできる) コンテナ間で共有したいのであれば volume を使うのが良いと思います (**docker volume create volume-name**) どうしてもホスト側のディレクトリをマウントしたいという場合は **chcon** で **svirt\_sandbox\_file\_t** という SELinux security context に設定します```
$ ls -ldZ work
drwxr-xr-x. ytera users unconfined\_u:object\_r:user\_home\_t:s0 work
$ chcon -t svirt\_sandbox\_file\_t work
$ ls -ldZ work
drwxr-xr-x. ytera users unconfined\_u:object\_r:svirt\_sandbox\_file\_t:s0 work
$ sudo docker run -it --rm -v $HOME/work:/work ubuntu bash
root@4f4cb02951b3:/# ls work
root@4f4cb02951b3:/# echo test > work/test.txt
root@4f4cb02951b3:/# cat work/test.txt
test
root@4f4cb02951b3:/# exit
$ cat work/test.txt
test
$ ls -lZ work/test.txt
-rw-r--r--. root root system\_u:object\_r:svirt\_sandbox\_file\_t:s0 work/test.txt

```relabel とかも機能するようにするには **semanage** で設定します。 参考資料

*   [Practical SELinux and Containers](http://www.projectatomic.io/blog/2016/03/dwalsh_selinux_containers/)
*   [Using Volumes with Docker can Cause Problems with SELinux](http://www.projectatomic.io/blog/2015/06/using-volumes-with-docker-can-cause-problems-with-selinux/)
*   [コンテナーセキュリティーガイド](https://access.redhat.com/documentation/ja/red-hat-enterprise-linux-atomic-host/7/paged/container-security-guide/)
*   [SELinux と Docker と OpenShift v3](http://qiita.com/nak3/items/361b62595601828bd354)
*   [Docker privileged オプションについて](http://qiita.com/muddydixon/items/d2982ab0846002bf3ea8)