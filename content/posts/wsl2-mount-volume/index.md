---
title: "WSL 2 で外部ストレージをマウント"
date: 2023-09-21T23:08:28+09:00
tags: [Windows, Linux, WSL2, XFS]
draft: false
---

Laptop を Linux で使用していた時の遺産を WSL 環境でも使おうと XFS でフォーマットされた USB 接続の HDD をマウントする方法がないかなと思って調べたメモ。

Microsoft のドキュメントにありました。

[Linux ディスクを WSL 2 にマウントする](https://learn.microsoft.com/ja-jp/windows/wsl/wsl2-mount-disk)

実際に試してみます。

## Windows 上での Device ID を確認する

PowerShell を開いて次のコマンドを実行します。

```bash
GET-CimInstance -query "SELECT * from Win32_DiskDrive"
```

```
PS C:\Users\ytera> GET-CimInstance -query "SELECT * from Win32_DiskDrive"

DeviceID           Caption                        Partitions Size          Model
--------           -------                        ---------- ----          -----
\\.\PHYSICALDRIVE0 CL4-3D512-Q11 NVMe SSSTC 512GB 5          512105932800  CL4-3D512-Q11 NVMe SSSTC 512GB
\\.\PHYSICALDRIVE1 TOSHIBA MQ01ABD100 USB Device  2          1000202273280 TOSHIBA MQ01ABD100 USB Device
```

ここで表示された `\\.\PHYSICALDRIVE1` を使います。

## Device を Linux に attach する

今回の HDD はパーティション分割されているので `--bare` オプションを指定しろと書かれています。

```
wsl --mount \\.\PHYSICALDRIVE1 --bare
```

```
PS C:\Users\ytera> wsl --mount \\.\PHYSICALDRIVE1 --bare
ディスクをマウントするには、管理者アクセス権が必要です。
Error code: Wsl/Service/AttachDisk/WSL_E_ELEVATION_NEEDED_TO_MOUNT_DISK
```

管理者権限で再実行します。


```
PS C:\Windows\system32> wsl --mount \\.\PHYSICALDRIVE1 --bare
この操作を正しく終了しました。
```

ここで WSL の Ubuntu 上で lsblk コマンドを実行して確認してみます。

```
$ lsblk
NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
sda      8:0    0 363.3M  1 disk
sdb      8:16   0     2G  0 disk [SWAP]
sdc      8:32   0     1T  0 disk /var/lib/docker
                                 /snap
                                 /mnt/wslg/distro
                                 /
sdd      8:48   0 931.5G  0 disk
├─sdd1   8:49   0   500G  0 part
└─sdd2   8:50   0 431.5G  0 part
```

<details>
<summary>mount 前の lsblk</summary>

```
$ lsblk
NAME
    MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
sda   8:0    0 363.3M  1 disk
sdb   8:16   0     2G  0 disk [SWAP]
sdc   8:32   0     1T  0 disk /var/lib/docker
                              /snap
                              /mnt/wslg/distro
                              /
```

</details>

`dmesg` コマンドでもデバイスを認識したログが確認できます。

```
[30688.416380] scsi 0:0:0:3: Direct-Access     TOSHIBA  MQ01ABD100       0200 PQ: 0 ANSI: 4
[30688.419647] sd 0:0:0:3: [sdd] 1953525168 512-byte logical blocks: (1.00 TB/932 GiB)
[30688.420121] sd 0:0:0:3: Attached scsi generic sg3 type 0
[30688.433255] sd 0:0:0:3: [sdd] Write Protect is off
[30688.433260] sd 0:0:0:3: [sdd] Mode Sense: 0f 00 00 00
[30688.460738] sd 0:0:0:3: [sdd] Write cache: enabled, read cache: enabled, doesn't support DPO or FUA
[30688.523883]  sdd: sdd1 sdd2
[30688.577911] sd 0:0:0:3: [sdd] Attached SCSI disk
```

ここまでくればこっちのものだと、`mount` コマンドを実行するのですが...

```bash
sudo mkdir /mnt/disk1
sudo mount -t xfs /dev/sdd1 /mnt/disk1
```


```bash
$ sudo mount -t xfs /dev/sdd1 /mnt/disk1
mount: /mnt/disk1: wrong fs type, bad option, bad superblock on /dev/sdd1, missing codepage or helper program, or other
error.
```

ん？

`dmesg` でログを確認してみる。

```
[31793.325808] XFS (sdd1): Deprecated V4 format (crc=0) not supported by kernel.
```

orz...

WSL の distribution を Ubuntu-18.04 に変更したら mount できるかな？と思って試してみましたが docker みたいなもので kernel は共通のようです。V4 format をサポートした Linux を用意して mount して中身取り出して再 format するしかないのか。

https://www.kernelconfig.io/config_xfs_support_v4

```
PS C:\> wsl --list --online
インストールできる有効なディストリビューションの一覧を次に示します。
'wsl.exe --install <Distro>' を使用してインストールします。

NAME                                   FRIENDLY NAME
Ubuntu                                 Ubuntu
Debian                                 Debian GNU/Linux
kali-linux                             Kali Linux Rolling
Ubuntu-18.04                           Ubuntu 18.04 LTS
Ubuntu-20.04                           Ubuntu 20.04 LTS
Ubuntu-22.04                           Ubuntu 22.04 LTS
OracleLinux_7_9                        Oracle Linux 7.9
OracleLinux_8_7                        Oracle Linux 8.7
OracleLinux_9_1                        Oracle Linux 9.1
openSUSE-Leap-15.5                     openSUSE Leap 15.5
SUSE-Linux-Enterprise-Server-15-SP4    SUSE Linux Enterprise Server 15 SP4
SUSE-Linux-Enterprise-15-SP5           SUSE Linux Enterprise 15 SP5
openSUSE-Tumbleweed                    openSUSE Tumbleweed
```

```bash
$ uname -a
Linux inspiron 5.15.90.1-microsoft-standard-WSL2 #1 SMP Fri Jan 27 02:56:13 UTC 2023 x86_64 x86_64 x86_64 GNU/Linux
```

## wsl コマンドで mount までさせられる

先ほどは `--bare` オプションをつけましたが、これをつけなかった場合 Linux 上でマウントまでやってくれるようです。

partition 分割されていなければ

```
wsl --mount \\.\PHYSICALDRIVE1
```

と実行するだけで ext4 としてマウントしてくれるようです。デフォルトでは mount point は自動生成のようです。

> 既定では、マウントポイント名は物理ディスクまたは VHD の名前に基づいて生成されます。 これは、 `--name` を使用してオーバーライドできます。


デフォルトは ext4 ですが、ファイルシステムは `--type` オプションで指定可能です。

```
    --mount <Disk>
        すべての WSL 2 ディストリビューションで物理ディスクまたは仮想ディスクをアタッチしてマウントします。

        オプション:
            --vhd
                <Disk> が仮想ハード ディスクであることを指定します。

            --bare
                ディスクを WSL2 にアタッチしますが、マウントはしません。

            --name <Name>
                マウント時のカスタム名を使用してディスクをマウントします。

            --type <Type>
                ディスクのマウント時に使用するファイル システム。指定しない場合は、既定で ext4 になります。

            --options <Options>
                追加のマウント オプション。

            --partition <Index>
                マウントするパーティションのインデックス。指定しない場合は、既定でディスク全体になります。
```

ディスクが partition 分割されている場合も `--partition` で番号指定することで mount までさせることができるようです。

`--options` で指定可能な mount option はファイルシステム固有のものだけのようです。

> 現時点では、ファイル システム固有のオプションのみがサポートされています。 `ro`, `rw`, `noatime`, ... などの汎用オプションはサポートされていません。

## Device の detach

```
wsl --unmount [DeviceID]
```

DeviceID を指定しなかったらすべてが detach される。

