---
title: 'Nomad で Service Job を実行する'
date: Mon, 22 Apr 2019 15:13:41 +0000
draft: false
tags: ['Nomad', 'Nomad']
---

[前回](/2019/04/setup-nomad-cluster/) Nomad クラスタを構築しました。今回はこのクラスタで Job を実行します。

### nomad job init

[job init](https://www.nomadproject.io/docs/commands/job/init.html) コマンドを実行することでスケルトンファイルを生成することができます。

```
# nomad job init
Example job file written to example.nomad
```

これで `example.nomad` ファイルが生成されています。多くのコメントが含まれていますが、コメント行と空行を除くと次のようになっています。

```
# egrep -v '^ *#|^$' example.nomad
job "example" {
  datacenters = ["dc1"]
  type = "service"
  update {
    max_parallel = 1
    min_healthy_time = "10s"
    healthy_deadline = "3m"
    progress_deadline = "10m"
    auto_revert = false
    canary = 0
  }
  migrate {
    max_parallel = 1
    health_check = "checks"
    min_healthy_time = "10s"
    healthy_deadline = "5m"
  }
  group "cache" {
    count = 1
    restart {
      attempts = 2
      interval = "30m"
      delay = "15s"
      mode = "fail"
    }
    ephemeral_disk {
      size = 300
    }

    task "redis" {
      driver = "docker"
      config {
        image = "redis:3.2"
        port_map {
          db = 6379
        }
      }
      resources {
        cpu    = 500 # 500 MHz
        memory = 256 # 256MB
        network {
          mbits = 10
          port "db" {}
        }
      }
      service {
        name = "redis-cache"
        tags = ["global", "cache"]
        port = "db"
        check {
          name     = "alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
```

* `type = "servie"` ですからどこかの node でずっと動かすプロセスを起動させます。
* 実行するのは `task "redis"` 内にあり、`driver = "docker"` で `image = "redis:3.2"` を実行します。
* `group "cache"` で `count = 1` と指定されているので1コンテナを維持します。
* `[resources](https://www.nomadproject.io/docs/job-specification/resources.html)` 内でこの Task を実行するのに必要なリソースを指定してあります。port は固定した場合にその port が使用可能な node が選択されます。`port "db" {}` は動的割り当てを意味します。転送先は `config` の `port_map` で定義されています。
* `[update](https://www.nomadproject.io/docs/job-specification/update.html)` 設定ではローリングアップデートやカナリアリリースのための設定です。省略するとこれらの機能は無効になります。
* node を停止する場合などに task を別 node へ移動させますが、これに関する設定が `[migrate](https://www.nomadproject.io/docs/job-specification/migrate.html)` にあります。([Workload Migration](https://www.nomadproject.io/guides/operations/node-draining.html))

### nomad job run

`example.nomad` を実行してみます。

```
# nomad job run example.nomad
==> Monitoring evaluation "a1ebcac6"
    Evaluation triggered by job "example"
    Evaluation within deployment: "4f9cf929"
    Allocation "4fef9fed" created: node "4c1bbcfa", group "cache"
    Evaluation status changed: "pending" -> "complete"
==> Evaluation "a1ebcac6" finished with status "complete"
```

```
# nomad status example
ID            = example
Name          = example
Submit Date   = 2019-04-22T12:55:16Z
Type          = service
Priority      = 50
Datacenters   = dc1
Status        = running
Periodic      = false
Parameterized = false

Summary
Task Group  Queued  Starting  Running  Failed  Complete  Lost
cache       0       0         1        0       0         0

Latest Deployment
ID          = 4f9cf929
Status      = running
Description = Deployment is running

Deployed
Task Group  Desired  Placed  Healthy  Unhealthy  Progress Deadline
cache       1        1       0        0          2019-04-22T13:05:16Z

Allocations
ID        Node ID   Task Group  Version  Desired  Status   Created  Modified
4fef9fed  4c1bbcfa  cache       0        run      running  17s ago  7s ago
```

Allocations にある ID を指定して [nomad alloc status](https://www.nomadproject.io/docs/commands/alloc/status.html) コマンドを実行すると次のような情報を確認することができます。

```
# nomad alloc status 4fef9fed
ID                  = 4fef9fed
Eval ID             = a1ebcac6
Name                = example.cache[0]
Node ID             = 4c1bbcfa
Job ID              = example
Job Version         = 0
Client Status       = running
Client Description  = Tasks are running
Desired Status      = run
Desired Description = Created             = 1h4m ago
Modified            = 1h4m ago
Deployment ID       = 4f9cf929
Deployment Health   = healthy

Task "redis" is "running"
Task Resources
CPU        Memory           Disk     Addresses
3/500 MHz  6.3 MiB/256 MiB  300 MiB  db: 68.183.xxx.xxx:23800

Task Events:
Started At     = 2019-04-22T12:55:27Z
Finished At    = N/A
Total Restarts = 0
Last Restart   = N/A

Recent Events:
Time                  Type        Description
2019-04-22T12:55:27Z  Started     Task started by client
2019-04-22T12:55:16Z  Driver      Downloading image
2019-04-22T12:55:16Z  Task Setup  Building Task Directory
2019-04-22T12:55:16Z  Received    Task received by client 
```

[nomad alloc logs](https://www.nomadproject.io/docs/commands/alloc/logs.html) コマンドでログを確認することができます。

```
# nomad alloc logs 4fef9fed
1:C 22 Apr 12:55:27.013 # Warning: no config file specified, using the default config. In order to specify a config file use redis-server /path/to/redis.conf
                _._
           _.-``__ ''-._
      _.-``    `.  `_.  ''-._           Redis 3.2.12 (00000000/0) 64 bit
  .-`` .-```.  ```\/    _.,_ ''-._
 (    '      ,       .-`  | `,    )     Running in standalone mode
 |`-._`-...-` __...-.``-._|'` _.-'|     Port: 6379
 |    `-._   `._    /     _.-'    |     PID: 1
  `-._    `-._  `-./  _.-'    _.-'
 |`-._`-._    `-.__.-'    _.-'_.-'|
 |    `-._`-._        _.-'_.-'    |           http://redis.io
  `-._    `-._`-.__.-'_.-'    _.-'
 |`-._`-._    `-.__.-'    _.-'_.-'|
 |    `-._`-._        _.-'_.-'    |
  `-._    `-._`-.__.-'_.-'    _.-'
      `-._    `-.__.-'    _.-'
          `-._        _.-'
              `-.__.-'
...
```

docker コマンドで確認してみます。

```
$ sudo docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                                                            NAMES
749c8f2f23bb        redis:3.2           "docker-entrypoint..."   9 minutes ago       Up 9 minutes        68.183.xxx.xxx:23800->6379/tcp, 68.183.xxx.xxx:23800->6379/udp   redis-4fef9fed-d03e-cbac-d480-8f4d4bc45ecb
```

```
$ sudo docker inspect 749c8f2f23bb
[
    {
        "Id": "749c8f2f23bb662ac3f7ddc03cf212281732d3bb06bbc14d2d493ccb640d8b21",
        "Created": "2019-04-22T12:55:26.242480047Z",
        "Path": "docker-entrypoint.sh",
        "Args": [
            "redis-server"
        ],
        "State": {
            "Status": "running",
            "Running": true,
            "Paused": false,
            "Restarting": false,
            "OOMKilled": false,
            "Dead": false,
            "Pid": 16282,
            "ExitCode": 0,
            "Error": "",
            "StartedAt": "2019-04-22T12:55:26.847576628Z",
            "FinishedAt": "0001-01-01T00:00:00Z"
        },
        "Image": "sha256:87856cc39862cec77541d68382e4867d7ccb29a85a17221446c857ddaebca916",
        "ResolvConfPath": "/var/lib/docker/containers/749c8f2f23bb662ac3f7ddc03cf212281732d3bb06bbc14d2d493ccb640d8b21/resolv.conf",
        "HostnamePath": "/var/lib/docker/containers/749c8f2f23bb662ac3f7ddc03cf212281732d3bb06bbc14d2d493ccb640d8b21/hostname",
        "HostsPath": "/var/lib/docker/containers/749c8f2f23bb662ac3f7ddc03cf212281732d3bb06bbc14d2d493ccb640d8b21/hosts",
        "LogPath": "",
        "Name": "/redis-4fef9fed-d03e-cbac-d480-8f4d4bc45ecb",
        "RestartCount": 0,
        "Driver": "overlay2",
        "MountLabel": "system_u:object_r:svirt_sandbox_file_t:s0:c198,c202",
        "ProcessLabel": "system_u:system_r:svirt_lxc_net_t:s0:c198,c202",
        "AppArmorProfile": "",
        "ExecIDs": null,
        "HostConfig": {
            "Binds": [
                "/opt/nomad/alloc/4fef9fed-d03e-cbac-d480-8f4d4bc45ecb/alloc:/alloc",
                "/opt/nomad/alloc/4fef9fed-d03e-cbac-d480-8f4d4bc45ecb/redis/local:/local",
                "/opt/nomad/alloc/4fef9fed-d03e-cbac-d480-8f4d4bc45ecb/redis/secrets:/secrets"
            ],
            "ContainerIDFile": "",
            "LogConfig": {
                "Type": "journald",
                "Config": {}
            },
            "NetworkMode": "bridge",
            "PortBindings": {
                "6379/tcp": [
                    {
                        "HostIp": "68.183.xxx.xxx",
                        "HostPort": "23800"
                    }
                ],
                "6379/udp": [
                    {
                        "HostIp": "68.183.xxx.xxx",
                        "HostPort": "23800"
                    }
                ]
            },
            "RestartPolicy": {
                "Name": "",
                "MaximumRetryCount": 0
            },
            "AutoRemove": false,
            "VolumeDriver": "",
            "VolumesFrom": null,
            "CapAdd": null,
            "CapDrop": null,
            "Dns": null,
            "DnsOptions": null,
            "DnsSearch": null,
            "ExtraHosts": null,
            "GroupAdd": null,
            "IpcMode": "",
            "Cgroup": "",
            "Links": null,
            "OomScoreAdj": 0,
            "PidMode": "",
            "Privileged": false,
            "PublishAllPorts": false,
            "ReadonlyRootfs": false,
            "SecurityOpt": null,
            "UTSMode": "",
            "UsernsMode": "",
            "ShmSize": 67108864,
            "Runtime": "docker-runc",
            "ConsoleSize": [
                0,
                0
            ],
            "Isolation": "",
            "CpuShares": 500,
            "Memory": 268435456,
            "NanoCpus": 0,
            "CgroupParent": "",
            "BlkioWeight": 0,
            "BlkioWeightDevice": null,
            "BlkioDeviceReadBps": null,
            "BlkioDeviceWriteBps": null,
            "BlkioDeviceReadIOps": null,
            "BlkioDeviceWriteIOps": null,
            "CpuPeriod": 0,
            "CpuQuota": 0,
            "CpuRealtimePeriod": 0,
            "CpuRealtimeRuntime": 0,
            "CpusetCpus": "",
            "CpusetMems": "",
            "Devices": null,
            "DiskQuota": 0,
            "KernelMemory": 0,
            "MemoryReservation": 0,
            "MemorySwap": 268435456,
            "MemorySwappiness": -1,
            "OomKillDisable": false,
            "PidsLimit": 0,
            "Ulimits": null,
            "CpuCount": 0,
            "CpuPercent": 0,
            "IOMaximumIOps": 0,
            "IOMaximumBandwidth": 0
        },
        "GraphDriver": {
            "Name": "overlay2",
            "Data": {
                "LowerDir": "/var/lib/docker/overlay2/74aca4e9bfab9d8e9a4cf278f5ef8f7e1631b10f1367fb50832c1b9763f450d2-init/diff:/var/lib/docker/overlay2/595ed0c413560d4b9e7167b9283704a2b04bb1e0704d7b9e92a8ab71789c79c6/diff:/var/lib/docker/overlay2/b3ce76020c10eb942c5e8166860c190b240e539a70271eddaec4a92fac947f07/diff:/var/lib/docker/overlay2/fc8771b79bcdb2806e86fb5f4510a8b3aed84a7ce33f2e2a252f7a0bb17fd42a/diff:/var/lib/docker/overlay2/345168c12d66c16cbdf0d6895741cfd2e727e2b31850d784d3ca3418b9d2d7cc/diff:/var/lib/docker/overlay2/1ffa8ff2fbc5f980e89308e6213d81470d816de9fb05dae8460842516a2efc1c/diff:/var/lib/docker/overlay2/77a0bab9ba43a0e0d426a9dee1751c6c5f280da21748012b691b4ef5c45335b9/diff",
                "MergedDir": "/var/lib/docker/overlay2/74aca4e9bfab9d8e9a4cf278f5ef8f7e1631b10f1367fb50832c1b9763f450d2/merged",
                "UpperDir": "/var/lib/docker/overlay2/74aca4e9bfab9d8e9a4cf278f5ef8f7e1631b10f1367fb50832c1b9763f450d2/diff",
                "WorkDir": "/var/lib/docker/overlay2/74aca4e9bfab9d8e9a4cf278f5ef8f7e1631b10f1367fb50832c1b9763f450d2/work"
            }
        },
        "Mounts": [
            {
                "Type": "bind",
                "Source": "/opt/nomad/alloc/4fef9fed-d03e-cbac-d480-8f4d4bc45ecb/alloc",
                "Destination": "/alloc",
                "Mode": "",
                "RW": true,
                "Propagation": "rprivate"
            },
            {
                "Type": "bind",
                "Source": "/opt/nomad/alloc/4fef9fed-d03e-cbac-d480-8f4d4bc45ecb/redis/local",
                "Destination": "/local",
                "Mode": "",
                "RW": true,
                "Propagation": "rprivate"
            },
            {
                "Type": "bind",
                "Source": "/opt/nomad/alloc/4fef9fed-d03e-cbac-d480-8f4d4bc45ecb/redis/secrets",
                "Destination": "/secrets",
                "Mode": "",
                "RW": true,
                "Propagation": "rprivate"
            },
            {
                "Type": "volume",
                "Name": "0ac66640f3e7fd443ed25809edd9a20b63174f40c0927f53e2d3164838bcd06b",
                "Source": "/var/lib/docker/volumes/0ac66640f3e7fd443ed25809edd9a20b63174f40c0927f53e2d3164838bcd06b/_data",
                "Destination": "/data",
                "Driver": "local",
                "Mode": "",
                "RW": true,
                "Propagation": ""
            }
        ],
        "Config": {
            "Hostname": "749c8f2f23bb",
            "Domainname": "",
            "User": "",
            "AttachStdin": false,
            "AttachStdout": false,
            "AttachStderr": false,
            "ExposedPorts": {
                "6379/tcp": {},
                "6379/udp": {}
            },
            "Tty": false,
            "OpenStdin": false,
            "StdinOnce": false,
            "Env": [
                "NOMAD_ADDR_db=68.183.xxx.xxx:23800",
                "NOMAD_ALLOC_DIR=/alloc",
                "NOMAD_ALLOC_ID=4fef9fed-d03e-cbac-d480-8f4d4bc45ecb",
                "NOMAD_ALLOC_INDEX=0",
                "NOMAD_ALLOC_NAME=example.cache[0]",
                "NOMAD_CPU_LIMIT=500",
                "NOMAD_DC=dc1",
                "NOMAD_GROUP_NAME=cache",
                "NOMAD_HOST_PORT_db=23800",
                "NOMAD_IP_db=68.183.xxx.xxx",
                "NOMAD_JOB_NAME=example",
                "NOMAD_MEMORY_LIMIT=256",
                "NOMAD_PORT_db=23800",
                "NOMAD_REGION=global",
                "NOMAD_SECRETS_DIR=/secrets",
                "NOMAD_TASK_DIR=/local",
                "NOMAD_TASK_NAME=redis",
                "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
                "GOSU_VERSION=1.10",
                "REDIS_VERSION=3.2.12",
                "REDIS_DOWNLOAD_URL=http://download.redis.io/releases/redis-3.2.12.tar.gz",
                "REDIS_DOWNLOAD_SHA=98c4254ae1be4e452aa7884245471501c9aa657993e0318d88f048093e7f88fd"
            ],
            "Cmd": [
                "redis-server"
            ],
            "ArgsEscaped": true,
            "Image": "redis:3.2",
            "Volumes": {
                "/data": {}
            },
            "WorkingDir": "/data",
            "Entrypoint": [
                "docker-entrypoint.sh"
            ],
            "OnBuild": null,
            "Labels": {}
        },
        "NetworkSettings": {
            "Bridge": "",
            "SandboxID": "5e94da3afc88eff1fd99102d762a81e861bf0ec5764850a746788fc1b4f10549",
            "HairpinMode": false,
            "LinkLocalIPv6Address": "",
            "LinkLocalIPv6PrefixLen": 0,
            "Ports": {
                "6379/tcp": [
                    {
                        "HostIp": "68.183.xxx.xxx",
                        "HostPort": "23800"
                    }
                ],
                "6379/udp": [
                    {
                        "HostIp": "68.183.xxx.xxx",
                        "HostPort": "23800"
                    }
                ]
            },
            "SandboxKey": "/var/run/docker/netns/5e94da3afc88",
            "SecondaryIPAddresses": null,
            "SecondaryIPv6Addresses": null,
            "EndpointID": "46921b2b1d86852e283570ac5fb3d0c0ac1305de8939dce3a707cbaf7d57bef0",
            "Gateway": "172.17.0.1",
            "GlobalIPv6Address": "",
            "GlobalIPv6PrefixLen": 0,
            "IPAddress": "172.17.0.2",
            "IPPrefixLen": 16,
            "IPv6Gateway": "",
            "MacAddress": "02:42:ac:11:00:02",
            "Networks": {
                "bridge": {
                    "IPAMConfig": null,
                    "Links": null,
                    "Aliases": null,
                    "NetworkID": "34694538c86fc73431d4e1f42c0d84708ebb6c69b4fb3eb19183f7e5f4a7da67",
                    "EndpointID": "46921b2b1d86852e283570ac5fb3d0c0ac1305de8939dce3a707cbaf7d57bef0",
                    "Gateway": "172.17.0.1",
                    "IPAddress": "172.17.0.2",
                    "IPPrefixLen": 16,
                    "IPv6Gateway": "",
                    "GlobalIPv6Address": "",
                    "GlobalIPv6PrefixLen": 0,
                    "MacAddress": "02:42:ac:11:00:02"
                }
            }
        }
    }
]
```

### Modifying a Job

次は Job の変更です。`example.nomad` ファイルを編集して `group "cache"` 内の `count` を 1 から 3 に変更してみます。

編集したら `nomad job plan` コマンドで差分を確認します。同じ Hashicorp 製の Terraform っぽいですね。

```
# nomad job plan example.nomad
+/- Job: "example"
+/- Task Group: "cache" (2 create, 1 in-place update)
  +/- Count: "1" => "3" (forces create)
      Task: "redis"

Scheduler dry-run:
- All tasks successfully allocated.

Job Modify Index: 49
To submit the job with version verification run:

nomad job run -check-index 49 example.nomad

When running the job with the check-index flag, the job will only be run if the
server side version matches the job modify index returned. If the index has
changed, another user has modified the job and the plan's results are
potentially invalid.
```

nomad job run コマンドで適用します。`-check-index` を指定することで、サーバー側でバージョンが一致していないと適用されないようにします。plan で確認した後に別の変更が入っていたら適用されないということになります。

```
# nomad job run -check-index 49 example.nomad
==> Monitoring evaluation "2e842c28"
    Evaluation triggered by job "example"
    Evaluation within deployment: "e300014c"
    Allocation "f5abe160" created: node "623aadcd", group "cache"
    Allocation "4fef9fed" modified: node "4c1bbcfa", group "cache"
    Allocation "be184b8e" created: node "2bb2e01c", group "cache"
    Evaluation status changed: "pending" -> "complete"
==> Evaluation "2e842c28" finished with status "complete"
```

nomad job status コマンドで allocation (コンテナ) が 3 つになっていることが確認できます。

```
# nomad job status example
ID            = example
Name          = example
Submit Date   = 2019-04-22T14:16:07Z
Type          = service
Priority      = 50
Datacenters   = dc1
Status        = running
Periodic      = false
Parameterized = false

Summary
Task Group  Queued  Starting  Running  Failed  Complete  Lost
cache       0       0         3        0       0         0

Latest Deployment
ID          = e300014c
Status      = successful
Description = Deployment completed successfully

Deployed
Task Group  Desired  Placed  Healthy  Unhealthy  Progress Deadline
cache       3        3       3        0          2019-04-22T14:26:31Z

Allocations
ID        Node ID   Task Group  Version  Desired  Status   Created    Modified
be184b8e  2bb2e01c  cache       1        run      running  3m27s ago  3m7s ago
f5abe160  623aadcd  cache       1        run      running  3m27s ago  3m2s ago
4fef9fed  4c1bbcfa  cache       1        run      running  1h24m ago  3m16s ago
```

次にアプリケーションの更新として redis イメージのバージョンを変更します。`image = "redis:3.2"` を `image = "redis:4.0"` にします。

```
# nomad job plan example.nomad
+/- Job: "example"
+/- Task Group: "cache" (1 create/destroy update, 2 ignore)
  +/- Task: "redis" (forces create/destroy update)
    +/- Config {
      +/- image:           "redis:3.2" => "redis:4.0"
          port_map[0][db]: "6379"
        }

Scheduler dry-run:
- All tasks successfully allocated.

Job Modify Index: 141
To submit the job with version verification run:

nomad job run -check-index 141 example.nomad

When running the job with the check-index flag, the job will only be run if the
server side version matches the job modify index returned. If the index has
changed, another user has modified the job and the plan's results are
potentially invalid.
```

1つの task だけ更新して2つはそのままだと表示されています。これは [update](https://www.nomadproject.io/docs/job-specification/update.html) 設定で `max_parallel = 1` となっているためで、1つずつ順に更新されます。

```
# nomad job run -check-index 141 example.nomad
==> Monitoring evaluation "f143cc8c"
    Evaluation triggered by job "example"
    Evaluation within deployment: "7459aa07"
    Allocation "80f319e8" created: node "623aadcd", group "cache"
    Evaluation status changed: "pending" -> "complete"
==> Evaluation "f143cc8c" finished with status "complete"
```

この後、待っていると順に3つ更新されて、完了後は次のようになりました。

```
# nomad job status example
ID            = example
Name          = example
Submit Date   = 2019-04-22T14:30:29Z
Type          = service
Priority      = 50
Datacenters   = dc1
Status        = running
Periodic      = false
Parameterized = false

Summary
Task Group  Queued  Starting  Running  Failed  Complete  Lost
cache       0       0         3        0       3         0

Latest Deployment
ID          = 7459aa07
Status      = successful
Description = Deployment completed successfully

Deployed
Task Group  Desired  Placed  Healthy  Unhealthy  Progress Deadline
cache       3        3       3        0          2019-04-22T14:41:45Z

Allocations
ID        Node ID   Task Group  Version  Desired  Status    Created     Modified
3ee0f6a7  4c1bbcfa  cache       2        run      running   34s ago     17s ago
ae380133  4c1bbcfa  cache       2        run      running   1m5s ago    36s ago
80f319e8  623aadcd  cache       2        run      running   1m32s ago   1m7s ago
be184b8e  2bb2e01c  cache       1        stop     complete  15m55s ago  34s ago
f5abe160  623aadcd  cache       1        stop     complete  15m55s ago  1m5s ago
4fef9fed  4c1bbcfa  cache       1        stop     complete  1h36m ago   1m32s ago
```

### GUI で確認

GUI で Jobs を開くとまずこの画面で Job の一覧が表示されます  

{{< figure src="nomad-example-job.png" caption="Jobs" >}}

Overview ページはこんな感じ  
{{< figure src="nomad-example-job-overview.png" caption="Overview" >}}

次に Definition で [nomad job inspect](https://www.nomadproject.io/docs/commands/job/inspect.html) コマンドの出力が確認できます  

{{< figure src="nomad-example-job-definition.png" caption="Definition" >}}

Versions では各 version 間での差分も確認できます  

{{< figure src="nomad-example-job-versions.png" caption="Version" >}}

Deployments でも各 version 時の deployment が確認できます  

{{< figure src="nomad-example-job-deployments.png" caption="Deployments" >}}

Allocations で task の配置が確認できますが、これは Overview でも見れますね  

{{< figure src="nomad-example-job-allocations.png" caption="Allocations" >}}

Evaluations は何だかまだよく知らない  

{{< figure src="nomad-example-job-evaluations.png" caption="Evaluations" >}}

Client 画面では Worker node のホスト情報が確認できます。CPU と Memory はリアルタイムにグラフ表示されます  

{{< figure src="nomad-client.png" caption="Client" >}}

### Stopping a Job

Job を停止します。GUI にも Stop ボタンがありますが [nomad job stop](https://www.nomadproject.io/docs/commands/job/stop.html) コマンドを実行します。

```
# nomad job stop example
==> Monitoring evaluation "858e1662"
    Evaluation triggered by job "example"
    Evaluation within deployment: "7459aa07"
    Evaluation status changed: "pending" -> "complete"
==> Evaluation "858e1662" finished with status "complete"
```

停止されました。

```
# nomad status example
ID            = example
Name          = example
Submit Date   = 2019-04-22T14:30:29Z
Type          = service
Priority      = 50
Datacenters   = dc1
Status        = dead (stopped)
Periodic      = false
Parameterized = false

Summary
Task Group  Queued  Starting  Running  Failed  Complete  Lost
cache       0       0         0        0       6         0

Latest Deployment
ID          = 7459aa07
Status      = successful
Description = Deployment completed successfully

Deployed
Task Group  Desired  Placed  Healthy  Unhealthy  Progress Deadline
cache       3        3       3        0          2019-04-22T14:41:45Z

Allocations
ID        Node ID   Task Group  Version  Desired  Status    Created     Modified
3ee0f6a7  4c1bbcfa  cache       2        stop     complete  28m4s ago   3m32s ago
ae380133  4c1bbcfa  cache       2        stop     complete  28m35s ago  3m32s ago
80f319e8  623aadcd  cache       2        stop     complete  29m2s ago   3m32s ago
be184b8e  2bb2e01c  cache       1        stop     complete  43m25s ago  28m4s ago
f5abe160  623aadcd  cache       1        stop     complete  43m25s ago  28m35s ago
4fef9fed  4c1bbcfa  cache       1        stop     complete  2h4m ago    29m2s ago
```

GUI の Versions で確認すると Stop が false から true に変化していました。

```
+/- Job: "example"
+/- Stop:	"false" => "true"
    Task Group: "cache"
      Task: "redis"
```

停止した Job を再開するには `nomad job run example.nomad` すれば良いですし、plan で確認することもできます。

```
# nomad job plan example.nomad
+/- Job: "example"
+/- Stop: "true" => "false"
    Task Group: "cache" (3 create)
      Task: "redis"

Scheduler dry-run:
- All tasks successfully allocated.

Job Modify Index: 229
To submit the job with version verification run:

nomad job run -check-index 229 example.nomad

When running the job with the check-index flag, the job will only be run if the
server side version matches the job modify index returned. If the index has
changed, another user has modified the job and the plan's results are
potentially invalid.
```

以上、[Getting Started の Jobs](https://www.nomadproject.io/intro/getting-started/jobs.html) の内容でした。Job の種類が **Service** の他に **Batch** と **System** がありますが、**Service** でできることをもう少し確認したいですね。
