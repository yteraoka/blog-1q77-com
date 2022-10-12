---
title: 'Terraform 小ネタ - formatlist'
date: Mon, 27 Jul 2020 15:30:51 +0000
draft: false
tags: ['Terraform']
---

Terraform の小ネタです。どうせまた自分でググることになるのでメモ。

[formatlist](https://www.terraform.io/docs/configuration/functions/formatlist.html) です。 Security Group の設定を行う場合には IP アドレスではなく [CIDR](https://ja.wikipedia.org/wiki/Classless_Inter-Domain_Routing) 表記で指定する必要があります。1つの IPv4 アドレスであれば `/32` をつける必要があります。 でも、何かのリソースで作成された IP アドレスは IP アドレス単体でしか取得できなかったりします。例えば [NAT Gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/nat_gateway) の IP アドレス。 これに `/32` をつけるのに便利なのが [formatlist](https://www.terraform.io/docs/configuration/functions/formatlist.html) です。

次の例では [concat](https://www.terraform.io/docs/configuration/functions/concat.html) と組み合わせていますが、これもメモです。ここで注目すべきは formatlist の部分。sprintf のように `"%s/32"` でフォーマットしていていて、これが後ろの `module.vpc.nat_public_ips` というリストの各要素に適用されて、その結果がリストで返されます。

```tf
resource "aws_security_group_rule" "some_ingress" {
  type              = "ingress"
  from_port         = var.some_port_number
  to_port           = var.some_port_number
  protocol          = "TCP"
  security_group_id = aws_security_group.some_sg.id
  cidr_blocks       = concat(concat(var.some_cidrs, var.additional_cidrs), formatlist("%s/32", module.vpc.nat_public_ips))
  description       = "example"
}
```

もう見つけたと思いますが [format](https://www.terraform.io/docs/configuration/functions/format.html) は sprintf のように使えます。

ネットワーク関連では [cidrhost](https://www.terraform.io/docs/configuration/functions/cidrhost.html)、[cidrnetmask](https://www.terraform.io/docs/configuration/functions/cidrnetmask.html)、[cidrsubnet](https://www.terraform.io/docs/configuration/functions/cidrsubnet.html) という便利 Function もあります。
