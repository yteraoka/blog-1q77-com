---
title: "Helm chart を GitHub Container Registry に host する"
date: 2024-03-15T00:13:39+09:00
draft: false
---

## 背景

最近は書いたアプリを Kubernetes に deploy することも多い。
その際に helm で簡単に deploy できるようになっていると便利ということで Helm chart を Git に入れておいても良いのだけれども、せっかくなら直接インストールできるようにしてしまいたい。
そんな場合に使えるのが OCI Registry。

[Use OCI-based registries](https://helm.sh/docs/topics/registries/)

そして、GitHub なら GitHub Container Registry (ghcr.io) がそれに使える。

ということで GitHub Actions で Chart を Push するようにしてみる。

## GitHub Actions

### Helm コマンドのインストール

[azure/setup-helm](https://github.com/Azure/setup-helm) が使えます。

```yaml
- uses: azure/setup-helm@v4
  with:
    version: 3.14.2
```

### Helm chart の packaging

`v` prefix を付けた tag を push したら helm package も push するようにしたので tag 名から x.y.z 部分を取り出す step も入れた。


```yaml
- name: Extract version
  run: |
    echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_ENV

- name: Package helm chart
  run: |
    helm package --app-version ${{ env.VERSION }} --version ${{ env.VERSION }} chart/myapp
```

Helm では chart の version と appVersion を Chart.yaml に書く習わしとなっており、appVersion は image の tag として使われるというのが helm create コマンドで作成した chart の仕様。
version と appVersion は別物だけど、ひとつの repository でアプリ (container image) と chart の両方を入れてる場合、使い分けるのも面倒なのでどっちも同じ値にして chart だけ更新した場合も container image を build & push することにした。

`helm package` コマンドで `--app-version` や `--version` を指定すると Chart.yaml の値を更新して package (tgz) を作成してくれる。

### GitHub Container Registry (ghcr.io) への login

docker 同様 helm でも login が必要。`GITHUB_TOKEN` を使ってログインすることが可能になっている。

```yaml
- name: Helm login
  run: |
    echo ${{ secrets.GITHUB_TOKEN }} | helm registry login ghcr.io/${{ github.repository_owner }} --username ${{ github.repository_owner }} --password-stdin
```

### GitHub Container Registry (ghcr.io) へ push

`${{ github.repository_owner }}/myapp` はすでに Container Image として使っているので `chart/` という subPath に保存することにした。

```yaml
- name: Push helm chart
  run: |
    helm push ./myapp-*.tgz oci://ghcr.io/${{ github.repository_owner }}/chart
```

### OCI registry からの helm install

```bash
helm install myapp oci://ghcr.io/yteraoka/chart/myapp --version 1.2.3
```

### Workflow の YAML 全体

<details>
<summary>build-and-pusy.yaml</summary>

```yaml
name: Build and Push Container Image, Helm chart

on:
  push:
    tags:
      - 'v*'

jobs:
  build-and-push:
    name: Build and Push Container Image
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Docker meta for GHCR
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: |
            ghcr.io/yteraoka/myapp
            docker.io/yteraoka/myapp
          tags: |
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha

      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_HUB_USERNAME }}
          password: ${{ secrets.DOCKER_HUB_TOKEN }}

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and push to GHCR and DockerHub
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./Dockerfile
          platforms: linux/amd64
          push: true
          tags: ${{ steps.meta.outputs.tags }}

      - name: Extract version
        run: |
          echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_ENV

      - name: Install helm
        uses: azure/setup-helm@v4
        with:
          version: 3.14.2

      - name: Package helm chart
        run: |
          helm package --app-version ${{ env.VERSION }} --version ${{ env.VERSION }} chart/myapp

      - name: Helm login
        run: |
          echo ${{ secrets.GITHUB_TOKEN }} | helm registry login ghcr.io/${{ github.repository_owner }} --username ${{ github.repository_owner }} --password-stdin

      - name: Push helm chart
        run: |
          helm push ./myapp-*.tgz oci://ghcr.io/${{ github.repository_owner }}/chart
```

</details>

## その他の Registry

Google Cloud の Artifact Registry にも AWS の ECR にも Helm は置けます。

- https://cloud.google.com/artifact-registry/docs/helm
- https://docs.aws.amazon.com/ja_jp/AmazonECR/latest/userguide/push-oci-artifact.html
