---
title: "GitLab CI で artifacts:reports:dotenv を使って Job をまたいで変数を渡す"
date: 2023-04-05T01:27:22+09:00
draft: false
tags: ["GitLab", "GitLab CI"]
image: cover.png
author: "@yteraoka"
categories:
  - IT
---

GitLab CI である Job で変数を定義して、それを後続の Job でも使いたいなと思って調べていたら
[artifacts:reports:dotenv](https://docs.gitlab.com/ee/ci/yaml/artifacts_reports.html#artifactsreportsdotenv) にたどり着いたのでメモ。

## 使用例

```yaml
stages:
  - stage1
  - stage2
  - stage3
  - stage4

job1:
  stage: stage1
  script:
    - echo "MY_VAR1=first-variable" >> dot.env
  artifacts:
    expire_in: 30 mins
    reports:
      dotenv: dot.env

# job1 と job2 で使用するファイル名が重複しても別物なので問題ない
job2:
  stage: stage2
  script:
    - echo "MY_VAR1=$MY_VAR1"
    - echo "MY_VAR2=second-variable" >> dot.env
  artifacts:
    expire_in: 30 mins
    reports:
      dotenv: dot.env
  needs:
    - job: job1
      artifacts: true

# needs で指定しているので MY_VAR1 も MY_VAR2 も渡される
job3_1:
  stage: stage3
  script:
    - echo "MY_VAR1=$MY_VAR1"
    - echo "MY_VAR2=$MY_VAR2"
  needs:
    - job: job1
      artifacts: true
    - job: job2
      artifacts: true

# needs で job1 だけを指定しているので MY_VAR1 だけ渡される
job3_2:
  stage: stage3
  script:
    - echo "MY_VAR1=$MY_VAR1"
    - echo "MY_VAR2=$MY_VAR2"
  needs:
    - job: job1
      artifacts: true

# needs を指定しないと MY_VAR1 も MY_VAR2 も両方渡される
job3_3:
  stage: stage3
  script:
    - echo "MY_VAR1=$MY_VAR1"
    - echo "MY_VAR2=$MY_VAR2"

# needs で job1 が指定されているが artifacts は false なので
# MY_VAR1 も MY_VAR2 も渡されない
job3_4:
  stage: stage3
  script:
    - echo "MY_VAR1=$MY_VAR1"
    - echo "MY_VAR2=$MY_VAR2"
  needs:
    - job: job1
      artifacts: false

# MY_VAR2 だけ受け取れる
job3_5:
  stage: stage3
  script:
    - echo "MY_VAR1=$MY_VAR1"
    - echo "MY_VAR2=$MY_VAR2"
  needs:
    - job: job1
      artifacts: false
    - job: job2
      artifacts: true
```

https://gitlab.com/gitlab-org/gitlab/-/issues/22638

ずっと対応されないままかと思ってたけどもう対応されてたんですねえ

## 追記

artifacts に credentials を保存してしまったら download して中身が見れちゃうじゃん、という問題がありましたが、
v16.11 から [artifacts.access](https://docs.gitlab.com/ci/yaml/#artifactsaccess) という設定が可能になっており
次のように `none` と指定すれば download できなくなります。

```json
job:
  artifacts:
    access: none
```

選択肢は次の3つ

- `all` (default): Artifacts in a job in public pipelines are available for download by anyone, including anonymous, guest, and reporter users.
- `developer`: Artifacts in the job are only available for download by users with the Developer role or higher.
- `none`: Artifacts in the job are not available for download by anyone.

https://forum.gitlab.com/t/how-to-restrict-artifact-download-access-in-gitlab-ci/104888/2
