---
title: 'EKS の node で inotify の上限'
date: 2021-10-01T00:16:00+09:00
draft: false
tags: ['AWS', 'KES']
---

https://github.com/awslabs/amazon-eks-ami/pull/589/files

inotify の上限に引っかかり、ssm でログインできなくなったりする。あまり古い EKS AMI を使っていなければ大丈夫
