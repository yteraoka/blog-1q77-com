---
title: 'Vagrant メモ (2)'
date: Sat, 23 Mar 2013 16:41:40 +0000
draft: false
tags: ['Vagrant']
---

[Vagrant メモ (1)](/2013/03/vagrant-1/) の続き。

## Vagrant コマンドの概要

### init

実行したディレクトリに Vagrantfile を作成することで初期化します。

```
vagrant init BOX-NAME BOX-URL
```

と box を指定することで同時に `box add` することができます。box を同時についかすれば Vagrantfile もそれに合わせて作成されます。そうでなかった場合は `vagrant add box` した後に Vagrantfile の `config.vm.box` をそれに合わせて書き換える必要があります。Vagrantfile と machine の情報（.vagrant ディレクトリ）は init を実行したディレクトリに作成されますが、box ファイルは ~/.vagrant.d にまとめて保存されます。

### box

box の管理を行います。`add`, `list`, `remove`, `repackage` というサブコマンドがあります。box = machine ではありません、1つの box から複数の machine（サーバー）を構築できます。

```
vagrant box add BOX-NAME BOX-URL
```

で box を追加します。ダウンロード可能な BOX-URL のリストは [Vagrantbox.es](http://www.vagrantbox.es/) にあります。

### up

```
vagrant up [MACHINE-NAME]
```

で指定の machine を起動させます。MACHINE-NAME を省略すると全てのマシンを起動させます。ただし、エラーが発生するとそれ以降のサーバーは起動されません。

### halt

```
vagrant halt [MACHINE-NAME]
```

で指定の machine を shutdown します。MACHINE-NAME を省略すると全てのマシンを shutdown します。

### ssh

```
vagrant ssh [MACHINE-NAME]
```

ssh でマシンにログインします。マルチマシンモードでは MACHINE-NAME が必須です。

### status

マシンの状態（起動してるかどうか）を確認します。

### reload

### reboot

(halt & up) します。(再起動されるけどSSH関連のエラーが出る)

### package

現在のマシンの状態を再利用できるように .box ファイルを作成します。

### suspend

サスペンドします。（メモリの状態を書き出すはずなのに `.vagrant` も `.vagrant.d` も増えないなぁと思ったら、仮想マシンは `~/VirtualBox VMs/` なのでした）
この状態から halt すると state ファイルの削除だけとなります。 マシンを指定しないと全てのマシンを suspend します。

### resume

suspend 状態から復帰させます。マシンを指定しないと全てのマシンを復帰させます。
複数のマシンを稼働させる場合 ssh の port forwarding でポート番号の衝突を自動で回避する仕組みがありますが resume の時に問題があるらしく、別のポートを指定しろと言われます。
それには次のように `:forwarded_port` を設定します。`id: "ssh"` が無いと default の port forward である 2222 -> 22 も残った上で追加で設定されてしまいます。

```ruby
  config.vm.define :node1 do |node|
    node.vm.box = "centos6"
    node.vm.network :forwarded_port, guest: 22, host: 2001, id: "ssh"
  end

  config.vm.define :node2 do |node|
    node.vm.box = "centos6"
    node.vm.network :forwarded_port, guest: 22, host: 2002, id: "ssh"
  end
```

### destroy

仮想マシンを破棄します。Vagrantfile は変更されれないのでまた up すれば box から再作成される。

### ssh-config

```
vagrant ssh-config [MACHINE-NAME]
```

Vagrantfile のあるディレクトリで `vagrant ssh` しなくても ssh 接続できるように `~/.ssh/config` に書くための情報を出力してくれるのでリダイレクトで追記すれば良い。
multi-VM の場合は MACHINE-NAME が必須。

### plugin

未調査

### provision

未調査

## その他

既存の vmdk から box を作成する方法もあるようです。
[Creating a Vagrant base box from an existing Vmdk](http://vertis.github.com/2012/11/02/creating-a-vagrant-base-box-from-an-existing-vmdk.html)
