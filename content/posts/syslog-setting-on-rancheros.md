---
title: 'RancherOSでsyslogを別サーバーに送る'
date: Mon, 08 May 2017 15:41:48 +0000
draft: false
tags: ['Docker', 'RancherOS']
---

[RancherOS](http://rancher.com/rancher-os/) は syslogd も docker container で稼働しています。

OS のサービスとして動かすコンテナは `system-docker` コマンドで操作します。

```
$ sudo system-docker ps --format 'table {{.ID}}\t{{.Image}}\t{{.Command}}\t{{.Names}}'             
CONTAINER ID        IMAGE                       COMMAND                  NAMES
00d574dcd02a        rancher/os-docker:1.12.6    "ros user-docker"        docker
a086f9e01e66        rancher/os-console:v1.0.1   "/usr/bin/ros entrypo"   console
d860b0783517        rancher/os-base:v1.0.1      "/usr/bin/ros entrypo"   ntp
61a493aa2cd2        rancher/os-base:v1.0.1      "/usr/bin/ros entrypo"   network
53b33a360900        rancher/os-base:v1.0.1      "/usr/bin/ros entrypo"   udev
dbac7f916cc2        rancher/os-base:v1.0.1      "/usr/bin/ros entrypo"   syslog
bf69300b6715        rancher/os-acpid:v1.0.1     "/usr/bin/ros entrypo"   acpid
```

`syslog` という名前のコンテナがいますね。

```
$ sudo system-docker ps --no-trunc -f name=syslog --format 'table {{.Image}}\t{{.Command}}\t{{.Names}}'         
IMAGE                    COMMAND                                 NAMES
rancher/os-base:v1.0.1   "/usr/bin/ros entrypoint rsyslogd -n"   syslog
```

`rsyslogd` の `-n` は

> Avoid auto-backgrounding. This is needed especially if the rsyslogd is started and controlled by init(8).

ということで普通に rsyslogd が起動しているだけっぽいので `/etc/rsyslog.conf` を読んでいるはず、ホストの `/etc` か `/etc/rsyslog.conf` をマウントしてるのかな？と思って確認してみる。

```
$ sudo system-docker inspect --format '{{range .Mounts}}{{printf "%-36s -> %s\n" .Source .Destination}}{{end}}' syslog
/usr/share/ros                       -> /usr/share/ros
/lib/modules                         -> /lib/modules
/run                                 -> /run
/etc/selinux                         -> /etc/selinux
/usr/bin/ros                         -> /usr/bin/ros
/dev                                 -> /host/dev
/var/log                             -> /var/log
/var/lib/rancher/cache               -> /var/lib/rancher/cache
/var/lib/rancher                     -> /var/lib/rancher
/lib/firmware                        -> /lib/firmware
/etc/docker                          -> /etc/docker
/etc/resolv.conf                     -> /etc/resolv.conf
/etc/ssl/certs/ca-certificates.crt   -> /etc/ssl/certs/ca-certificates.crt.rancher
/etc/hosts                           -> /etc/hosts
/var/lib/rancher/conf                -> /var/lib/rancher/conf
/var/run                             -> /var/run
```

マウントしてない。 けれどもホストの `/etc/rsyslog.conf` を書き換えて再起動してみる。

```
*.* @syslog-server
```

を追記して再起動するのですが、再起動方法は

```
$ sudo system-docker restart syslog
```

です。再起動してみるも syslog-server に送ってくれない。ということでコンテナ内のファイルを書き換えて再起動します。

```
$ sudo system-docker exec -it syslog vi /etc/rsyslog.conf
```

`rsyslog.conf` には

```
$IncludeConfig /etc/rsyslog.d/*.conf
```

という記述があるので `/etc/rsyslog.d/relay.conf` などに書くこともできます。
コンテナ内のファイルを書き換えて再起動することで無事ログの転送ができました。めでたしめでたし。

### おまけ

rsyslog は UDP だけでなく TCP での転送に対応しています。`@` 1個だと UDP で、TCP で送りたい場合は `@@` と2個にします。
CentOS だと次のようなコメントが `rsyslog.conf` に書いてあります。TCP を使う場合は接続が切れた場合にログを出力するプログラムが止まってしまわないように Queue を有効にしておくべきです。繋がらない場合にディスクに溜めておいてくれます。復旧時には多くのサーバーから一斉に送られるとサーバー側に負荷がかかりすぎたりしないようにゆっくりと流れるようになってるみたいです。（復旧したのにログが流れてこない！！って悩んだことがあります）

```
# ### begin forwarding rule ###
# The statement between the begin ... end define a SINGLE forwarding
# rule. They belong together, do NOT split them. If you create multiple
# forwarding rules, duplicate the whole block!
# Remote Logging (we use TCP for reliable delivery)
#
# An on-disk queue is created for this action. If the remote host is
# down, messages are spooled to disk and sent when it is up again.
#$WorkDirectory /var/lib/rsyslog # where to place spool files
#$ActionQueueFileName fwdRule1 # unique name prefix for spool files
#$ActionQueueMaxDiskSpace 1g   # 1gb space limit (use as much as possible)
#$ActionQueueSaveOnShutdown on # save messages to disk on shutdown
#$ActionQueueType LinkedList   # run asynchronously
#$ActionResumeRetryCount -1    # infinite retries if host is down
# remote host is: name/ip:port, e.g. 192.168.0.1:514, port optional
#*.* @@remote-host:514
# ### end of the forwarding rule ###
```
