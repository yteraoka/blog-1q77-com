---
title: 'elasticsearch 5.0 x-pack を試す'
date: 
draft: true
tags: ['未分類']
---

### CentOS 7 に elasticsearch 5.0 をインストール

DigitalOcean にて CentOS 7 を起動してインストールをすすめる。 [Install Elasticsearch with RPM](https://www.elastic.co/guide/en/elasticsearch/reference/5.0/rpm.html)

```
$ sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
```

```
$ cat <<_EOD_ | sudo tee /etc/yum.repos.d/elasticsearch.repo
[elasticsearch-5.x]
name=Elasticsearch repository for 5.x packages
baseurl=https://artifacts.elastic.co/packages/5.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
_EOD_
```

```
$ sudo yum -y install java-1.8.0-openjdk-headless elasticsearch
```

heap size を調整する、搭載メモリの半分程度が適当らしい。ファイルシステムのキャッシュに回したほうが良い（-Xms2g, -Xmx2g でデフォルトで設定してある）

```
$ sudoedit /etc/elasticsearch/jvm.options
```

[important Elasticsearch settings](https://www.elastic.co/guide/en/elasticsearch/reference/5.0/important-settings.html)  
[important system settings](https://www.elastic.co/guide/en/elasticsearch/reference/5.0/system-config.html)

```
$ sudo systemctl start elasticsearch
$ sudo systemctl enable elasticsearch
```

```
$ curl -s http://localhost:9200/
```

```
$ curl -s http://localhost:9200/_cat/indices\?v
```

```
$ sudo systemctl stop elasticsearch
$ sudo /usr/share/elasticsearch/bin/elasticsearch-plugin install x-pack
-> Downloading x-pack from elastic
[=================================================] 100%   
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@     WARNING: plugin requires additional permissions     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
* java.lang.RuntimePermission accessClassInPackage.com.sun.activation.registries
* java.lang.RuntimePermission getClassLoader
* java.lang.RuntimePermission setContextClassLoader
* java.lang.RuntimePermission setFactory
* java.security.SecurityPermission createPolicy.JavaPolicy
* java.security.SecurityPermission getPolicy
* java.security.SecurityPermission putProviderProperty.BC
* java.security.SecurityPermission setPolicy
* java.util.PropertyPermission * read,write
* java.util.PropertyPermission sun.nio.ch.bugLevel write
* javax.net.ssl.SSLPermission setHostnameVerifier
See http://docs.oracle.com/javase/8/docs/technotes/guides/security/permissions.html
for descriptions of what these permissions allow and the associated risks.

Continue with installation? [y/N]y
-> Installed x-pack
```

```
$ echo 'action.auto_create_index: +*' | sudo tee -a /etc/elasticsearch/elasticsearch.yml
```

```
$ cat <<_EOD_ | sudo tee /etc/yum.repos.d/kibana.repo
[kibana-5.x]
name=Kibana repository for 5.x packages
baseurl=https://artifacts.elastic.co/packages/5.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
_EOD_
$ sudo yum -y install kibana
```

```
$ sudo /usr/share/kibana/bin/kibana-plugin install x-pack
Attempting to transfer from x-pack
Attempting to transfer from https://artifacts.elastic.co/downloads/kibana-plugins/x-pack/x-pack-5.0.0.zip
Transferring 56932561 bytes....................
Transfer complete
Retrieving metadata from plugin archive
Extracting plugin archive
Extraction complete
Optimizing and caching browser bundles...
Plugin installation complete
```

```
$ sudo systemctl start kibana
$ sudo systemctl enable kibana
```

```
$ cat <<_EOD_ | sudo tee /etc/yum.repos.d/nginx.repo
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/mainline/centos/\$releasever/\$basearch/
gpgcheck=0
enabled=1
_EOD_
$ sudo yum -y install nginx
```

```
    location = / {
        proxy_pass http://localhost:9200;
    }

    location / {
        proxy_pass http://localhost:5601;
    }

    location /_ {
        proxy_pass http://localhost:9200;
    }

    location /.kibana {
        proxy_pass http://localhost:9200;
    }
```

### metricbeat をインストール

別ホストに metricbeat をインストール elasticsearch yum repository からインストールできるため

```
sudo yum -y install metricbeat
```

で ok 設定ファイルは /etc/metricbeat/metricbeat.yml

```
#-------------------------- Elasticsearch output ------------------------------
output.elasticsearch:
  # Array of hosts to connect to.
  hosts: ["10.130.14.174:80"]

  # Optional protocol and basic auth credentials.
  protocol: "http"
  username: "elastic"
  password: "changeme"

  template.name: "metricbeat"
  template.path: "metricbeat.template.json"
  template.overwrite: false
```

ログは /var/log/metricbeat/metricbeat に出力される Dashboard のテンプレートをインポートする

```
/usr/share/metricbeat/scripts/import_dashboards -es http://10.130.14.174 -user elastic -pass changeme
```
