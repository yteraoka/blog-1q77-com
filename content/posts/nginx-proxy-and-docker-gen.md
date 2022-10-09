---
title: 'nginx-proxy, docker-gen という便利ツール'
date: Tue, 02 Feb 2016 15:15:22 +0000
draft: false
tags: ['Docker', 'docker-gen', 'forego', 'nginx', 'thumbor']
---

先日ようやく [Docker を触り始めた](/2016/02/thumbor-の-docker-化/)わけですが thumbor を使う場合、前段に nginx を置いてキャッシュさせるべきだから nginx の docker も必要だなっと思って調べてたら [jwilder/nginx-proxy](https://github.com/jwilder/nginx-proxy) というものを見つけました。 大変便利そうな docker image だったのでこれについて書いてみます。 nginx-proxy は nginx の [official image](https://hub.docker.com/_/nginx/) をベースに [docker-gen](https://github.com/jwilder/docker-gen) というツールを使って template から nginx の設定ファイルを生成するように出来ています。 [nginx.tmpl](https://github.com/jwilder/nginx-proxy/blob/master/nginx.tmpl) [consul-template](https://github.com/hashicorp/consul-template) の docker API 版ですね。consul の変更ではなく docker の変更を監視してファイルを更新します。 前回作った thumbor を2つ動かしてその手前に nginx-proxy を置くとどうなるかというと `EXPOSE` されていれば `-p` で port forwarding する必要はありません。 thumbor の image は 8000 番を EXPOSE してあります。 VIRTUAL\_HOST 環境変数を指定して起動します。

```
$ docker run -d --name thumbor1 -e VIRTUAL_HOST=thumbor.example.com thumbor-centos
4930455aadf4a63055a29016dfde521c2dfa7c7fd34ee75498a4c3850adff56c
$ docker run -d --name thumbor2 -e VIRTUAL_HOST=thumbor.example.com thumbor-centos
4318322fa2a6f66374474bc7b7a0ce1964a6aa828eae7852027b1f12faadd416
$ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
4318322fa2a6        thumbor-centos      "/bin/bash /bin/thumb"   4 seconds ago       Up 3 seconds        8000/tcp            thumbor2
4930455aadf4        thumbor-centos      "/bin/bash /bin/thumb"   12 seconds ago      Up 11 seconds       8000/tcp            thumbor1
```

nginx-proxy は先に起動していても、後から起動しても良いですがホスト側の docker.sock にアクセスできるように volume 指定する必要があります。この socket を通じて Docker API で監視しています。

```
$ docker run -d -p 80:80 --name nginx -v /var/run/docker.sock:/tmp/docker.sock:ro jwilder/nginx-proxy
f259f6c444aadb5c9573f3ee598e6a101ac2598d2a018bb101b33fd7d6477d03
```

nginx-proxy を起動したところで /etc/nginx/conf.d/default.conf を確認してみます。

```nginx
$ docker exec nginx cat /etc/nginx/conf.d/default.conf
# If we receive X-Forwarded-Proto, pass it through; otherwise, pass along the
# scheme used to connect to this server
map $http_x_forwarded_proto $proxy_x_forwarded_proto {
  default $http_x_forwarded_proto;
  ''      $scheme;
}
# If we receive Upgrade, set Connection to "upgrade"; otherwise, delete any
# Connection header that may have been passed to this server
map $http_upgrade $proxy_connection {
  default upgrade;
  '' close;
}
gzip_types text/plain text/css application/javascript application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;
log_format vhost '$host $remote_addr - $remote_user [$time_local] '
                 '"$request" $status $body_bytes_sent '
                 '"$http_referer" "$http_user_agent"';
access_log off;
# HTTP 1.1 support
proxy_http_version 1.1;
proxy_buffering off;
proxy_set_header Host $http_host;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection $proxy_connection;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $proxy_x_forwarded_proto;
server {
	server_name _; # This is just an invalid value which will never trigger on a real hostname.
	listen 80;
	access_log /var/log/nginx/access.log vhost;
	return 503;
}
upstream thumbor.example.com {
			# thumbor2
			server 172.17.0.3:8000;
			# thumbor1
			server 172.17.0.2:8000;
}
server {
	server_name thumbor.example.com;
	listen 80 ;
	access_log /var/log/nginx/access.log vhost;
	location / {
		proxy_pass http://thumbor.example.com;
	}
}
```

thumbor.example.com にアクセスすると thumbor1, thumbor2 に振り分けられる設定になっています。 VIRTUAL\_HOST という環境変数を設定するだけで。 thumbor1 を停止してみます。

```
$ docker stop thumbor1
thumbor1
$ docker exec nginx cat /etc/nginx/conf.d/default.conf | grep -C 5 ^upstream
	server_name _; # This is just an invalid value which will never trigger on a real hostname.
	listen 80;
	access_log /var/log/nginx/access.log vhost;
	return 503;
}
upstream thumbor.example.com {
			# thumbor2
			server 172.17.0.3:8000;
}
server {
	server_name thumbor.example.com;
```

upstream thumbor.example.com のメンバーが減りました。また起動させれば復活します。 別の VIRTUAL\_HOST を指定すれば別の virtual host 設定が追加されます。

```
$ docker run -d --name thumbor3 -e VIRTUAL_HOST=foo.example.com thumbor-centos 
6f933fdd9948a0793788c4d15088ba5c298b5d6606ee7c57a982e8de9b044b4e
```

これで

```nginx
upstream foo.example.com {
			# thumbor3
			server 172.17.0.2:8000;
}
server {
	server_name foo.example.com;
	listen 80 ;
	access_log /var/log/nginx/access.log vhost;
	location / {
		proxy_pass http://foo.example.com;
	}
}
```

が default.conf に追加されました。 `docker logs nginx` でログを確認してみます

```
$ docker logs nginx
forego     | starting nginx.1 on port 5000
forego     | starting dockergen.1 on port 5100
dockergen.1 | 2016/02/01 15:02:40 Generated '/etc/nginx/conf.d/default.conf' from 3 containers
dockergen.1 | 2016/02/01 15:02:40 Running 'nginx -s reload'
dockergen.1 | 2016/02/01 15:02:40 Watching docker events
dockergen.1 | 2016/02/01 15:16:46 Received event die for container 4930455aadf4
dockergen.1 | 2016/02/01 15:16:46 Generated '/etc/nginx/conf.d/default.conf' from 2 containers
dockergen.1 | 2016/02/01 15:16:46 Running 'nginx -s reload'
dockergen.1 | 2016/02/01 15:16:46 Received event stop for container 4930455aadf4
dockergen.1 | 2016/02/01 15:16:46 Contents of /etc/nginx/conf.d/default.conf did not change. Skipping notification 'nginx -s reload'
dockergen.1 | 2016/02/01 15:19:35 Received event start for container 6f933fdd9948
dockergen.1 | 2016/02/01 15:19:35 Generated '/etc/nginx/conf.d/default.conf' from 3 containers
dockergen.1 | 2016/02/01 15:19:35 Running 'nginx -s reload'
```

[forego](https://github.com/ddollar/forego) ってのが登場しました。
Foreman in Go だそうです。
nginx-proxy には [Procfile](https://github.com/jwilder/nginx-proxy/blob/master/Procfile) があって forego がこれを参照しているようです。
forego が nginx と docker-gen を起動させるようになっています。上の docker logs を見てもわかるように、どのプロセスが出力したメッセージかわかるように装飾してくれます。色までついています。docker のログを fluentd で処理したりするには不便ですが、目で見るには人に優しい感じです。
docker を動かすホストでログを fluentd で送る設定を動的に更新できる [https://github.com/jwilder/docker-gen/blob/master/templates/fluentd.conf.tmpl](https://github.com/jwilder/docker-gen/blob/master/templates/fluentd.conf.tmpl) も便利そうです。
