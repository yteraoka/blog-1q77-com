---
title: 'kubie 3分 Cooking!'
date: Sun, 26 Apr 2020 05:13:41 +0000
draft: false
tags: ['Kubernetes']
---

kubectl などで複数の Kubernetes クラスタを切り替えるのに [kubectx](https://kubectx.dev) を使っていますが、これでは別ターミナルにしても同時に複数のクラスタにアクセスすることができません。ファイルを分けて環境変数 `KUBECONFIG` を切り替えるようにすれば良いのですが、この shell は今どの環境だっけ？とか考えなければならなくもなります。

そんな面倒を解消してくれるのが [kubie](https://github.com/sbstp/kubie) です。一時ファイルと環境変数を駆使して shell 毎に切り替えられるようになります。prompt への追加もやってくれます。prompt は設定で向こうにもできます。

作者による紹介ブログ記事 "[Introducing Kubie](https://blog.sbstp.ca/introducing-kubie/)" です。

インストールはバイナリをダウンロードして実行権限をつけるだけ。

```
❯ curl -Lo ~/bin/kubie https://github.com/sbstp/kubie/releases/download/v0.8.4/kubie-darwin-amd64
❯ chmod +x ~/bin/kubie
```

```
❯ kubie
kubie 0.8.4

USAGE:
    kubie FLAGS:
    -h, --help       Prints help information
    -V, --version    Prints version information

SUBCOMMANDS:
    ctx            Spawn a shell in the given context. The shell is isolated from other shells. Kubie shells can be
                   spawned recursively without any issue
    edit           Edit the given context
    edit-config    Edit kubie's config file
    exec           Execute a command inside of the given context and namespace
    help           Prints this message or the help of the given subcommand(s)
    info           View info about the current kubie shell, such as the context name and the current namespace
    lint           Check the Kubernetes config files for issues
    ns             Change the namespace in which the current shell operates. The namespace change does not affect
                   other shells
    update         Check for a Kubie update and replace Kubie's binary if needed. This function can ask for sudo-
                   mode 
```

minikube を指定してみます。私の元のプロンプト表示のせいでちょっと分かりづらいですが、context と namespace がプロンプトに追加されました。

```
~
❯ kubie ctx minikube

[minikube|default] ~
❯
```

zsh の場合は ~/.kube/kubie.yaml で右側に表示させることもできます。（RPS1 っていう変数があるんですね）

```
prompt:
  zsh_use_rps1: true
```

namespace も指定してみましょう。

```
[minikube|default] ~
❯ kubie ns kube-system

[minikube|kube-system] ~
❯ k get pod
NAME                             READY   STATUS    RESTARTS   AGE
coredns-5d4dd4b4db-47pl4         1/1     Running   1          49d
coredns-5d4dd4b4db-jdgjt         1/1     Running   1          49d
etcd-m01                         1/1     Running   1          49d
kube-apiserver-m01               1/1     Running   1          49d
kube-controller-manager-m01      1/1     Running   36         49d
kube-proxy-t8wmf                 1/1     Running   1          49d
kube-scheduler-m01               1/1     Running   35         49d
storage-provisioner              1/1     Running   3          49d
tiller-deploy-54f7455d59-jmsdw   1/1     Running   9          48d

[minikube|kube-system] ~
❯
```

KUBECONFIG を確認。 minikube だけのファイルが作成されています。

```
[minikube|kube-system] ~
❯ echo $KUBECONFIG
/var/folders/nd/8mk6834s31g8dymd1_9pnqq00000gn/T/kubie-configskP9Dc.yaml

[minikube|kube-system] ~
❯ cat /var/folders/nd/8mk6834s31g8dymd1_9pnqq00000gn/T/kubie-configskP9Dc.yaml
---
clusters:
  - name: minikube
    cluster:
      certificate-authority: /Users/teraoka/.minikube/ca.crt
      server: "https://192.168.64.33:8443"
users:
  - name: minikube
    user:
      client-certificate: /Users/teraoka/.minikube/client.crt
      client-key: /Users/teraoka/.minikube/client.key
contexts:
  - name: minikube
    context:
      cluster: minikube
      namespace: kube-system
      user: minikube
current-context: minikube
kind: Config
apiVersion: v1
```

~/.kube/config にはもっと沢山の設定が入っています。

```
[minikube|kube-system] ~
❯ yq r -j ~/.kube/config | jq -r '.contexts[].name' | wc -l
      10
```

良い感じですね。

しかし、このコマンド、ファイル作って環境変数設定してくれるだけじゃなくてこのプロセスから fork した SHELL の中で作業することになるんですよね。exit とか Ctrl-D で抜けると元の shell に戻ります。作ったファイル消す必要があるからかなとは思うけど。で、この fork の影響なのか zsh では Ctrl-P とか Ctrl-A とか普段の shell 作業で使うショートカット(?)が使えないんです...

が、「[zsh でいつの間にか Ctrl+R とか Ctrl+A とかきかなくなっていた](http://sotarok.hatenablog.com/entry/20080926/1222368908)」という記事を見つけて `~/.zshrc` に `bindkey -e` を追加することで解決しました。。zsh は mac のデフォルトが zsh だったから使ってるだけのにわかユーザーなので知りませんでした。しかし、なぜ .zshrc で指定してないのに通常は使えてるんだろうか？？

prompt じゃなくて status bar に表示できるらしいということで iTerm2 を使おうかと思ってたのに fork しちゃってるからか status bar の情報が更新されないんですよね。。。 iTerm2 使わなくていっか。

最後に twitter で見かけたこれを貼っておきましょう。[kubectl.info](kubectl.info) （私はキューブシーティーエル）
