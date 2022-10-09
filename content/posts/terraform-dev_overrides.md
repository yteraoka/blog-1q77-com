---
title: 'Terraform でカスタム provider を使うための dev_overrides 設定'
date: Sun, 04 Apr 2021 04:03:47 +0000
draft: false
tags: ['Terraform', 'Terraform']
---

[healthchecks.io](/2021/03/monitoring-raspberry-pi-with-healthchecks-io/) が大変便利なので Self-hosted なサーバーを用意して、設定を terraform で管理したいなあということがありまして、[terraform-provider-healthchecksio](https://github.com/kristofferahl/terraform-provider-healthchecksio) の接続先サーバーを指定可能にしようと思いました。provider のコードを編集して build するところまではすぐに出来たのですが、このバイナリを terraform からどうやって使うのかな？でハマったのでメモです。

Terraform 0.14 から `~/.terraformrc` の `provider_installation` 内に `dev_overrides` という設定を書くことができるようになっていました。([Development Overrides for Provider Developers](https://www.terraform.io/docs/cli/config/config-file.html#development-overrides-for-provider-developers))

`~/.terraformrc` に次の設定を入れておけば、指定したディレクトリ直下にあるバイナリを使ってくれます。場所はどこでも良いですが、ここで `go build` すればバイナリが生成されるのでそのまま使えるようにここを指定してみました。

```tf
provider_installation {
  dev_overrides {
    "kristofferahl/healthchecksio" = "/Users/teraoka/ghq/github.com/yteraoka/terraform-provider-healthchecksio"
  }
  direct {}
}
```

`terraform init` では次のような Warning が表示されます。

```
% terraform init

Initializing the backend...

Initializing provider plugins...
- Finding latest version of kristofferahl/healthchecksio...
- Using kristofferahl/healthchecksio v1.7.0 from the shared cache directory

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Warning: Provider development overrides are in effect

The following provider development overrides are set in the CLI configuration:
 - kristofferahl/healthchecksio in /Users/teraoka/ghq/github.com/yteraoka/terraform-provider-healthchecksio

Skip terraform init when using provider development overrides. It is not
necessary and may error unexpectedly.

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

ところで、この機能は 0.14 から使えるようになったものなので、0.13 など古いバージョンではエラーになります。

```
There are some problems with the CLI configuration:

Error: Invalid provider_installation method block

Unknown provider installation method "dev_overrides" at X:Y.

As a result of the above problems, Terraform may not behave as intended.
```

以前、elasticsearch provider を使う場合は README にあるように ~/.terraformrc の providers に書いていました。

```tf
providers {
  elasticsearch = "$HOME/.terraform.d/plugins/terraform-provider-elasticsearch.v1.3.0"
}
```

この providers 設定は 0.13 から[非推奨になっている](https://www.terraform.io/docs/cli/config/config-file.html#removed-settings)ようです。

0.13 の場合はどう設定すれば手元のバイナリを指定して実行できるのだろう？
