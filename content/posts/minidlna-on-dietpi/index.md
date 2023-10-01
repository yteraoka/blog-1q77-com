---
title: DietPi で DNLA サーバー
date: 2023-09-30T17:33:09+09:00
draft: false
tags: [DietPi, "Raspberry Pi", DLNA]
---

Raspberry Pi 4 を買った週に Raspberry Pi 5 が発表されてちょっと悔しいところですが Windows XP 時代から OS を更新しながら使っていた古いデスクトップPCを処分したのでそこで使っていた HDD をラズパイにつないで Samba で NAS としてアクセス可能にしてみました。そこには昔ハンディカムで撮影した動画なんかも沢山保存されていたのでテレビでそれを見れるように DLNA のメディアサーバーすることにしました。

DLNA サーバーはいくつか選択肢があるみたいですが簡単そうなので MiniDLNA (ReadyMedia) を使うことにしました。
もともと NETGEAR が ReadyNAS 向けに作成していた Media Server だったらしく ReadyMedia とも呼ばれているみたい。

## インストール

ラズパイには [DietPi](https://dietpi.com/) をインストールしているので `dietpi-software` コマンドで
minidlna をインストールして `/etc/minidlna.conf` を書き換えるだけ。

デフォルトでは次のようになっているところを環境にあわせて変更する。

```
media_dir=A,/mnt/dietpi_userdata/Music
media_dir=P,/mnt/dietpi_userdata/Pictures
media_dir=V,/mnt/dietpi_userdata/Video

db_dir=/mnt/dietpi_userdata/.MiniDLNA_Cache
```

`media_dir` はメディアファイルのあるところをいくつも指定可能。`db_dir` に SQLite の DB ファイルと `art_cache` サブディレクトリに動画のサムネイルや音楽アルバムのジャケット画像？がコピーされてりリンクが張られたりする。
私の環境ではこの volume が vfat だったので synbolic link 作成がエラーになってたのかな？
また、vfat に書き込み可能なユーザーで minidlna サーバーを実行する必要があったので `systemctl edit minidlna` で `[Service]` セクションの `User` を上書きしている。ログは `/var/log/minidlna/minidlna.log` に出力されるのでそこの権限も調整する。

### メディアファイルの更新について

DB の更新は inotify でファイルの更新を検知して実行されるらしいが、私の今回の環境ではメディアのおかれているディスクは NTFS であり、ntfs3 driver でマウントしている。inotify は vfat や ntfs3 でマウントされた filesystem でも機能するのか不明だったので `inotifywait` を使って試してみた。`inotifywait` は `inotify-tools` パッケージに含まれている。

```
apt-get install -y inotify-tools
```

試してみた結果、vfat や ntfs3 でもイベントは発生しているので大丈夫そうだった。

ただし、今回ファイルを追加したり更新したりすることはなさそうなので minidlna.conf で `inotify=no` として更新は無効にしておいた。DB ファイルの保存先は SD カードじゃないので更新回数の心配はしていないがまあ不要なので。

minidlna サーバーを再起動すると DB ファイルは再作成となるっぽい。

<details>
<summary>メモ</summary>

ところで、今回 `/etc/fstab` に次のように書いたが

```
PARTUUID=3081ae75-01 /mnt/extra_data vfat noatime,lazytime,iocharset=utf8,codepage=932,uid=1000,gid=1000 0 2
PARTUUID=40d055f5-85fb-4205-8d91-62d36967ed5c /mnt/desktop ntfs3 noatime,lazytime,iocharset=utf8,uid=1000,gid=1000 0 2
```

`PARTUUID` は lsblk コマンドで確認することができる

```
# lsblk -o NAME,SIZE,TYPE,PTTYPE,FSTYPE,PARTUUID,MOUNTPOINTS
NAME          SIZE TYPE PTTYPE FSTYPE PARTUUID                             MOUNTPOINTS
sda         465.8G disk dos
└─sda1      465.8G part dos    vfat   3081ae75-01                          /mnt/extra_data
sdb           1.8T disk gpt
├─sdb1        128M part gpt           30580f1c-edb5-4418-891d-fc0c1f268d06
└─sdb2        1.8T part gpt    ntfs   40d055f5-85fb-4205-8d91-62d36967ed5c /mnt/desktop
mmcblk0      28.8G disk dos
├─mmcblk0p1   128M part dos    vfat   6d9e65d5-01                          /boot
└─mmcblk0p2  28.7G part dos    ext4   6d9e65d5-02                          /
```

また ntfs3 module は load されていなかったので `/etc/modules` に追加した

```
# /etc/modules: kernel modules to load at boot time.
#
# This file contains the names of kernel modules that should be loaded
# at boot time, one per line. Lines beginning with "#" are ignored.
# Parameters can be specified after the module name.
ntfs3
```

</details>

### ネットワーク

今回のラズパイは PiVPN (WireGuard) で VPN サーバーも兼ねており、それ用の Network Interface が存在して不要なログが出てたので `network_interface=wlan0` で interface を限定しておいた。

## 完成

テレビ (REGZA) で再生できるようになったし、Windows や iPhone からも [VLC media player](https://www.videolan.org/) で再生可能になりました。
