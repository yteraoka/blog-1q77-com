---
title: 'send-ssh-public-key と ssm start-session の合わせ技'
date: Mon, 23 Nov 2020 11:35:01 +0000
draft: false
tags: ['AWS', 'aws']
---

以前、「[SSM Session Manager 経由での SSH](/2020/04/ssh-connection-through-session-manager/)」で、Public IP address を持たない EC2 Instance に対して SSH 接続する方法を確認したが、SSM の Session Manager だけでは事前に EC2 Instance 側に Public Key が登録されている必要があった。

しかし、今回 Public Key の登録されていない Instance に SSH したくなった。確か、一時的な Public Key を登録する機能があったよな、ということでメモっておく。

一時的な Public Key を送った後に Session Manger を使って接続すれば今回やりたいことができる。

Public Key の登録は `aws ec2-instance-connect send-ssh-public-key` コマンドで行う。

```
aws ec2-instance-connect send-ssh-public-key \\
  --instance-id i-xxxxxxxxxxxxxxxxx \\
  --instance-os-user ec2-user \\
  --availability-zone ap-northeast-1c \\
  --ssh-public-key file://$HOME/.ssh/id\_rsa.pub

```

わざわざ `--availability-zone` を指定しなくてはならないというのが面倒だが Instance Id から取ってくる wrapper を書く。

```
aws ec2 describe-instances \\
  --instance-ids i-xxxxxxxxxxxxxxxxx \\
  --query 'Reservations\[0\].Instances\[0\].Placement.AvailabilityZone' \\
  --output text

```

`send-ssh-public-key` で登録した Public Key は 60 秒間だけ有効なのでその間に SSM の Session Manager で接続します。これは「[SSM Session Manager 経由での SSH](/2020/04/ssh-connection-through-session-manager/)」で書いた通りで `~/.ssh/config` に次の様に書いておけば `ssh ec2-user@i-xxxxxxxxxxxxxxxxx` で接続できます。

```
host i-\* mi-\*
  ProxyCommand sh -c "aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"

```

とりあえずこんな wrapper で

```
#!/bin/bash

instance\_id=$1
user=ec2-user

if \[ -z "$instance\_id" \] ; then
  echo "Usage: ssmssh \[username@\]instance\_id" 1>&2
  exit 1
fi

echo $instance\_id | grep -q @
if \[ $? -eq 0 \] ; then
  user=$(echo $instance\_id | cut -d @ -f 1)
  instance\_id=$(echo $instance\_id | cut -d @ -f 2)
fi

echo $instance\_id | grep -q ^i-
if \[ $? -ne 0 \] ; then
  echo "invalid instance id: $instance\_id" 1>&2
  exit 2
fi

echo "Getting availability zone of instance" 1>&2
az=$(aws ec2 describe-instances \\
  --instance-ids $instance\_id \\
  --query 'Reservations\[0\].Instances\[0\].Placement.AvailabilityZone' \\
  --output text
)

echo "Sending ssh public key" 1>&2
aws ec2-instance-connect send-ssh-public-key \\
  --instance-id $instance\_id \\
  --instance-os-user $user \\
  --availability-zone $az \\
  --ssh-public-key file://$HOME/.ssh/id\_rsa.pub

echo "exec ssh $user@$instance\_id" 1>&2
exec ssh $user@$instance\_id

```