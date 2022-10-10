---
title: 'apt-key is deprecated への対応'
date: 
draft: true
tags: ['Uncategorized']
---

```
Warning: apt-key is deprecated. Manage keyring files in trusted.gpg.d instead (see apt-key(8)).
```

```
echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb\_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
curl -sfLo /etc/apt/trusted.gpg.d/pgdg.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc
apt-get update
apt-get -y install postgresql-client-14
```

https://zenn.dev/spiegel/articles/20220508-apt-key-is-deprecated
