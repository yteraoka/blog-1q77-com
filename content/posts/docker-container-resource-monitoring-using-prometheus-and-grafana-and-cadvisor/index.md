---
title: 'Prometheus + Grafana + cAdvisor で Docker container のリソースモニタリング'
date: Sat, 14 Jan 2017 15:14:09 +0000
draft: false
tags: ['Docker', 'Grafana', 'Prometheus']
---

Docker 1.11 の Swarm クラスタのリソースモニタリングをどうしようかなということでひとまず各 Docker ホストに [monitoringartist/zabbix-agent-xxl-limited/](https://hub.docker.com/r/monitoringartist/zabbix-agent-xxl-limited/) をインストールし、zabbix で一応見れるようにしていました。

「[Zabbix 3.0をDocker Composeで一度に実行する方法](http://qiita.com/zembutsu/items/686b99be90d72688aee8)」にお世話になりました。

でも zabbix に慣れないのもあるし不便だったのでずっと課題ではありました。

Docker に限らず [Prometheus](https://prometheus.io/) は前から使いたいと思っていたし、今後 Swarm をやめて Kubernetes に切り替えようかなというのもあってやっぱり Prometheus にトライしてみようということにしました。

Prometheus は pull 型のサーバーで、監視対象（target）に exporter という metrics を HTTP で提供する endpoint を用意する必要があります。公式の exporter は [https://prometheus.io/download/](https://prometheus.io/download/) からダウンロードできます。

* [blackbox\_exporter](https://github.com/prometheus/blackbox_exporter)
* [haproxy\_exporter](https://github.com/prometheus/haproxy_exporter)
* [memcached\_exporter](https://github.com/prometheus/memcached_exporter)
* [mysqld\_exporter](https://github.com/prometheus/mysqld_exporter)
* [node\_exporter](https://github.com/prometheus/node_exporter)
* [statsd\_exporter](https://github.com/prometheus/statsd_exporter)

が、公式には Docker コンテナの情報を返す exporter が存在しない。

検索してみると [cAdvisor](https://github.com/google/cadvisor) が Prometheus 用の endpoint を持っているようなのでこれを各 Docker ホストで起動させます。 公式、サーボパーティ合わせて [https://prometheus.io/docs/instrumenting/exporters/](https://prometheus.io/docs/instrumenting/exporters/) ここにもっと沢山載ってました。

### cAdvisor の設定

設定というほどのことはなくって、Docker ホストなので cAdvisor もコンテナとして起動するだけです。 起動方法も GitHub の [README.md](https://github.com/google/cadvisor/blob/master/README.md) に書いてあります。

```
sudo docker run \
  --volume=/:/rootfs:ro \
  --volume=/var/run:/var/run:rw \
  --volume=/sys:/sys:ro \
  --volume=/var/lib/docker/:/var/lib/docker:ro \
  --publish=8080:8080 \
  --detach=true \
  --name=cadvisor \
  google/cadvisor:latest
```

でもなぜか起動時に頻繁に panic でコケるので `--restart=on-failure:30` を追加したのでした。それでも起動しなかったりするので調査中。（docker rm で device or resource busy となって rm -f でないと消せない問題なんかもあるのでコンテナではなく通常のプロセスとして起動させようと試したら今度は docker daemon がだんまりになって reboot しても直らない問題が発生したのでした...）

これで Docker ホストのポート 8080 で Prometheus 用の metrics が提供されます。

```
curl -s http://localhost:8080/metrics
```

で確認できます。Prometheus サーバーからもアクセスできることを確認しておきましょう。

今回の環境は ubuntu 14.04 + docker 1.11 だったので [https://github.com/google/cadvisor/blob/master/docs/running.md](https://github.com/google/cadvisor/blob/master/docs/running.md) の Debian のところにある [https://github.com/google/cadvisor/issues/432](https://github.com/google/cadvisor/issues/432) を見て

```
sudo sed -i 's/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="cgroup_enable=memory"/' /etc/default/grub
sudo update-grub2
```

を実行してみた。

### node\_exporter の設定

コンテナだけじゃなくてホストの状態も確認する必要があるので [node\_exporter](https://github.com/prometheus/node_exporter) も起動させます。Linu x ホストで一般的な各種メトリクスを返してくれます。対応していない特殊なメトリクスもテキストファイルに別途書き出す処理を用意してやればその値を返すようにできます。

起動はこれも docker run するだけです。

```
docker run -d -p 9100:9100 \
  -v "/proc:/host/proc" \
  -v "/sys:/host/sys" \
  -v "/:/rootfs" \
  --net="host" \
  --name="node-exporter" \
  quay.io/prometheus/node-exporter \
    -collector.procfs /host/proc \
    -collector.sysfs /host/sys \
    -collector.filesystem.ignored-mount-points "^/(sys|proc|dev|host|etc)($|/)|docker"
```

コンテナが起動している環境だとマウントポイントが山ほど出てきちゃうので `-collector.filesystem.ignored-mount-points` をちょっといじって docker が含まれるものを除外するようにしました。

```
curl -s http://localhost:9100/metrics
```

で確認します。

### Prometheus の設定

Prometheus サーバーは Go で書かれているので [GitHub のリリースページ](https://github.com/prometheus/prometheus/releases) から最新版をダウンロードして展開すると prometheus というバイナリがあるので、そのディレクトリに移動して

```
./prometheus
```

とすれば起動します。デフォルトではカレントディレクトリの `prometheus.yml` を設定ファイルとして `data` ディレクトリをデータの保存場所として動作します。`console_libraries`, `consoles` もカレントディレクトリにある前提で動作するので場所を変更したい場合は引数で指定する必要があります。

もちろん [Docker Image](https://quay.io/repository/prometheus/prometheus) もあるので docker run するだけでも起動します。設定ファイルを書いて指定する必要はあります。 設定ファイルはコメントを削るとデフォルトで次の様に書いてありました

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
     monitor: 'codelab-monitor'
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
```

で、この `scrape_configs` にリストでモニタリング対象を設定します。Prometheus 自身の metrics を収集する設定がデフォルトで入っています `job_name: 'prometheus'`。これにならって Docker コンテナ用 (cAdvisor) の設定を追加します。

```yaml
  - job_name: 'docker'
    static_configs:
      - targets:
          - 'docker-host1:8080'
          - 'docker-host2:8080'
          - 'docker-host3:8080'
        labels:
          group: 'docker-container'
```

`labels` は任意のラベルを指定できます。グラフ生成時にこれを使ってグループ化したりできます。`job_name` もラベルと同様に使えるので上記の様に同じ値を設定するのはあまり意味がない。
metrics を返す URL の path がデフォルトの `/metrics` でない場合は `job_name` と同じ階層に `metrics_path: '/some/where'` と指定します。 次に node_exporter 用の設定です

```yaml
  - job_name: 'docker-host'
    static_configs:
      - targets:
          - 'docker-host1:9100'
          - 'docker-host2:9100'
          - 'docker-host3:9100'
        labels:
          group: 'docker-host'
```

ポート番号が違うだけですね。ラベルは適当。 また、ここでは `static_configs` を使っているので直接 `targets` に対象をつらつらを書き並べているのでホストの増減に合わせて書き換える必要があります。

Prometheus にはいくつかの Service Discovery 機能があるためこれを利用すれば動的に監視対象を更新できます。

[https://prometheus.io/docs/operating/configuration/](https://prometheus.io/docs/operating/configuration/)

* [azure\_sd\_config](https://prometheus.io/docs/operating/configuration/#<azure_sd_config>)
* [consul\_sd\_config](https://prometheus.io/docs/operating/configuration/#<consul_sd_config>)
* [dns\_sd\_config](https://prometheus.io/docs/operating/configuration/#<dns_sd_config>)
* [ec2\_sd\_config](https://prometheus.io/docs/operating/configuration/#<ec2_sd_config>)
* [file\_sd\_config](https://prometheus.io/docs/operating/configuration/#<file_sd_config>)
* [gce\_sd\_config](https://prometheus.io/docs/operating/configuration/#<gce_sd_config>)
* [kubernetes\_sd\_config](https://prometheus.io/docs/operating/configuration/#<kubernetes_sd_config>)
* [marathon\_sd\_config](https://prometheus.io/docs/operating/configuration/#<marathon_sd_config>)
* [nerve\_sd\_config](https://prometheus.io/docs/operating/configuration/#<nerve_sd_config>)
* [serverset\_sd\_config](https://prometheus.io/docs/operating/configuration/#<serverset_sd_config>)

`consul_sd_config`, `file_sd_config` は使ったので次のエントリで書こうと思います。

port 9090 にブラウザでアクセスすれば Prometheus サーバーにアクセスできます。 上部のメニューにある「Status▼」から「Targets」にアクセスすると job と target のリストが確認できます。

Service Discovery で見つかった target も表示されます。

{{< figure src="prometheus-targets.png" caption="Prometheus Targets" >}}

### Grafana

の設定 [Grafana](http://grafana.org/) は DEB も RPM も APT, YUM の repository も提供されているのでパッケージを使ってインストールします。
設定ファイルは省略（後で書くかも） いろんな認証方法に対応してますね。
Grafana は port 3000 を listen します。
起動したらブラウザでそこにアクセスします。
まずは DataSource として Prometheus を追加します。

{{< figure src="grafana_add_datasource.png" caption="Grafana add datasource" >}}

**Access** には **direct** か **proxy** かを指定しますが。これは Prometheus へのアクセスをブラウザから直接行うか、Grafana に proxy させるかの指定です。ブラウザから直接アクセスできるかどうかとか、認証をどするかによって指定します。 次にダッシュボードを作る必要があります。一から作るのは大変そうですが [collection of shared dashboards](https://grafana.net/dashboards?dataSource=prometheus&category=docker) というものがあるので、ここから [Docker and system monitoring](https://grafana.net/dashboards/893) をダウンロードして、「**Dashboard**」→「**Import**」で json ファイルをインポートします。 あら簡単、こんな Dashboard ができちゃいました

{{< figure src="grafana_doker_dashboard.png" caption="Grafana doker dashboard" >}}

node\_exporter を使っているので [Node Exporter Server Metrics](https://grafana.net/dashboards/405), [Node exporter server stats](https://grafana.net/dashboards/704) あたりを使ってホストの状態を確認することもできます。
これらを参考にして必要に合わせてオリジナルの Dashboard を作るのが良いかと思います。各グラフのタイトル部分をクリックして「**Edit**」を選択すると設定内容が確認できます。
対象サーバーや対象コンテナをリストから選んで表示するようにするには **Template** を使います。

次回は Consul と File の Service Discovery について書こうと思います。

書きました「[Prometheus の Service Discovery](/2017/01/service-discovery-of-prometheus/)」
