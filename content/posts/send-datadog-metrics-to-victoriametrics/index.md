---
title: "Datadog Agent からの Metrics を Victoria Metrics で受ける"
date: 2023-03-19T21:38:04+09:00
draft: false
tags: ["VictoriaMetrics", "Datadog"]
image: cover.jpg
---

[Victoria Metrics](https://github.com/VictoriaMetrics/VictoriaMetrics) は [v1.67.0](https://github.com/VictoriaMetrics/VictoriaMetrics/releases/tag/v1.67.0) で Datadog Agent からのメトリクスを受け取れるようになっているので今回はこれを試してみる。

Victoria Metrics のドキュメント [How to send data from DataDog agent](https://docs.victoriametrics.com/Single-server-VictoriaMetrics.html#how-to-send-data-from-datadog-agent)

## Single node Instance をセットアップ

Victoria Metrics はクラスタリング構成も可能だが今回は Single node のサーバーで検証。

```bash
VM_VER=v1.89.1
curl -LO https://github.com/VictoriaMetrics/VictoriaMetrics/releases/download/${VM_VER}/victoria-metrics-linux-amd64-${VM_VER}.tar.gz
sudo tar -C /usr/local/bin -xvf victoria-metrics-linux-amd64-${VM_VER}.tar.gz victoria-metrics-prod
sudo chmod 0755 /usr/local/bin/victoria-metrics-prod
sudo chown root:root /usr/local/bin/victoria-metrics-prod
sudo groupadd -g 3000 victoriametrics
sudo useradd -u 3000 -g victoriametrics -s /usr/sbin/nologin victoriametrics
sudo install -o victoriametrics -g victoriametrics -m 0750 -d /var/lib/victoria-metrics
```

```bash
sudo tee /etc/systemd/system/victoriametrics.service > /dev/null <<'EOF'
[Unit]
Description=Description=VictoriaMetrics service
After=network.target

[Service]
Type=simple
LimitNOFILE=2097152
User=victoriametrics
Group=victoriametrics
ExecStart=/usr/local/bin/victoria-metrics-prod -storageDataPath=/var/lib/victoria-metrics -selfScrapeInterval=30s -retentionPeriod=12 -maxConcurrentInserts=32 -search.maxUniqueTimeseries=900000
SyslogIdentifier=victoriametrics
Restart=always
PrivateTmp=yes
ProtectHome=yes
NoNewPrivileges=yes
ProtectSystem=full
ProtectControlGroups=true
ProtectKernelModules=true
ProtectKernelTunables=yes

[Install]
WantedBy=multi-user.target
EOF
```

```bash
sudo systemctl daemon-reload
sudo systemctl start victoriametrics
sudo systemctl enable victoriametrics
```

これで 8428/tcp ポートで Victoria Metrics が起動する。

昔見た Web UI よりもだいぶ使いやすくなってる！ Prometheus よりも使いやすそう。


## EC2 インスタンスに Datadog Agent をセットアップ

最近 GA になった Amazon Linux 2023 で EC2 インスタンスを作成し、そこに Datadog Agent をセットアップする。

インストール方法は https://app.datadoghq.com/account/settings#agent/aws にある。
Datadog へのログインが必要だが、[Datadog Learning Center](https://learn.datadoghq.com/) のコースを受講(無料)すれば何度でも2週間使えるトライアルアカウントが発行される。

```bash
sudo dnf install -y libxcrypt-compat
```

ドキュメントの手順では

```bash
DD_API_KEY= DD_SITE="datadoghq.com" \
 bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh)"
```

となっているが、`DD_SITE` ではなく `DD_URL` で Victoria Metrics を指定する。

```bash
sudo DD_API_KEY=dummy \
 DD_URL="http://victoriametrics:8428/datadog" \
 DD_INSTALL_ONLY=true \
 bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh)"
```

### 動作確認

tcpdump でやり取りを覗いてみる。

```
POST /datadog/api/v1/check_run HTTP/1.1
Host: victoriametrics:8428
User-Agent: datadog-agent/7.43.1
Content-Length: 223
Content-Encoding: deflate
Content-Type: application/json
Dd-Agent-Version: 7.43.1
Dd-Api-Key: dummy
Accept-Encoding: gzip

HTTP/1.1 202 Accepted
Content-Type: application/json
Vary: Accept-Encoding
X-Server-Hostname: ip-172-31-6-187.ap-northeast-1.compute.internal
Date: Sun, 19 Mar 2023 12:02:39 GMT
Content-Length: 15

{"status":"ok"}
```

これは成功してる。

が

```
POST /datadog/api/v2/series HTTP/1.1
Host: victoriametrics:8428
User-Agent: datadog-agent/7.43.1
Content-Length: 4559
Content-Encoding: deflate
Content-Type: application/x-protobuf
Dd-Agent-Payload: v5.0.67
Dd-Agent-Version: 7.43.1
Dd-Api-Key: dummy
Accept-Encoding: gzip

TTP/1.1 400 Bad Request
Content-Type: text/plain; charset=utf-8
Vary: Accept-Encoding
X-Content-Type-Options: nosniff
X-Server-Hostname: ip-172-31-6-187.ap-northeast-1.compute.internal
Date: Sun, 19 Mar 2023 12:02:39 GMT
Content-Length: 123

remoteAddr: "172.31.0.183:53542"; requestURI: /datadog/api/v2/series; unsupported path requested: "/datadog/api/v2/series"
```

ぐぬぬ、Victoria Metrics がサポートしているのは `/datadog/api/v1/series` だけれども Datadog Agent v7 が使うのは v2 でした...

### 撃沈

Datadog Agent v6 で試しても series API は v2 でした...  撃沈

https://docs.datadoghq.com/ja/api/latest/metrics/#submit-metrics

### `use_v2_api.series` 設定の発見

諦めてインスタンスを削除した後に Datadog Agent は GitHub で公開されているのだから一応確認してみるかと思って
[Datadog Agent](https://github.com/DataDog/datadog-agent) のリポジトリ内を検索してみたら
[CHANGELOG の 7.41.0 / 6.41.0](https://github.com/DataDog/datadog-agent/blob/main/CHANGELOG.rst#7410--6410) で 

> The Agent now uses the V2 API to submit series data to the Datadog intake by default. This can be reverted by setting `use_v2_api.series` to false.

という記述を見つけた。

早速再度サーバーをセットアップして試す。

`/etc/datadog-agent/datadog.yaml` に `use_v2_api` 設定はなかったので追記して datadog-agent を restart します。

```bash
sudo tee -a /etc/datadog-agent/datadog.yaml > /dev/null <<'EOF'
use_v2_api:
  series: false
EOF
```

```
POST /datadog/api/v1/series HTTP/1.1
Host: victoriametrics:8428
User-Agent: datadog-agent/7.43.1
Content-Length: 3797
Content-Encoding: deflate
Content-Type: application/json
Dd-Agent-Version: 7.43.1
Dd-Api-Key: dummy
Accept-Encoding: gzip

HTTP/1.1 202 Accepted
Content-Type: application/json
Vary: Accept-Encoding
X-Server-Hostname: ip-172-31-0-54.ap-northeast-1.compute.internal
Date: Sun, 19 Mar 2023 13:14:56 GMT
Content-Length: 15

{"status":"ok"}
```

成功してる！！

Victoria Metrics の Web UI (`/vmui`) の Query ページで `{__name__=~"datadog.*"}` とクエリしてみました。

{{< figure src="vmui-datadog-metrics.png" alt="datadog.* metrics" >}}

`system.cpu.user` と `system.cpu.system` をグラフ表示してみた。

{{< figure src="vmui-system-cpu.png" alt="sysem.cpu.user, system.cpu.system" >}}

後は Grafana Dashboard を頑張れば...
