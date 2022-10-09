---
title: 'Google Cloud で ServiceAccount になりすます'
date: 
draft: true
tags: ['Uncategorized']
---

GitHub Actions などから Cloud サービスへアクセスする場合に割り当てた ServiceAccount の権限でやりたいことができるかどうか事前に確認したいですよね。そこでその ServiceAccout になりすまして手元から操作をしてみるという。

gcloud コマンドで成りすます場合は `CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT` で指定するか `--impersonate-service-account` オプションで指定する。 terraform の場合は GOOGLE\_IMPERSONATE\_SERVICE\_ACCOUNT で指定するか provider 設定で指定する。 https://cloud.google.com/blog/ja/topics/developers-practitioners/using-google-cloud-service-account-impersonation-your-terraform-code https://github.com/gcpug/nouhau/blob/master/general/note/destroy-service-account-key/README.md