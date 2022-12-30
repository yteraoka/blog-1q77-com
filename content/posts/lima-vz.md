---
title: "Lima の vmType VZ と virtiofs を試す"
date: 2022-12-30T00:49:47+09:00
tags: ["Docker", "macOS", "lima"]
draft: false
---

[Lima](https://github.com/lima-vm/lima) が [version 0.14.0](https://github.com/lima-vm/lima/releases/tag/v0.14.0) で QEMU だけではなく macOS の Virtualization.Framework に対応していました。

[vmtype](https://github.com/lima-vm/lima/blob/v0.14.0/docs/vmtype.md) という設定項目が増えています。

この新しい Framework では Host のディレクトリをマウントするのに virtiofs が使えるようになっており、QEMU での `reverse-sshfs` や `9p` よりもパフォーマンスが良いらしいので試してみます。

とりあえず fio を使ってみますが、Host (mac) でのキャッシュの状況の影響を受けるだろうし、ディレクトリのリストやファイルの open、close が遅い場合は測れないけどとりあえず参考までにということで。fio だけではイマイチだったので tarball の展開にかかる時間も比較してみた。

lima は普段 [docker 用の VM](https://blog.1q77.com/2022/01/docker-on-lima/) として使っているので docker の volume としてマウントして docker コンテナ内で fio コマンドを実行しています。


```
$ limactl --version
limactl version 0.14.2
```

`vz` (Virtualization.Framework) は macOS 13 以降でしか使えないみたいです。また、ARM の Guest として Intel VM を実行することもできないみたいです。

```
$ sw_vers
ProductName:            macOS
ProductVersion:         13.1
BuildVersion:           22C65
```

```
# fio --version
fio-3.25
```

## VM 作成

lima の VM は [examples/docker.yaml](https://github.com/lima-vm/lima/blob/v0.14.2/examples/docker.yaml)
をベースにして `vmType` と `mountType` を変更して作成しました。

```
$ limactl ls
NAME                STATUS     SSH                VMTYPE    ARCH      CPUS    MEMORY    DISK      DIR
qemu-9p-docker      Stopped    127.0.0.1:0        qemu      x86_64    2       2GiB      100GiB    ~/.lima/qemu-9p-docker
qemu-ssh-docker     Stopped    127.0.0.1:0        qemu      x86_64    2       2GiB      100GiB    ~/.lima/qemu-ssh-docker
vz-virtfs-docker    Running    127.0.0.1:52261    vz        x86_64    2       2GiB      100GiB    ~/.lima/vz-virtfs-docker
```

VM の情報はこんな感じ。

```
$ uname -r
5.15.0-56-generic
```

```
$ cat /etc/os-release
PRETTY_NAME="Ubuntu 22.04.1 LTS"
NAME="Ubuntu"
VERSION_ID="22.04"
VERSION="22.04.1 LTS (Jammy Jellyfish)"
VERSION_CODENAME=jammy
ID=ubuntu
ID_LIKE=debian
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
UBUNTU_CODENAME=jammy
```

### docker context

以前 [blog (Docker on Lima)](https://blog.1q77.com/2022/01/docker-on-lima/) を書いたときは `DOCKER_HOST` という環境変数を指定することで VM 上の docker daemon にアクセスするようにしていましたが。`limactl start` で VM を作成した時に表示される [メッセージ](https://github.com/lima-vm/lima/blob/v0.14.2/examples/docker.yaml#L81-L85) が更新されていて `docker context` というものを知りました。今後はこれを使うことにします。

```
$ docker context ls
NAME                      DESCRIPTION                               DOCKER ENDPOINT                                                 KUBERNETES ENDPOINT   ORCHESTRATOR
default                   Current DOCKER_HOST based configuration   unix:///var/run/docker.sock                                                           swarm
desktop-linux                                                       unix:///Users/teraoka/.docker/run/docker.sock
lima-qemu-9p-docker                                                 unix:///Users/teraoka/.lima/qemu-9p-docker/sock/docker.sock
lima-qemu-ssh-docker                                                unix:///Users/teraoka/.lima/qemu-ssh-docker/sock/docker.sock
lima-vz-virtfs-docker *                                             unix:///Users/teraoka/.lima/vz-virtfs-docker/sock/docker.sock
rancher-desktop           Rancher Desktop moby context              unix:///Users/teraoka/.rd/docker.sock
```


## fio で IOPS を比較

次のコマンドを使って fio を実行しました。

```
docker pull debian:11.6
docker run --rm -it -v $(pwd):/work debian:11.6 bash
```

```
apt-get update && apt-get install -y fio bc
fio /work/test.fio --section=random-read
fio /work/test.fio --section=random-write
fio /work/test.fio --section=random-readwrite
```

### test.fio

`test.fio` ファイルの中身は次のもの。

```
[global]
size=2*1024*1024*$mb_memory
directory=/work
bs=4k
numjobs=$ncpus
thread=1
runtime=60s
direct=1
ioengine=libaio
group_reporting=1

[random-read]
rw=randread

[random-write]
rw=randwrite

[random-readwrite]
rw=randrw
rwmixread=70
rwmixwrite=30
```

## IOPS 結果

各環境で5回実行。うーん、IOPS だけだと 9p と virtiofs との差はなんとも言えない感じ。

| vmType | mountType     | Random Read IOPS | Random Write IOPS | Random Read/Write IOPS |
|--------|---------------|-----------------:|------------------:|-----------------------:|
| QEMU   | reverse-sshfs |            1,495 |             2,755 |          1,037 /   443 |
| QEMU   | reverse-sshfs |            1,772 |               604 |          1,172 /   503 |
| QEMU   | reverse-sshfs |            1,702 |             3,279 |          1,135 /   487 |
| QEMU   | reverse-sshfs |            1,764 |             2,919 |          1,153 /   495 |
| QEMU   | reverse-sshfs |            1,771 |             1,939 |          1,139 /   488 |
| QEMU   | 9p            |            5,814 |             4,839 |          4,030 / 1,729 |
| QEMU   | 9p            |            5,703 |             4,143 |          3,819 / 1,637 |
| QEMU   | 9p            |            8,916 |             4,493 |          3,797 / 1,628 |
| QEMU   | 9p            |            9,037 |             4,972 |          3,923 / 1,682 |
| QEMU   | 9p            |            8,910 |             5,026 |          3,965 / 1,699 |
| VZ     | virtiofs      |            9,645 |             2,265 |          4,207 / 1,805 |
| VZ     | virtiofs      |            7,716 |             4,481 |          3,874 / 1,662 |
| VZ     | virtiofs      |            7,740 |             4,575 |          3,761 / 1,614 |
| VZ     | virtiofs      |            7,747 |             4,542 |          3,806 / 1,633 |
| VZ     | virtiofs      |            7,565 |             4,314 |          3,681 / 1,579 |


### QEMU reverse-sshfs

<details>
<summary>Random Read</summary>

```
# fio /work/test.fio --section=random-read
random-read: (g=0): rw=randread, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=1
...
fio-3.25
Starting 2 threads
Jobs: 2 (f=2): [r(2)][100.0%][r=6058KiB/s][r=1514 IOPS][eta 00m:00s]
random-read: (groupid=0, jobs=2): err= 0: pid=3036: Fri Dec 30 10:58:22 2022
  read: IOPS=1495, BW=5982KiB/s (6126kB/s)(351MiB/60002msec)
    slat (usec): min=9, max=1322, avg=50.91, stdev=41.56
    clat (usec): min=79, max=9807, avg=1222.00, stdev=225.85
     lat (usec): min=683, max=9884, avg=1287.87, stdev=235.52
    clat percentiles (usec):
     |  1.00th=[  824],  5.00th=[  898], 10.00th=[  963], 20.00th=[ 1057],
     | 30.00th=[ 1106], 40.00th=[ 1156], 50.00th=[ 1188], 60.00th=[ 1237],
     | 70.00th=[ 1303], 80.00th=[ 1385], 90.00th=[ 1500], 95.00th=[ 1614],
     | 99.00th=[ 1893], 99.50th=[ 2008], 99.90th=[ 2343], 99.95th=[ 2442],
     | 99.99th=[ 3654]
   bw (  KiB/s): min= 5420, max= 6417, per=100.00%, avg=5987.08, stdev=93.17, samples=238
   iops        : min= 1354, max= 1604, avg=1496.26, stdev=23.36, samples=238
  lat (usec)   : 100=0.01%, 500=0.01%, 750=0.11%, 1000=13.10%
  lat (msec)   : 2=86.26%, 4=0.52%, 10=0.01%
  cpu          : usr=0.22%, sys=11.38%, ctx=90655, majf=0, minf=4
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=89735,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
   READ: bw=5982KiB/s (6126kB/s), 5982KiB/s-5982KiB/s (6126kB/s-6126kB/s), io=351MiB (368MB), run=60002-60002msec
```

</details>


<details>
<summary>Random Write</summary>

```
# fio /work/test.fio --section=random-write
random-write: (g=0): rw=randwrite, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=1
...
fio-3.25
Starting 2 threads
random-write: Laying out IO file (1 file / 3938MiB)
Jobs: 2 (f=2): [f(2)][100.0%][eta 00m:00s]
random-write: (groupid=0, jobs=2): err= 0: pid=3045: Fri Dec 30 11:00:06 2022
  write: IOPS=2755, BW=10.8MiB/s (11.3MB/s)(647MiB/60059msec); 0 zone resets
    slat (usec): min=9, max=5484, avg=157.21, stdev=164.50
    clat (usec): min=9, max=1689.0k, avg=480.19, stdev=11320.34
     lat (usec): min=34, max=1689.2k, avg=658.14, stdev=11319.37
    clat percentiles (usec):
     |  1.00th=[    10],  5.00th=[    11], 10.00th=[    11], 20.00th=[    11],
     | 30.00th=[    11], 40.00th=[    12], 50.00th=[    13], 60.00th=[    18],
     | 70.00th=[    26], 80.00th=[   149], 90.00th=[   494], 95.00th=[   668],
     | 99.00th=[  1004], 99.50th=[  1303], 99.90th=[185598], 99.95th=[198181],
     | 99.99th=[219153]
   bw (  KiB/s): min=   70, max=24816, per=100.00%, avg=11491.88, stdev=5356.66, samples=230
   iops        : min=   16, max= 6204, avg=2872.40, stdev=1339.28, samples=230
  lat (usec)   : 10=1.46%, 20=64.61%, 50=11.52%, 100=1.24%, 250=3.77%
  lat (usec)   : 500=7.60%, 750=6.62%, 1000=2.17%
  lat (msec)   : 2=0.74%, 4=0.09%, 10=0.02%, 100=0.01%, 250=0.16%
  lat (msec)   : 500=0.01%, 750=0.01%, 2000=0.01%
  cpu          : usr=0.25%, sys=18.02%, ctx=197836, majf=0, minf=2
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=0,165512,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
  WRITE: bw=10.8MiB/s (11.3MB/s), 10.8MiB/s-10.8MiB/s (11.3MB/s-11.3MB/s), io=647MiB (678MB), run=60059-60059msec
```

</details>


<details>
<summary>Random Read/Write</summary>

```
# fio /work/test.fio --section=random-readwrite
random-readwrite: (g=0): rw=randrw, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=1
...
fio-3.25
Starting 2 threads
Jobs: 2 (f=2): [m(2)][100.0%][r=4180KiB/s,w=1889KiB/s][r=1045,w=472 IOPS][eta 00m:00s]
random-readwrite: (groupid=0, jobs=2): err= 0: pid=3026: Fri Dec 30 10:54:45 2022
  read: IOPS=1037, BW=4150KiB/s (4249kB/s)(243MiB/60002msec)
    slat (usec): min=9, max=16301, avg=424.26, stdev=590.42
    clat (usec): min=23, max=14736, avg=1301.33, stdev=288.54
     lat (usec): min=728, max=18995, avg=1740.40, stdev=662.20
    clat percentiles (usec):
     |  1.00th=[  840],  5.00th=[  947], 10.00th=[ 1012], 20.00th=[ 1090],
     | 30.00th=[ 1156], 40.00th=[ 1205], 50.00th=[ 1254], 60.00th=[ 1319],
     | 70.00th=[ 1401], 80.00th=[ 1483], 90.00th=[ 1631], 95.00th=[ 1778],
     | 99.00th=[ 2147], 99.50th=[ 2343], 99.90th=[ 2966], 99.95th=[ 3490],
     | 99.99th=[ 6521]
   bw (  KiB/s): min= 3776, max= 4499, per=100.00%, avg=4152.97, stdev=65.06, samples=238
   iops        : min=  944, max= 1124, avg=1037.43, stdev=16.19, samples=238
  write: IOPS=443, BW=1775KiB/s (1818kB/s)(104MiB/60002msec); 0 zone resets
    slat (usec): min=9, max=7192, avg=76.19, stdev=98.69
    clat (usec): min=10, max=5483, avg=142.69, stdev=167.88
     lat (usec): min=37, max=7217, avg=236.52, stdev=184.30
    clat percentiles (usec):
     |  1.00th=[   12],  5.00th=[   13], 10.00th=[   13], 20.00th=[   33],
     | 30.00th=[   41], 40.00th=[   68], 50.00th=[  105], 60.00th=[  133],
     | 70.00th=[  161], 80.00th=[  200], 90.00th=[  310], 95.00th=[  461],
     | 99.00th=[  824], 99.50th=[  979], 99.90th=[ 1336], 99.95th=[ 1483],
     | 99.99th=[ 2376]
   bw (  KiB/s): min= 1412, max= 2258, per=100.00%, avg=1776.47, stdev=81.07, samples=238
   iops        : min=  352, max=  564, avg=443.55, stdev=20.30, samples=238
  lat (usec)   : 20=4.74%, 50=5.62%, 100=4.13%, 250=11.00%, 500=3.19%
  lat (usec)   : 750=0.97%, 1000=6.62%
  lat (msec)   : 2=62.46%, 4=1.24%, 10=0.02%, 20=0.01%
  cpu          : usr=0.15%, sys=15.19%, ctx=105253, majf=0, minf=2
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=62246,26629,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
   READ: bw=4150KiB/s (4249kB/s), 4150KiB/s-4150KiB/s (4249kB/s-4249kB/s), io=243MiB (255MB), run=60002-60002msec
  WRITE: bw=1775KiB/s (1818kB/s), 1775KiB/s-1775KiB/s (1818kB/s-1818kB/s), io=104MiB (109MB), run=60002-60002msec
```

</details>

### QEMU 9p

<details>
<summary>Random Read</summary>

```
# fio /work/test.fio --section=random-read
random-read: (g=0): rw=randread, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=1
...
fio-3.25
Starting 2 threads
Jobs: 2 (f=2): [r(2)][100.0%][r=23.9MiB/s][r=6130 IOPS][eta 00m:00s]
random-read: (groupid=0, jobs=2): err= 0: pid=3106: Fri Dec 30 13:48:01 2022
  read: IOPS=8910, BW=34.8MiB/s (36.5MB/s)(2088MiB/60001msec)
    slat (usec): min=56, max=5699, avg=220.50, stdev=115.35
    clat (nsec): min=1191, max=629060, avg=2086.80, stdev=3940.19
     lat (usec): min=58, max=5701, avg=223.01, stdev=115.55
    clat percentiles (nsec):
     |  1.00th=[  1416],  5.00th=[  1688], 10.00th=[  1720], 20.00th=[  1752],
     | 30.00th=[  1784], 40.00th=[  1832], 50.00th=[  1880], 60.00th=[  1912],
     | 70.00th=[  1944], 80.00th=[  1976], 90.00th=[  2008], 95.00th=[  2064],
     | 99.00th=[  2320], 99.50th=[  5024], 99.90th=[ 66048], 99.95th=[ 70144],
     | 99.99th=[117248]
   bw (  KiB/s): min=21208, max=60848, per=100.00%, avg=35763.03, stdev=8202.08, samples=238
   iops        : min= 5302, max=15212, avg=8940.66, stdev=2050.51, samples=238
  lat (usec)   : 2=87.13%, 4=12.34%, 10=0.07%, 20=0.12%, 50=0.05%
  lat (usec)   : 100=0.27%, 250=0.02%, 500=0.01%, 750=0.01%
  cpu          : usr=2.83%, sys=15.14%, ctx=531748, majf=0, minf=4
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=534646,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
   READ: bw=34.8MiB/s (36.5MB/s), 34.8MiB/s-34.8MiB/s (36.5MB/s-36.5MB/s), io=2088MiB (2190MB), run=60001-60001msec
```

</details>


<details>
<summary>Random Write</summary>

```
# fio /work/test.fio --section=random-write
random-write: (g=0): rw=randwrite, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=1
...
fio-3.25
Starting 2 threads
Jobs: 1 (f=1): [_(1),f(1)][100.0%][eta 00m:00s]
random-write: (groupid=0, jobs=2): err= 0: pid=3115: Fri Dec 30 13:49:03 2022
  write: IOPS=5026, BW=19.6MiB/s (20.6MB/s)(1178MiB/60013msec); 0 zone resets
    slat (usec): min=55, max=101622, avg=393.87, stdev=2114.52
    clat (nsec): min=1245, max=306020, avg=2095.78, stdev=3597.79
     lat (usec): min=57, max=101626, avg=396.38, stdev=2114.64
    clat percentiles (nsec):
     |  1.00th=[  1624],  5.00th=[  1672], 10.00th=[  1704], 20.00th=[  1736],
     | 30.00th=[  1768], 40.00th=[  1800], 50.00th=[  1848], 60.00th=[  1912],
     | 70.00th=[  1944], 80.00th=[  1976], 90.00th=[  2040], 95.00th=[  2128],
     | 99.00th=[  3056], 99.50th=[ 11840], 99.90th=[ 63744], 99.95th=[ 70144],
     | 99.99th=[110080]
   bw (  KiB/s): min=10618, max=56916, per=100.00%, avg=20183.88, stdev=5565.14, samples=238
   iops        : min= 2653, max=14229, avg=5045.76, stdev=1391.31, samples=238
  lat (usec)   : 2=83.48%, 4=15.73%, 10=0.21%, 20=0.21%, 50=0.13%
  lat (usec)   : 100=0.23%, 250=0.01%, 500=0.01%
  cpu          : usr=2.94%, sys=7.08%, ctx=300439, majf=0, minf=2
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=0,301634,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
  WRITE: bw=19.6MiB/s (20.6MB/s), 19.6MiB/s-19.6MiB/s (20.6MB/s-20.6MB/s), io=1178MiB (1235MB), run=60013-60013msec
```

</details>


<details>
<summary>Random Read/Write</summary>

```
# fio /work/test.fio --section=random-readwrite
random-readwrite: (g=0): rw=randrw, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=1
...
fio-3.25
Starting 2 threads
Jobs: 1 (f=1): [f(1),_(1)][100.0%][r=2201KiB/s,w=859KiB/s][r=550,w=214 IOPS][eta 00m:00s]
random-readwrite: (groupid=0, jobs=2): err= 0: pid=3124: Fri Dec 30 13:50:05 2022
  read: IOPS=3965, BW=15.5MiB/s (16.2MB/s)(929MiB/60001msec)
    slat (usec): min=158, max=4769, avg=332.10, stdev=71.38
    clat (nsec): min=1235, max=513370, avg=2157.14, stdev=4381.52
     lat (usec): min=160, max=4777, avg=334.68, stdev=71.56
    clat percentiles (nsec):
     |  1.00th=[  1592],  5.00th=[  1672], 10.00th=[  1704], 20.00th=[  1736],
     | 30.00th=[  1784], 40.00th=[  1832], 50.00th=[  1880], 60.00th=[  1912],
     | 70.00th=[  1944], 80.00th=[  1976], 90.00th=[  2024], 95.00th=[  2064],
     | 99.00th=[  3024], 99.50th=[ 15936], 99.90th=[ 68096], 99.95th=[ 74240],
     | 99.99th=[130560]
   bw (  KiB/s): min= 8040, max=21888, per=99.97%, avg=15858.13, stdev=2840.22, samples=238
   iops        : min= 2010, max= 5472, avg=3964.50, stdev=710.07, samples=238
  write: IOPS=1699, BW=6799KiB/s (6962kB/s)(398MiB/60001msec); 0 zone resets
    slat (usec): min=56, max=101177, avg=388.06, stdev=3492.74
    clat (nsec): min=1198, max=250992, avg=2091.27, stdev=3656.07
     lat (usec): min=58, max=101180, avg=390.57, stdev=3492.80
    clat percentiles (nsec):
     |  1.00th=[  1624],  5.00th=[  1672], 10.00th=[  1704], 20.00th=[  1736],
     | 30.00th=[  1768], 40.00th=[  1800], 50.00th=[  1848], 60.00th=[  1896],
     | 70.00th=[  1944], 80.00th=[  1976], 90.00th=[  2024], 95.00th=[  2064],
     | 99.00th=[  2704], 99.50th=[ 11968], 99.90th=[ 64768], 99.95th=[ 71168],
     | 99.99th=[102912]
   bw (  KiB/s): min= 3232, max= 9992, per=99.97%, avg=6797.47, stdev=1229.80, samples=238
   iops        : min=  808, max= 2498, avg=1699.33, stdev=307.47, samples=238
  lat (usec)   : 2=86.51%, 4=12.68%, 10=0.14%, 20=0.27%, 50=0.07%
  lat (usec)   : 100=0.30%, 250=0.02%, 500=0.01%, 750=0.01%
  cpu          : usr=2.60%, sys=8.55%, ctx=339403, majf=0, minf=2
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=237950,101989,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
   READ: bw=15.5MiB/s (16.2MB/s), 15.5MiB/s-15.5MiB/s (16.2MB/s-16.2MB/s), io=929MiB (975MB), run=60001-60001msec
  WRITE: bw=6799KiB/s (6962kB/s), 6799KiB/s-6799KiB/s (6962kB/s-6962kB/s), io=398MiB (418MB), run=60001-60001msec
```

</details>


### VZ virtiofs

<details>
<summary>Random Read</summary>

```
# fio /work/test.fio --section=random-read
random-read: (g=0): rw=randread, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=1
...
fio-3.25
Starting 2 threads
Jobs: 2 (f=2): [r(2)][100.0%][r=30.4MiB/s][r=7775 IOPS][eta 00m:00s]
random-read: (groupid=0, jobs=2): err= 0: pid=3092: Fri Dec 30 12:38:17 2022
  read: IOPS=7747, BW=30.3MiB/s (31.7MB/s)(1816MiB/60001msec)
    slat (usec): min=101, max=3597, avg=254.73, stdev=38.78
    clat (nsec): min=1089, max=497831, avg=1781.28, stdev=1412.89
     lat (usec): min=103, max=3600, avg=256.94, stdev=38.99
    clat percentiles (nsec):
     |  1.00th=[ 1560],  5.00th=[ 1624], 10.00th=[ 1640], 20.00th=[ 1656],
     | 30.00th=[ 1672], 40.00th=[ 1688], 50.00th=[ 1704], 60.00th=[ 1736],
     | 70.00th=[ 1752], 80.00th=[ 1768], 90.00th=[ 1816], 95.00th=[ 1896],
     | 99.00th=[ 2128], 99.50th=[ 2704], 99.90th=[18816], 99.95th=[20864],
     | 99.99th=[50944]
   bw (  KiB/s): min=28656, max=31552, per=100.00%, avg=31024.42, stdev=178.01, samples=238
   iops        : min= 7164, max= 7888, avg=7756.10, stdev=44.50, samples=238
  lat (usec)   : 2=97.98%, 4=1.65%, 10=0.09%, 20=0.22%, 50=0.05%
  lat (usec)   : 100=0.01%, 250=0.01%, 500=0.01%
  cpu          : usr=1.62%, sys=6.58%, ctx=464919, majf=0, minf=4
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=464862,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
   READ: bw=30.3MiB/s (31.7MB/s), 30.3MiB/s-30.3MiB/s (31.7MB/s-31.7MB/s), io=1816MiB (1904MB), run=60001-60001msec
```

</details>


<details>
<summary>Random Write</summary>

```
# fio /work/test.fio --section=random-write
random-write: (g=0): rw=randwrite, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=1
...
fio-3.25
Starting 2 threads
Jobs: 2 (f=2): [w(2)][100.0%][w=15.9MiB/s][w=4081 IOPS][eta 00m:00s]
random-write: (groupid=0, jobs=2): err= 0: pid=3103: Fri Dec 30 12:39:18 2022
  write: IOPS=4542, BW=17.7MiB/s (18.6MB/s)(1065MiB/60001msec); 0 zone resets
    slat (usec): min=69, max=6989, avg=436.66, stdev=286.46
    clat (nsec): min=1060, max=3964.7k, avg=1924.20, stdev=7809.67
     lat (usec): min=70, max=6992, avg=439.02, stdev=286.79
    clat percentiles (nsec):
     |  1.00th=[ 1320],  5.00th=[ 1368], 10.00th=[ 1416], 20.00th=[ 1656],
     | 30.00th=[ 1720], 40.00th=[ 1752], 50.00th=[ 1768], 60.00th=[ 1800],
     | 70.00th=[ 1832], 80.00th=[ 1864], 90.00th=[ 1992], 95.00th=[ 2224],
     | 99.00th=[ 3792], 99.50th=[15808], 99.90th=[24448], 99.95th=[30848],
     | 99.99th=[61184]
   bw (  KiB/s): min= 6784, max=42992, per=100.00%, avg=18205.65, stdev=3022.13, samples=238
   iops        : min= 1696, max=10748, avg=4551.29, stdev=755.54, samples=238
  lat (usec)   : 2=90.37%, 4=8.69%, 10=0.31%, 20=0.31%, 50=0.30%
  lat (usec)   : 100=0.02%, 250=0.01%
  lat (msec)   : 4=0.01%
  cpu          : usr=1.07%, sys=9.36%, ctx=545082, majf=0, minf=2
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=0,272529,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
  WRITE: bw=17.7MiB/s (18.6MB/s), 17.7MiB/s-17.7MiB/s (18.6MB/s-18.6MB/s), io=1065MiB (1116MB), run=60001-60001msec
```

</details>


<details>
<summary>Random Read/Write</summary>

```
# fio /work/test.fio --section=random-readwrite
random-readwrite: (g=0): rw=randrw, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=1
...
fio-3.25
Starting 2 threads
Jobs: 2 (f=2): [m(2)][100.0%][r=15.1MiB/s,w=6514KiB/s][r=3861,w=1628 IOPS][eta 00m:00s]
random-readwrite: (groupid=0, jobs=2): err= 0: pid=3114: Fri Dec 30 12:40:19 2022
  read: IOPS=3806, BW=14.9MiB/s (15.6MB/s)(892MiB/60001msec)
    slat (usec): min=36, max=14375, avg=342.60, stdev=179.88
    clat (nsec): min=1164, max=470611, avg=1933.66, stdev=1710.59
     lat (usec): min=38, max=14385, avg=345.00, stdev=180.00
    clat percentiles (nsec):
     |  1.00th=[ 1352],  5.00th=[ 1624], 10.00th=[ 1672], 20.00th=[ 1704],
     | 30.00th=[ 1736], 40.00th=[ 1752], 50.00th=[ 1784], 60.00th=[ 1816],
     | 70.00th=[ 1848], 80.00th=[ 1960], 90.00th=[ 2160], 95.00th=[ 2384],
     | 99.00th=[ 3120], 99.50th=[ 7200], 99.90th=[19840], 99.95th=[23680],
     | 99.99th=[51456]
   bw (  KiB/s): min= 8824, max=19064, per=100.00%, avg=15242.83, stdev=974.69, samples=238
   iops        : min= 2206, max= 4766, avg=3810.69, stdev=243.67, samples=238
  write: IOPS=1633, BW=6536KiB/s (6693kB/s)(383MiB/60001msec); 0 zone resets
    slat (usec): min=88, max=15049, avg=413.38, stdev=269.66
    clat (nsec): min=1041, max=93483, avg=1961.65, stdev=1520.59
     lat (usec): min=90, max=15058, avg=415.81, stdev=269.77
    clat percentiles (nsec):
     |  1.00th=[ 1320],  5.00th=[ 1400], 10.00th=[ 1576], 20.00th=[ 1736],
     | 30.00th=[ 1768], 40.00th=[ 1800], 50.00th=[ 1816], 60.00th=[ 1848],
     | 70.00th=[ 1896], 80.00th=[ 1976], 90.00th=[ 2160], 95.00th=[ 2416],
     | 99.00th=[ 3312], 99.50th=[14912], 99.90th=[20096], 99.95th=[25984],
     | 99.99th=[55552]
   bw (  KiB/s): min= 3736, max= 8208, per=100.00%, avg=6543.24, stdev=424.83, samples=238
   iops        : min=  934, max= 2052, avg=1635.80, stdev=106.21, samples=238
  lat (usec)   : 2=83.10%, 4=16.19%, 10=0.28%, 20=0.35%, 50=0.08%
  lat (usec)   : 100=0.01%, 250=0.01%, 500=0.01%
  cpu          : usr=1.34%, sys=6.75%, ctx=424596, majf=0, minf=2
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=228416,98040,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
   READ: bw=14.9MiB/s (15.6MB/s), 14.9MiB/s-14.9MiB/s (15.6MB/s-15.6MB/s), io=892MiB (936MB), run=60001-60001msec
  WRITE: bw=6536KiB/s (6693kB/s), 6536KiB/s-6536KiB/s (6693kB/s-6693kB/s), io=383MiB (402MB), run=60001-60001msec
```

</details>


## tarball 展開にかかる時間の比較

IOPS だけではちょっと実際の利用での差が分かりづらいのでそこそこのファイル含む tarball を展開するのにかかる時間を計測してみる。

[linux-6.1.1.tar.xz](https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.1.1.tar.xz) を xz だけ展開した tar ファイルを展開する時間を計測してみる。
と思ったけど virtiofs 以外では時間がかかりすぎるので git の [v2.39.0.tar.gz](https://github.com/git/git/archive/refs/tags/v2.39.0.tar.gz) を使うことにした。gunzip 済みの tar ファイルを展開する時間を計測。(git の v2.39.0.tar はディレクトリを 213 個、ファイルを 4294 個含む 43MB のファイル)

ssh と 9p では owner の変更でたくさんエラー (`Cannot change ownership to uid 0, gid 0: Permission denied`) が出るので `time tar -x --no-same-owner -f ../v2.39.0.tar` と実行して計測。各環境で3回実行。

vz の virtiofs が圧倒的に速いですね。そして 9p は sshfs より速いとは言えない感じですね。vz が使えない環境では sshfs のままで良いのかな。

| vmType | mountType     | time      |
|--------|---------------|----------:|
| QEMU   | reverse-sshfs | 0m15.758s |
| QEMU   | reverse-sshfs | 0m15.996s |
| QEMU   | reverse-sshfs | 0m15.586s |
| QEMU   | 9p            | 0m34.567s |
| QEMU   | 9p            | 0m29.186s |
| QEMU   | 9p            | 0m32.770s |
| VZ     | virtiofs      |  0m6.130s |
| VZ     | virtiofs      |  0m5.259s |
| VZ     | virtiofs      |  0m5.370s |

ちなみに macOS 上で直接同じコマンドで展開したところ約2秒でした。
