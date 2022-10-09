---
title: 'コンテナ内での Java の CPU Cores'
date: Tue, 01 Dec 2020 16:23:38 +0000
draft: false
tags: ['Java', 'advent calendar 2020', 'java']
---

[Advent Calendar 2020 全部オレシリーズ](https://qiita.com/advent-calendar/2020/yteraoka) 2日目です。書きかけで放置されていたやつを掘り起こしました💦

コンテナ内での Java のメモリの扱いについては 「[JVMのヒープサイズとコンテナ時代のチューニング - Folioscope](https://i-beam.org/2019/08/15/jvm-heap-sizing/)」 に詳しく説明されています。ありがたい。

それでは Kubernetes で実行するコンテナ内での CPU のコア数はどのように見えるでしょうか？

`resources.limits.cpu` の値によります。指定がなければホストの CPU のコア数となり、指定した場合は 1 までなら 1 だし、1 より大きく 2 以下であれば 2 になるといった具合。

ところで、Java はこの CPU のコア数を元に計算した値がデフォルト値になったりするものがあります。物理サーバーや仮想サーバーからコンテナにして CPU Limit を小さく絞ったら期待の動作じゃなくなったりするかもしれません。CPU 沢山使うわけじゃないけどコア数から計算される値をとりあえず上げたい、とかデフォルトの GC が変わってしまったとかいう場合、本来はそれぞれを適切に指定するべきですが、見せかけの CPU コア数を増やす方法はないでしょうか？

`-XX:ActiveProcessorCount=N` で指定可能なようです。

試してみます。CPU コアを 4 個割り当てた minikube 環境です。

CPU Limit を 100m にした OpenJDK Pod を作成します。(100m は小さすぎてスロットリングがひどい...)

```
kubectl run java --image openjdk:16-slim -it --rm --limits=cpu=100m --command -- bash

```

lscpu では CPU は 4 つに見えますね。

```
root@java:/# **lscpu**
Architecture:        x86\_64
CPU op-mode(s):      32-bit, 64-bit
Byte Order:          Little Endian
Address sizes:       39 bits physical, 48 bits virtual
CPU(s):              4
On-line CPU(s) list: 0-3
Thread(s) per core:  1
Core(s) per socket:  1
Socket(s):           4
NUMA node(s):        1
Vendor ID:           GenuineIntel
CPU family:          6
Model:               158
Model name:          Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz
Stepping:            10
CPU MHz:             2600.000
BogoMIPS:            5184.00
L1d cache:           32K
L1i cache:           32K
L2 cache:            256K
L3 cache:            12288K
NUMA node0 CPU(s):   0-3
Flags:               fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr sse sse2 ss ht pbe syscall nx pdpe1gb lm constant\_tsc rep\_good nopl xtopology nonstop\_tsc cpuid tsc\_known\_freq pni pclmulqdq dtes64 ds\_cpl ssse3 sdbg fma cx16 xtpr pcid sse4\_1 sse4\_2 movbe popcnt aes xsave avx f16c rdrand hypervisor lahf\_lm abm 3dnowprefetch pti fsgsbase bmi1 avx2 bmi2 erms xsaveopt arat

```

Jshell で Java プロセスから CPU の数がいくつに見えるか確認してみます。

```
root@java:/# **jshell --execution local**
Dec 01, 2020 3:41:53 PM java.util.prefs.FileSystemPreferences$1 run
INFO: Created user preferences directory.
|  Welcome to JShell -- Version 16-ea
|  For an introduction type: /help intro

jshell> **Runtime.getRuntime().availableProcessors()**
$1 ==> 1

```

1 ですね。

次に `-J-XX:ActiveProcessorCount=2` をつけて試します。

```
root@java:/# **jshell --execution local -J-XX:ActiveProcessorCount=2**
|  Welcome to JShell -- Version 16-ea
|  For an introduction type: /help intro

jshell> **Runtime.getRuntime().availableProcessors()**
$1 ==> 2

```

2 になりました。

ホストが持っている以上の値を指定するとどうなるでしょう？

```
root@java:/# **jshell --execution local -J-XX:ActiveProcessorCount=8**
|  Welcome to JShell -- Version 16-ea
|  For an introduction type: /help intro

jshell> **Runtime.getRuntime().availableProcessors()**
$1 ==> 8

```

4 コアのホストですが 8 個になってますね。

Pod の CPU Limit を 3 にした環境でも試してみます。

```
kubectl run java --image openjdk:16-slim -it --rm --limits=cpu=3 --command -- bash

``````
root@java:/# **jshell --execution local**
Dec 01, 2020 3:58:52 PM java.util.prefs.FileSystemPreferences$1 run
INFO: Created user preferences directory.
|  Welcome to JShell -- Version 16-ea
|  For an introduction type: /help intro

jshell> **Runtime.getRuntime().availableProcessors()**
$1 ==> 3

```

`-J-XX:ActiveProcessorCount` 未指定で 3 ですね。

デフォルトの GC も変わります。 CPU が 1 個の時は SerialGC

```
root@java:/# **java -XX:+PrintCommandLineFlags -version**
-XX:InitialHeapSize=97560512 -XX:MaxHeapSize=1560968192 -XX:MinHeapSize=6815736 -XX:+PrintCommandLineFlags -XX:ReservedCodeCacheSize=251658240 -XX:+SegmentedCodeCache -XX:+UseCompressedClassPointers -XX:+UseCompressedOops -XX:+UseSerialGC 
openjdk version "16-ea" 2021-03-16
OpenJDK Runtime Environment (build 16-ea+25-1633)
OpenJDK 64-Bit Server VM (build 16-ea+25-1633, mixed mode, sharing)

```

2 個以上で G1GC になります。GC の Thread も増えるので、見せかけの CPU の数を増やすのは得策ではなさそうです、どうしても大きくしたい場合は GC 関連 Thread の数を直接指定するのかな。

```
root@java:/# **java -XX:+PrintCommandLineFlags -XX:ActiveProcessorCount=2 -version**
-XX:ActiveProcessorCount=2 -XX:ConcGCThreads=1 -XX:G1ConcRefinementThreads=2 -XX:GCDrainStackTargetSize=64 -XX:InitialHeapSize=97560512 -XX:MarkStackSize=4194304 -XX:MaxHeapSize=1560968192 -XX:MinHeapSize=6815736 -XX:+PrintCommandLineFlags -XX:ReservedCodeCacheSize=251658240 -XX:+SegmentedCodeCache -XX:+UseCompressedClassPointers -XX:+UseCompressedOops -XX:+UseG1GC 
openjdk version "16-ea" 2021-03-16
OpenJDK Runtime Environment (build 16-ea+25-1633)
OpenJDK 64-Bit Server VM (build 16-ea+25-1633, mixed mode, sharing)

``````
root@java:/# **java -XX:+PrintCommandLineFlags -XX:ActiveProcessorCount=8 -version** 
-XX:ActiveProcessorCount=8 -XX:ConcGCThreads=2 -XX:G1ConcRefinementThreads=8 -XX:GCDrainStackTargetSize=64 -XX:InitialHeapSize=97560512 -XX:MarkStackSize=4194304 -XX:MaxHeapSize=1560968192 -XX:MinHeapSize=6815736 -XX:+PrintCommandLineFlags -XX:ReservedCodeCacheSize=251658240 -XX:+SegmentedCodeCache -XX:+UseCompressedClassPointers -XX:+UseCompressedOops -XX:+UseG1GC 
openjdk version "16-ea" 2021-03-16
OpenJDK Runtime Environment (build 16-ea+25-1633)
OpenJDK 64-Bit Server VM (build 16-ea+25-1633, mixed mode, sharing)

```

調べはしたけど、使ってないので書きかけで放置されていた記事でした。