---
title: 'SSM Session Manager 経由での SSH'
date: Sun, 05 Apr 2020 14:49:01 +0000
draft: false
tags: ['AWS', 'SSH']
---

"[Step 7: (Optional) Enable SSH Connections Through Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started-enable-ssh-connections.html)" にある通りだが、SSH クライアント側に [session-manager-plugin をインストール](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) して、`~/.ssh/config` に次のように設定すれば

```
# SSH over Session Manager
host i-* mi-*
    ProxyCommand sh -c "aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"
```

`ssh ec2-user@i-0897e5bf469826a3c` などとするだけで SSH 接続することができる。サーバー側はクライアント側から直接アクセス可能な IP アドレスを持っている必要がなく、もちろん SecurityGroup で 22/tcp を開けておく必要もない。

ただし、サーバー側に公開鍵 (`~/.ssh/authorized_keys`) の設置が必要。

SSH クライアント側では **session-manager-plugin** が起動して AWS と https (443/tcp) で通信します。ssh コマンドはこの session-manager-plugin と pipe で通信します。

サーバー側では **amazon-ssm-agent** から起動される **ssm-session-worker** が localhost の sshd (22/tcp) に接続しています。

```
USER       PID  COMMAND
root      3456  /usr/sbin/sshd -D
root     20830   \_ sshd: ec2-user [priv]
ec2-user 20862       \_ sshd: ec2-user@pts/1
ec2-user 20863           \_ -bash
ec2-user 20902               \_ ps auxwwf
...
root      4291  /usr/bin/amazon-ssm-agent
root     20821   \_ /usr/bin/ssm-session-worker yteraoka-0b10612850cc08e6e i-04bf9e371e9f6b863
```

関連するプロセスの流れは次のような感じですが、

```
ssh -> session-manager-plugin -> (AWS) -> amazon-ssm-agent -> ssm-session-worker -> sshd
```

接続の方向としては次のようになっていました。

```
ssh -> session-manager-plugin -> (AWS) <- amazon-ssm-agent
                                   ^
                                   |
                            ssm-session-worker -> sshd
```

ここで、amazon-ssm-agent や ssm-session-worker の接続先となっている (AWS) というのが Global IP Address であるため、Private な Subnet にいるインスタンスの場合は NAT Gateway などでインターネットに出られるようになっているか [VPC Endpoint](https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html) や [PrivateLink の設定](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started-privatelink.html) が必要です。

ブラウザから Session Manager でインスタンスに接続する場合は ssm-session-worker が直接 shell を起動させます。

```
USER       PID  COMMAND
root      4291  /usr/bin/amazon-ssm-agent
root     20569   \_ /usr/bin/ssm-session-worker yteraoka-05b675cf4885dd674 i-04bf9e371e9f6b863
ssm-user 20582       \_ sh
ssm-user 20583           \_ ps auxwwf

```

Session Manager 経由の SSH を禁止したい場合は IAM Policy で次のように Deny します。

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor1",
            "Effect": "Deny",
            "Action": "ssm:StartSession",
            "Resource": "arn:aws:ssm:*:*:document/AWS-StartSSHSession"
        }
    ]
}
```

その他のメモ

* [Session Manager を使うための最小の IAM Policy 設定](https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-create-iam-instance-profile.html)
* [Auditing and Logging Session Activity](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-logging-auditing.html) (CloudWatch Logs や S3 にログを送ることができる)
* [SSMのセッションマネージャをTerraformで設定する](https://qiita.com/momin/items/964e62d7658f5d1ac223) ([aws\_ssm\_document](https://www.terraform.io/docs/providers/aws/r/ssm_document.html) で設定するみたい)
