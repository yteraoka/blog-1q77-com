---
title: 'Docker 1.12-RC3 の HEALTHCHECK を試す'
date: Tue, 05 Jul 2016 16:09:40 +0000
draft: false
tags: ['Docker', 'Docker', 'Swarm', 'Swarm']
---

2016年7月14日にリリースされる予定の Docker 1.12 ですが RC3 に HEALTHCHECK 機能が入ったようなのでこれを試してみます。（1.12 のその他の目玉機能は[Docker 1.12 の衝撃](http://www.slideshare.net/yteraoka1/docker-112) \[slideshare\] をどうぞ） [https://github.com/docker/docker/releases/tag/v1.12.0-rc3](https://github.com/docker/docker/releases/tag/v1.12.0-rc3)

> New HEALTHCHECK Dockerfile instruction to support user-defined healthchecks [#23218](https://github.com/docker/docker/pull/23218)

RC版のインストールも簡単で```
curl -fsSL https://test.docker.com/ | sh
```だけ。 バージョン情報はこちら```
Client:
 Version:      1.12.0-rc3
 API version:  1.24
 Go version:   go1.6.2
 Git commit:   91e29e8
 Built:        Sat Jul  2 00:28:53 2016
 OS/Arch:      linux/amd64

Server:
 Version:      1.12.0-rc3
 API version:  1.24
 Go version:   go1.6.2
 Git commit:   91e29e8
 Built:        Sat Jul  2 00:28:53 2016
 OS/Arch:      linux/amd64
```[DigitalOcean](https://m.do.co/c/97e74a2e7336) を使って3台の swarm mode cluster をセットアップします。```
root@docker01:~# docker swarm init --listen-addr 10.130.13.161
Swarm initialized: current node (8a0gb55owih94q8lwum4b61us) is now a manager.

root@docker02:~# docker swarm join --listen-addr 10.130.27.157 10.130.13.161
This node joined a Swarm as a worker.

root@docker03:~# docker swarm join --listen-addr 10.130.44.213 10.130.13.161
This node joined a Swarm as a worker.

root@docker01:~# docker node ls
ID                           HOSTNAME  MEMBERSHIP  STATUS  AVAILABILITY  MANAGER STATUS
3tv5prg22lgebh0rvjp8gu4o4    docker03  Accepted    Ready   Active        
8a0gb55owih94q8lwum4b61us \*  docker01  Accepted    Ready   Active        Leader
ciezynqpmqa9ok5egpuf2sdjy    docker02  Accepted    Ready   Active
```簡単ですねぇ、たったこれだけで3台のクラスタができちゃいます。 （あら？worker node って RC2 の時から auto accept だったっけ？） テストにあたって nginx:1.11.1-alpine をベースに HEALTHCHECK の有効な docker image を build してみます。 まず、healthcheck.sh というスクリプトを準備```
#!/bin/sh

status=\`curl -so /dev/null -w %{http\_code} http://127.0.0.1/healthcheck\`
if \[ $? -eq 0 -a "$status" = "200" \] ; then
    exit 0
else
    exit 1
fi
```healthcheck コマンドは OK の場合は 0、NG の場合は 1 で終了させます。起動中の場合は 2 で終了させますが、一度 healthy となった後は 1 も 2 も同じです。 このスクリプトでは nginx に GET /healthcheck でテストします。初期状態ではこの URL は 404 となるため 1 で終了します。 次に Dockerfile を準備```
FROM nginx:1.11.1-alpine
COPY healthcheck.sh /
RUN apk update && apk add curl && chmod 755 /healthcheck.sh
HEALTHCHECK --interval=5s --timeout=3s --retries=1 CMD /healthcheck.sh
```大事なのは `HEALTHCHECK --interval=5s --timeout=3s --retries=1 CMD /healthcheck.sh` の部分ですね。5秒おきに /healthcheck.sh が実行されます。ポートへの connect だけの確認であれば `HEALTHCHECK CONNECT TCP 7000` という書き方もできるようです。interval や timeout, retries は省略可能。 build して Docker Hub にアップロードします```
root@docker01:~# docker build --tag yteraoka/nginx-healthcheck .
root@docker01:~# docker login
root@docker01:~# docker push yteraoka/nginx-healthcheck
```docker image の準備ができたところでコンテナ3つを維持するように service を起動させます```
root@docker01:~# docker service create --name nginx --replicas 3 -p 80 yteraoka/nginx-healthcheck
7dxakcqlnsqcoq4g9sqq6qyvc

root@docker01:~# docker service ls
ID            NAME   REPLICAS  IMAGE                       COMMAND
7dxakcqlnsqc  nginx  3/3       yteraoka/nginx-healthcheck  

root@docker01:~# docker service tasks nginx
ID                         NAME     SERVICE  IMAGE                       LAST STATE              DESIRED STATE  NODE
0qwcjtu4pni4i5r8qn37d6nj4  nginx.1  nginx    yteraoka/nginx-healthcheck  Running About a minute  Running        docker01
9ajup0heqn1i9j894ntn7e17j  nginx.2  nginx    yteraoka/nginx-healthcheck  Running About a minute  Running        docker03
0zbp7nniwimnj89v3f2d3i644  nginx.3  nginx    yteraoka/nginx-healthcheck  Running About a minute  Running        docker02
```あら簡単！ healthcheck が機能しているかどうかログを確認します```
root@docker01:~# docker ps
CONTAINER ID        IMAGE                               COMMAND                  CREATED              STATUS                          PORTS               NAMES
ac6a04048f48        yteraoka/nginx-healthcheck:latest   "nginx -g 'daemon off"   About a minute ago   Up About a minute (unhealthy)   80/tcp, 443/tcp     nginx.1.4t4708e2hhijpk3i0oh6udoav

root@docker01:~# docker logs --tail 5 ac6a04048f48
127.0.0.1 - - \[05/Jul/2016:14:21:46 +0000\] "GET /healthcheck HTTP/1.1" 404 169 "-" "curl/7.49.1" "-"
2016/07/05 14:21:51 \[error\] 6#6: \*22 open() "/usr/share/nginx/html/healthcheck" failed (2: No such file or directory), client: 127.0.0.1, server: localhost, request: "GET /healthcheck HTTP/1.1", host: "127.0.0.1"
127.0.0.1 - - \[05/Jul/2016:14:21:51 +0000\] "GET /healthcheck HTTP/1.1" 404 169 "-" "curl/7.49.1" "-"
2016/07/05 14:21:56 \[error\] 6#6: \*23 open() "/usr/share/nginx/html/healthcheck" failed (2: No such file or directory), client: 127.0.0.1, server: localhost, request: "GET /healthcheck HTTP/1.1", host: "127.0.0.1"
127.0.0.1 - - \[05/Jul/2016:14:21:56 +0000\] "GET /healthcheck HTTP/1.1" 404 169 "-" "curl/7.49.1" "-"
```404 だから unhealthy のはずですね。さて、これはサービスにどう影響するのでしょう？ 期待としては unhealthy の状態では Load Balancer のメンバーに組み込まれないという状態ですが・・・ わかりやすいように /index.html にそれぞれ docker01, docker02, docker03 を書き込みます。 `docker exec -it ... /bin/sh` で `echo docker01 > /usr/share/nginx/html/index.html` てな具合に。 それから Load Balancer のポート番号を確認```
root@docker01:~# docker service inspect nginx -f '{{range .Endpoint.Ports}}{{.PublishedPort}}{{end}}'
30000
```30000 番なので http://localhost:30000/ に何度かアクセスしてみると```
root@docker01:~# curl http://localhost:30000/
docker02
root@docker01:~# curl http://localhost:30000/
docker03
root@docker01:~# curl http://localhost:30000/
docker01
root@docker01:~# curl http://localhost:30000/
docker02
root@docker01:~# curl http://localhost:30000/
docker03
root@docker01:~#
```あれ？3つとも有効になってるぞ 1つでも healthy にしてみたらなにか変わるだろうか？また docker exec で touch /usr/share/nginx/html/healthcheck して再度 curl で 30000 番にアクセスしてみるも変化なし おやおや？期待の動作じゃありませんね `docker inspect` で healthcheck の状態が確認できるようなので試してみます healthy な場合```
root@docker01:~# docker ps
CONTAINER ID        IMAGE                               COMMAND                  CREATED             STATUS                   PORTS               NAMES
ac6a04048f48        yteraoka/nginx-healthcheck:latest   "nginx -g 'daemon off"   9 minutes ago       Up 9 minutes (healthy)   80/tcp, 443/tcp     nginx.1.4t4708e2hhijpk3i0oh6udoav
root@docker01:~# docker inspect -f {{.State.Health.Status}} ac6a04048f48
healthy
root@docker01:~# docker inspect -f '{{json .State.Health}}' ac6a04048f48
{
  "Status":"healthy",
  "FailingStreak":0,
  "Log":\[
    {
      "Start":"2016-07-05T10:30:19.247502323-04:00",
      "End":"2016-07-05T10:30:19.300936843-04:00",
      "ExitCode":0,
      "Output":""
    },
    {
      "Start":"2016-07-05T10:30:24.301484104-04:00",
      "End":"2016-07-05T10:30:24.386685529-04:00",
      "ExitCode":0,
      "Output":""
    },
    {
      "Start":"2016-07-05T10:30:29.387079189-04:00",
      "End":"2016-07-05T10:30:29.468869919-04:00",
      "ExitCode":0,
      "Output":""
    },
    {
      "Start":"2016-07-05T10:30:34.469089038-04:00",
      "End":"2016-07-05T10:30:34.545193782-04:00",
      "ExitCode":0,
      "Output":""
    },
    {
      "Start":"2016-07-05T10:30:39.545724519-04:00",
      "End":"2016-07-05T10:30:39.621370916-04:00",
      "ExitCode":0,
      "Output":""
    }
  \]
}
root@docker01:~#
```unhealthy な場合```
root@docker02:~# docker ps
CONTAINER ID        IMAGE                               COMMAND                  CREATED             STATUS                     PORTS               NAMES
5c20b551e3b9        yteraoka/nginx-healthcheck:latest   "nginx -g 'daemon off"   9 minutes ago       Up 9 minutes (unhealthy)   80/tcp, 443/tcp     nginx.2.8bvv14ynpt9wvnruo6oukoy5u
root@docker02:~# docker inspect -f {{.State.Health.Status}} 5c20b551e3b9
unhealthy
root@docker02:~# docker inspect -f '{{json .State.Health}}' 5c20b551e3b9
{
  "Status":"unhealthy",
  "FailingStreak":122,
  "Log":\[
    {
      "Start":"2016-07-05T10:29:58.986077293-04:00",
      "End":"2016-07-05T10:29:59.074625863-04:00",
      "ExitCode":1,
      "Output":""
    },
    {
      "Start":"2016-07-05T10:30:04.075129735-04:00",
      "End":"2016-07-05T10:30:04.160529007-04:00",
      "ExitCode":1,
      "Output":""
    },
    {
      "Start":"2016-07-05T10:30:09.160904985-04:00",
      "End":"2016-07-05T10:30:09.253501465-04:00",
      "ExitCode":1,
      "Output":""
    },
    {
      "Start":"2016-07-05T10:30:14.253976633-04:00",
      "End":"2016-07-05T10:30:14.32434033-04:00",
      "ExitCode":1,
      "Output":""
    },
    {
      "Start":"2016-07-05T10:30:19.324644872-04:00",
      "End":"2016-07-05T10:30:19.395827854-04:00",
      "ExitCode":1,
      "Output":""
    }
  \]
}
root@docker02:~#
```healthcheck 自体は機能しているが、現状はまだこれによて Load Balancer の状態に反映されたりはしないようだ。コード読めってことですね、はい。 event としては通知されます。ドキュメントにもまだ event のことしか書かれていない。`docker events` コマンドで event を monitor できます。```
2016-07-05T11:32:19.612553558-04:00 container health\_status: unhealthy ac6a04048f488d66457edea65b168d5b51671cc9da9aab7a63719c78c6bb8d45 (com.docker.swarm.node.id=8a0gb55owih94q8lwum4b61us, com.docker.swarm.service.id=ecbqm2dd25ibcsf6fmwqbt6yl, com.docker.swarm.service.name=nginx, com.docker.swarm.task=, com.docker.swarm.task.id=4t4708e2hhijpk3i0oh6udoav, com.docker.swarm.task.name=nginx.1, image=yteraoka/nginx-healthcheck:latest, name=nginx.1.4t4708e2hhijpk3i0oh6udoav)

2016-07-05T11:32:29.796809926-04:00 container health\_status: healthy ac6a04048f488d66457edea65b168d5b51671cc9da9aab7a63719c78c6bb8d45 (com.docker.swarm.node.id=8a0gb55owih94q8lwum4b61us, com.docker.swarm.service.id=ecbqm2dd25ibcsf6fmwqbt6yl, com.docker.swarm.service.name=nginx, com.docker.swarm.task=, com.docker.swarm.task.id=4t4708e2hhijpk3i0oh6udoav, com.docker.swarm.task.name=nginx.1, image=yteraoka/nginx-healthcheck:latest, name=nginx.1.4t4708e2hhijpk3i0oh6udoav)
````docker run` にも `--health-cmd`, `--health-interval`, `--health-retries`, `--health-timeout`, `--no-healthcheck` というオプションが追加されています。 **※更新※** 1.12.0 では Service で HEALTHCHECK が FAIL すると、その TASK は停止させれら、新しく起動されるようになっています おまけ

**[Docker 1.12 の衝撃](//www.slideshare.net/yteraoka1/docker-112 "Docker 1.12 の衝撃")** from **[Yoshinori Teraoka](//www.slideshare.net/yteraoka1)**