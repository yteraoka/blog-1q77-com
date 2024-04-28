---
title: "Wireguard Exporter と Grafana Alloy で VPN 通信量を可視化"
date: 2024-04-28T21:57:31+09:00
tags: [Grafana, alloy, wireguard, Rust]
draft: false
image: cover.png
---
先日、家のラズパイに Grafana Alloy をセットアップしてメトリクス可視化の環境はできているので WireGuard での VPN 通信のメトリクスを可視化してみようかなと試してみました。

[prometheus_wireguard_exporter](https://github.com/MindFlavor/prometheus_wireguard_exporter) を使ってみることにしましたが、Container Image は [dockerhub](https://hub.docker.com/r/mindflavor/prometheus-wireguard-exporter) で公開されているのですが、うちのラズパイでは Docker は使ってないのでバイナリが GitHub の release ページで公開されてれば良かったのですが無いので build することにします。

Rust で書かれていますが、Rust は1行も書いたことないし build もしたことがないけどやってみる。

## WSL で cargo の cross platform build する

ラズパイに余計なものを入れたくないので WSL で cross platform build してみます。

DietPi で `uname -m` を実行すると aarch64 ということらしい。

```
# uname -m
aarch64
```

### Rust の環境構築

インストール

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

<details>
<summary>実行例</summary>

```
$ curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
info: downloading installer

Welcome to Rust!

This will download and install the official compiler for the Rust
programming language, and its package manager, Cargo.

Rustup metadata and toolchains will be installed into the Rustup
home directory, located at:

  /home/yteraoka/.rustup

This can be modified with the RUSTUP_HOME environment variable.

The Cargo home directory is located at:

  /home/yteraoka/.cargo

This can be modified with the CARGO_HOME environment variable.

The cargo, rustc, rustup and other commands will be added to
Cargo's bin directory, located at:

  /home/yteraoka/.cargo/bin

This path will then be added to your PATH environment variable by
modifying the profile files located at:

  /home/yteraoka/.profile
  /home/yteraoka/.bashrc
  /home/yteraoka/.zshenv

You can uninstall at any time with rustup self uninstall and
these changes will be reverted.

Current installation options:


   default host triple: x86_64-unknown-linux-gnu
     default toolchain: stable (default)
               profile: default
  modify PATH variable: yes

1) Proceed with standard installation (default - just press enter)
2) Customize installation
3) Cancel installation
>

info: profile set to 'default'
info: default host triple is x86_64-unknown-linux-gnu
info: syncing channel updates for 'stable-x86_64-unknown-linux-gnu'
info: latest update on 2024-04-09, rust version 1.77.2 (25ef9e3d8 2024-04-09)
info: downloading component 'cargo'
info: downloading component 'clippy'
info: downloading component 'rust-docs'
 14.9 MiB /  14.9 MiB (100 %)   8.3 MiB/s in  1s ETA:  0s
info: downloading component 'rust-std'
 24.3 MiB /  24.3 MiB (100 %)   8.3 MiB/s in  3s ETA:  0s
info: downloading component 'rustc'
 60.3 MiB /  60.3 MiB (100 %)   8.2 MiB/s in  8s ETA:  0s
info: downloading component 'rustfmt'
info: installing component 'cargo'
info: installing component 'clippy'
info: installing component 'rust-docs'
 14.9 MiB /  14.9 MiB (100 %)   6.0 MiB/s in  2s ETA:  0s
info: installing component 'rust-std'
 24.3 MiB /  24.3 MiB (100 %)   9.9 MiB/s in  2s ETA:  0s
info: installing component 'rustc'
 60.3 MiB /  60.3 MiB (100 %)  11.6 MiB/s in  5s ETA:  0s
info: installing component 'rustfmt'
info: default toolchain set to 'stable-x86_64-unknown-linux-gnu'

  stable-x86_64-unknown-linux-gnu installed - rustc 1.77.2 (25ef9e3d8 2024-04-09)


Rust is installed now. Great!

To get started you may need to restart your current shell.
This would reload your PATH environment variable to include
Cargo's bin directory ($HOME/.cargo/bin).

To configure your current shell, you need to source
the corresponding env file under $HOME/.cargo.

This is usually done by running one of the following (note the leading DOT):
. "$HOME/.cargo/env"            # For sh/bash/zsh/ash/dash/pdksh
source "$HOME/.cargo/env.fish"  # For fish
```

</details>

aarch64 をターゲットとして追加

```bash
rustup target add aarch64-unknown-linux-gnu
```

<details>
<summary>実行例</summary>

```
$ rustup target add aarch64-unknown-linux-gnu
info: downloading component 'rust-std' for 'aarch64-unknown-linux-gnu'
info: installing component 'rust-std' for 'aarch64-unknown-linux-gnu'
 29.9 MiB /  29.9 MiB (100 %)  16.7 MiB/s in  1s ETA:  0s
```

</details>

`rustup target add` では linker は入らないということらしいので apt でインストール

```
sudo apt-get install gcc-aarch64-linux-gnu -y
```

## prometheus\_wireguard\_exporter の build

git clone して `.cargo/config.toml` に aarch64-unknown-linux-gnu target の linker を指定する

```bash
ghq get https://github.com/MindFlavor/prometheus_wireguard_exporter.git
cd $(ghq root)/github.com/MindFlavor/prometheus_wireguard_exporter
cat >> .cargo/config.toml <<EOF
[target.aarch64-unknown-linux-gnu]
linker = "aarch64-linux-gnu-gcc"
EOF
```

target 指定して build を実行

```bash
cargo build --target aarch64-unknown-linux-gnu
```

target ディレクトリ配下に `prometheus_wireguard_exporter` が出来上がっているので探してラズパイの /usr/local/bin/ にコピーする

```bash
$ find target -name prometheus_wireguard_exporter
target/aarch64-unknown-linux-gnu/debug/prometheus_wireguard_exporter
```

## Wireguard Exporter の設定

### systemd 設定

`/etc/systemd/system/wireguard_exporter.service` で systemd の service 設定を行う。

[document](https://mindflavor.github.io/prometheus_wireguard_exporter/) に例が載っている。

```bash
cat > cat /etc/systemd/system/wireguard_exporter.service <<'EOF'
[Unit]
Description=Prometheus WireGuard Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/prometheus_wireguard_exporter -n /etc/wireguard/wg0.conf -i wg0
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
```

追加した service を読み込ませる

```bash
systemctl daemon-reload
```

起動してみる

```bash
systemctl start wireguard_exporter
systemctl status wireguard_exporter
```

メトリクスが取得できるか確認する

```bash
curl -s http://localhost:9586/metrics
```

問題なさそうなら自動起動を有効にする

```bash
systemctl enable wireguard_exporter
```

### 取得できるメトリクス

次の3つのメトリクスが取得できる

```
# HELP wireguard_sent_bytes_total Bytes sent to the peer
# TYPE wireguard_sent_bytes_total counter

# HELP wireguard_received_bytes_total Bytes received from the peer
# TYPE wireguard_received_bytes_total counter

# HELP wireguard_latest_handshake_seconds UNIX timestamp seconds of the last handshake
# TYPE wireguard_latest_handshake_seconds gauge
```

label に `public_key` が入っているので発行した key 単位での通信料が得られるのだが、public key ではどれがどの用途の key なのかがわかりづらいのでこの exporter には wireguard の設定ファイルのそれぞれの key 設定にコメントで `friendly_name` を入れておくことでそれをメトリクスの label に追加してくれる機能がある。

pivpn コマンドを使って client を作成しているので次のフォーマットでファイルに入っている、ここに `friendly_name` をコメントで入れる。次の pivpn コマンドで消えてしまわないか心配ではあるが、今のところクライアントの追加、削除では消えなかった。

```
### begin myclient1 ###
[Peer]
PublicKey = 41Vji1423FcUlYe/KwrIdFQvv0YS8UJlaFnTe9AZzCs=
PresharedKey = Wj2MC1yp5ZZ3ndnHWlIa5m1VZFCo3ulfmjeDKPVvWp8=
AllowedIPs = 10.20.30.5/32
### end myclient1 ###
```

↓

```
### begin myclient1 ###
[Peer]
# friendly_name = myclient1
PublicKey = 41Vji1423FcUlYe/KwrIdFQvv0YS8UJlaFnTe9AZzCs=
PresharedKey = Wj2MC1yp5ZZ3ndnHWlIa5m1VZFCo3ulfmjeDKPVvWp8=
AllowedIPs = 10.20.30.5/32
### end myclient1 ###
```

## Grafana Alloy での scrape 設定

[prometheus.scrape](https://grafana.com/docs/alloy/latest/reference/components/prometheus.scrape/) を参考に `/etc/alloy/config.alloy` に次の設定を追記して reload しました。

```
prometheus.scrape "wireguard_exporter" {
  targets = [
    {"__address__" = "127.0.0.1:9586", "instance" = constants.hostname},
  ]
  forward_to      = [prometheus.remote_write.metrics_service.receiver]
  scrape_interval = "30s"
  metrics_path    = "/metrics"
}
```

