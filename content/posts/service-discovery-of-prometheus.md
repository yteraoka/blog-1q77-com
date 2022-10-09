---
title: 'Prometheus の Service Discovery'
date: Mon, 16 Jan 2017 16:06:38 +0000
draft: false
tags: ['Consul', 'Prometheus']
---

前回の「[Prometheus + Grafana + cAdvisor で Docker container のリソースモニタリング](/2017/01/docker-container-resource-monitoring-using-prometheus-and-grafana-and-cadvisor/)」では prometheus.yml に直接ターゲットサーバーのリストを書きましたが、[file\_sd\_config](https://prometheus.io/docs/operating/configuration/#<file_sd_config&g;) と [consul\_sd\_config](https://prometheus.io/docs/operating/configuration/#<consul_sd_config>) を使ってみます。

### file\_sd\_config

ファイルを使った Service Discovery は次のように `file_sd_configs` に複数の JSON または YAML ファイルを指定します。ひとつだけ「`\`」を含んだ `some_dir/*.yml` と glob っぽく指定することも可能です。ファイルフォーマットはファイル名の拡張子から判断されます。

```yaml
  - job_name: 'myapp'
    metrics_path: '/api/prometheus'
    file_sd_configs:
      - files:
          - 'tgroups/myapp1-servers.yml'
          - 'tgroups/myapp2-servers.yml'
```

ファイルの中身は [static\_config](https://prometheus.io/docs/operating/configuration/#<static_config>) で、次のようなフォーマットで記述します。

```json
[
  {
    "targets": [ "", ... ],
    "labels": {
      "": "", ...
    }
  },
  ...
] 
```

YAML ではこのようになります。

```yaml
- targets:
    - 192.168.2.95:31234
    - 192.168.2.96:32768
    - 192.168.2.97:35395
  labels:
    aaa: AAA
    bbb: BBB
```

なんだファイルに書くなら prometheus.yml と何が違うんだ？というおとになりますが、fsnotify で変更を検知して自動でリロードしてくれます。また、対象のリストを含むだけなので自動更新するのも簡単です。次に説明する `consul_sd_config` で consul から直接リストを取り出せますが、それは consul の service 部分だけなので node の情報を使いたい場合は [consul-template](https://github.com/hashicorp/consul-template) を使うなどして更新することができます。
他のリソースから cron などで更新しても良いです。

### consul\_sd\_config

[Consul](https://www.consul.io/) の [catalog API](https://www.consul.io/docs/agent/http/catalog.html) の **services**, **service** を使ってターゲットを更新します。

**index** と **wait** パラメータを使って変更があるまで最大で wait の秒数待つけど、その間に変更があったらすぐにレスポンスが変えるようになっています。

**service** API では Consul から次のようなレスポンスが返ります。

```json
[
  {
    "Node": "docker-nodeqa1",
    "Address": "192.168.2.97",
    "ServiceID": "docker-host1:myapp_1:8000",
    "ServiceName": "myapp",
    "ServiceTags": [],
    "ServiceAddress": "10.0.0.8",
    "ServicePort": 32768,
    "ServiceEnableTagOverride": false,
    "CreateIndex": 9181194,
    "ModifyIndex": 9181194
  }
]
```

デフォルトでは **Address** よりも **ServiceAddress** が優先されるため、上記の例では **10.0.0.8:32768** をターゲットとして登録します。 私の今回の環境ではこの **ServiceAddress** は Docker の内部ネットワークであり、Docker クラスタの外にある Prometheus サーバーからはアクセスできませんでした。**Address** を使う方法はないか？と GitHub の issue で聞いてみたら [relabel\_config](https://prometheus.io/docs/operating/configuration/#<relabel_config>) でできるよってことだったので調べてみたら次の設定でできました。ラベルっていう名称からグルーピングに使うようなラベルだけかと思ったら違ったのですね。

```yaml
  - job_name: 'myapp'
    metrics_path: '/api/prometheus'
    consul_sd_configs:
      - server: '127.0.0.1:8500'
        datacenter: 'dc1'
        services:
          - 'myapp1'
          - 'myapp2'
    relabel_configs:
      - source_labels: ['__meta_consul_address', '__meta_consul_service_port']
        separator: ':'
        regex: '(.*)'
        target_label: '__address__'
        replacement: '$1'
```

**127.0.0.1:8500** の consul サーバーに問い合わせて、**myapp1**、**myapp2** のサービスを対象とし **Address** と **ServiceAddress** を **:** で join したものを **regex** でマッチさせ、カッコで囲んだ '$1', '$2' などを使って **target\_label** で指定するラベルにセットします。**\_\_address\_\_** がターゲットとなるIPアドレスとポートになります。[https://github.com/prometheus/prometheus/issues/2342](https://github.com/prometheus/prometheus/issues/2342)

正しくターゲットが取得できているかどうかは Prometheus UI の上部のメニューにある「**Status▼**」から「**Targets**」で確認できます。

いーーーーーっじょう！！

次回は Grafana でのグラフの作成方法かな。
