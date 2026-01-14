---
title: Windows 11 Home で WSL の VHD の縮小
date: 2024-05-06T23:10:44+09:00
draft: false
tags: [Windows, WSL]
---

ときどき実行するのでメモ

WSL のディスクは 1TiB で thin provisioning された vhdx が使われているようです。
実際には 1TiB が割り当てられているわけではなく実際に必要になった段階で Windows 上の仮想ディスクファイルが大きくなります。
普通に使っているといったん大きくなると WSL 内のファイルを削除しても仮想ディスクのサイズは小さくならないので、無駄に大きくなりすぎてしまった場合には WSL のディストリビューションを再作成するか仮想ディスクの使われていない領域を解放して小さくする必要があります。

本当は再作成して、必要なセットアップをさくっと終わらせるスクリプトを用意すれば良いのですが、面倒でやっていない。

Windows の Professional Edition であれば Optimize-VHD というコマンドで小さくできるらしいけど Home Edition には存在せず、diskpart コマンドを使う。

https://qiita.com/siruku6/items/c91a40d460095013540d

diskpart コマンドを実行する前に WSL 内で `fstrim -av` を実行しておかないと小さくならなかった。

知らず知らずのうちに非常に大きくなっているのが docker 関連。image の pull や build で溜まっていく。

```bash
docker system df
```

