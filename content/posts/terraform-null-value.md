---
title: 'Terraform の便利な null value'
date: Wed, 02 Dec 2020 16:27:02 +0000
draft: false
tags: ['Terraform', 'advent calendar 2020']
---

[Advent Calendar 2020 全部オレシリーズ](https://qiita.com/advent-calendar/2020/yteraoka) 3日目です。

AWS の新サービス、新機能が続々と発表されて困っちゃいますね。

今回は最近 Terraform を書いていて、`null` という便利な値があるということを今更知ったのでそのメモです。

Terraform のドキュメントは[こちら (Types and Values)](https://www.terraform.io/docs/configuration/expressions.html#types-and-values)

`null` については次のように書かれています。

> Finally, there is one special value that has no type: `null`: a value that represents absence or omission. If you set an argument of a resource or module to `null`, Terraform behaves as though you had completely omitted it — it will use the argument's default value if it has one, or raise an error if the argument is mandatory. `null` is most useful in conditional expressions, so you can dynamically omit an argument if a condition isn't met.

Ansible での [`default(omit)`](https://docs.ansible.com/ansible/latest/user_guide/playbooks_filters.html#making-variables-optional) のようなやつですね。

Terraform の variable 定義で default を null にしておけば、実行時に入力は求められないけど、値としては未定義なので resource で指定していても null のままであれば指定していないことになります。 [#221](https://github.com/terraform-docs/terraform-docs/pull/221)

例えば aws [instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) で次のようなリソース定義があったとして

```tf
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  iam_instance_profile = var.profile_name

  tags = {
    Name = "HelloWorld"
  }
}
```

iam\_instance\_profile は optional なので variable 定義で次のように default を null としておけば、terraform.tfvars などで指定された場合にだけ設定することができます。default を指定しない場合は実行時に入力を求められてしまいます。

```tf
variable "profile_name" {
  default = null
}
```

これだけでも便利ですね。

直近で私が使ったパターンは map に対して lookup で key に対する値を取り出すが、その key が存在しない場合は null とするというものでした。具体的には launch\_template で block\_device\_mapping を指定してもしなくても良い module を書くのに使用しました。

```tf
variable "block_device_mappings" {
  description = "Block Device Mappings for launch template"
  type        = map(map(string))
  default     = {}
}
```

```tf
resource "aws_launch_template" "some_template" {
  name     = var.template_name
  image_id = var.image_id

  ...

  dynamic "block_device_mappings" {
    for_each = var.block_device_mappings
    content {
      device_name = block_device_mappings.key
      ebs {
        encrypted             = tobool(lookup(block_device_mappings.value, "encrypted", "true"))
        volume_size           = tonumber(block_device_mappings.value["volume_size"])
        volume_type           = lookup(block_device_mappings.value, "volume_type", null)
        iops                  = tonumber(lookup(block_device_mappings.value, "iops", null))
        snapshot_id           = lookup(block_device_mappings.value, "snapshot_id", null)
        delete_on_termination = tobool(lookup(block_device_mappings.value, "delete_on_termination", null))
      }
    }
  }

  ...
}
```

[dynamic block](https://www.terraform.io/docs/configuration/expressions.html#dynamic-blocks) の for\_each のおかげで block\_device\_mappings が空の map であれば何も生成されません。指定する場合は、次のように変数を定義するのですが

```tf
block_device_mappings = {
  /dev/xvda = {
    volume_size           = 10
    volume_type           = "gp2"
    encrypted             = true
    snapshot_id           = "snap-0123456789abcdef0"
    delete_on_termination = true
  }
  /dev/xvdb = {
    volume_size           = 10
    volume_type           = "gp2"
    encrypted             = true
    snapshot_id           = "snap-0123456789abcdef1"
    delete_on_termination = true
  }
  /dev/xvdc = {
    volume_size           = 10
    volume_type           = "gp2"
    encrypted             = true
    snapshot_id           = "snap-0123456789abcdef2"
    delete_on_termination = true
  }
}
```

AMI に含まれている volume については volume\_size だけが必須で、他は省略可能です。省略しておけば AMI 作成時の値が使われます。AMI をアカウント跨ぎで共有するために AMI 作成時の volume 暗号化をやめて、EC2 Instance 作成時に暗号化するという選択肢を可能にするためにこういう作りにしました。

便利な機能があってよかったよかった。
