---
title: 'Apache Mesos を試す'
date: 
draft: true
tags: ['未分類']
---

まずは Vagrant でテスト

### Vagrant で ubuntu を起動

```
$ vagrant init ubuntu/trusty64
$ vagrant up
$ vagrant ssh

```

### 必要なものをインストール

```
\# Update the packages.
$ sudo apt-get update

# Install a few utility tools.
$ sudo apt-get install -y tar wget git

# Install the latest OpenJDK.
$ sudo apt-get install -y openjdk-7-jdk

# Install autotools (Only necessary if building from git repository).
$ sudo apt-get install -y autoconf libtool

# Install other Mesos dependencies.
$ sudo apt-get -y install build-essential python-dev python-boto libcurl4-nss-dev libsasl2-dev libsasl2-modules maven libapr1-dev libsvn-dev

```

### mesos のビルド

```
$ wget http://www.apache.org/dist/mesos/0.28.0/mesos-0.28.0.tar.gz
$ tar -zxf mesos-0.28.0.tar.gz

# Change working directory.
$ cd mesos-0.28.0

# Configure and build.
$ mkdir build
$ cd build
$ ../configure
$ make

```