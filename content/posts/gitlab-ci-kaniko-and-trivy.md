---
title: "Gitlab Ci で Kaniko build し Trivy で scan する"
date: 2022-10-26T23:34:28+09:00
draft: false
tags: ['GitLab', 'GitLab CI', 'Kaniko', 'Trivy']
---

GitLab CI でコンテナイメージを Docker daemon の不要な [Kaniko](https://github.com/GoogleContainerTools/kaniko) で build し、それを Trivy でスキャンする方法

まず、kaniko で `--tarPath` を指定して tar ファイルで書き出す

書き出す先を `artifacts` で指定したディレクトリにしておいて次の Job が使えるようにしている

ここでは Container Registry にはまだ Push しないので `--no-push` も指定している


```yaml
# https://docs.gitlab.com/ee/ci/docker/using_kaniko.html
build image:
  stage: build
  image:
    name: gcr.io/kaniko-project/executor:debug
    entrypoint: [""]
  cache:
    key: kaniko-cache
    paths:
      - kaniko-cache
  artifacts:
    paths:
      - images
  script:
    - test -d kaniko-cache || mkdir -p kaniko-cache
    - test -d images || mkdir images
    - /kaniko/executor
      --context "${CI_PROJECT_DIR}"
      --dockerfile "${CI_PROJECT_DIR}/Dockerfile"
      --destination "${CI_PROJECT_PATH}:${CI_COMMIT_SHORT_SHA}"
      --cache-dir kaniko-cache
      --tarPath images/${CI_COMMIT_SHORT_SHA}.tar
      --no-push
```

次に `artifacts` 経由で受け渡された tar ファイルを trivy でスキャンする

```yaml
scan image:
  stage: scan
  dependencies:
    - build image
  image:
    name: aquasec/trivy:latest
  cache:
    key: trivy-cache
    paths:
      - trivy-cache
  script:
    - test -d trivy-cache || mkdir trivy-cache
    - trivy image --no-progress --exit-code 1 --input images/${CI_COMMIT_SHORT_SHA}.tar --cache-dir trivy-cache --ignore-unfixed --severity HIGH,CRITICAL --format table
```

- `--input` で kaniko が書き出した tar ファイルを指定
- `--exit-code 1` で脆弱性があった場合は Job が失敗するようにしてある
- `--ignore-unfixed` で修正版がリリースされていないものは無視する
- `--severity` で `HIGH` 以上だけを検出
