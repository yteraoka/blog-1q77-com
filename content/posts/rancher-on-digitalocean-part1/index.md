---
title: 'DigitalOcean にて Rancher を試す - その1'
date: Thu, 12 Jan 2017 15:32:28 +0000
draft: false
tags: ['Docker', 'Rancher']
---

Docker 1.11 の Swarm クラスタを運用しているものの、Kubernetes に切り替えようかなと考えていて [Rancher](http://rancher.com/) って便利なのかな？と思い Rancher Meetup Tokyo #3 に参加してきました。
Rancher Labs の VP of Sales である Shannon Williams さんが多くの導入事例を発表されました。
[youtube](https://www.youtube.com/channel/UCh5Xtp82q8wjijP8npkVTBA/www.rancher.com) に Case Study が沢山あるようです。
Version 2.0 では RBAC が導入されるようでエンタープライズ環境に入れやすくなりそうです。
さて、DigitalOcean のチュートリアルに [How To Manage Multi-Node Deployments with Rancher and Docker Machine on Ubuntu 16.04](https://www.digitalocean.com/community/tutorials/how-to-manage-multi-node-deployments-with-rancher-and-docker-machine-on-ubuntu-16-04) というものがありました。
Rancher で何ができるのかを確認するためにこれをなぞってみます。
Rancher は Server と Agent があり、どちらもコンテナとして起動し、Agent が Server に接続にいく感じらしい。

### Rancher Server の起動

チュートリアルにある手順ではブラウザから操作するようになっていますが、ここでは [doctl](https://github.com/digitalocean/doctl) を使います。 （サーバー1台起動させるだけなのでブラウザからの操作で十分ではあります）
Docker インストール済みの Ubuntu 16.04 のイメージを使います CLI で指定するイメージ名を確認します

```
ytera@vaio:~$ doctl compute image list | awk '(NR == 1 || /Docker/) {print $0}'
ID		Name							Type		Distribution	Slug			Public	Min Disk
20842141	Docker 1.12.2 on 14.04					snapshot	Ubuntu		docker			true	20
21543639	Docker 1.12.4 on 16.04					snapshot	Ubuntu					true	20
21968259	Docker 1.12.5 on 16.04					snapshot	Ubuntu		docker-16-04		true	20
```

**docker-16-04** ですね 1GB メモリのインスタンスを起動するので **size** は **1gb** と指定します

```
$ doctl compute size list 
Slug	Memory	VCPUs	Disk	Price Monthly	Price Hourly
512mb	512	1	20	5.00		0.007440
1gb	1024	1	30	10.00		0.014880
2gb	2048	2	40	20.00		0.029760
4gb	4096	2	60	40.00		0.059520
8gb	8192	4	80	80.00		0.119050
16gb	16384	8	160	160.00		0.238100
m-16gb	16384	2	30	120.00		0.178570
32gb	32768	12	320	320.00		0.476190
m-32gb	32768	4	90	240.00		0.357140
48gb	49152	16	480	480.00		0.714290
m-64gb	65536	8	200	480.00		0.714290
64gb	65536	20	640	640.00		0.952380
m-128gb	131072	16	340	960.00		1.428570
m-224gb	229376	32	500	1680.00		2.500000
```

**region** は一番近いシンガポールにするので **spg1**

```
$ doctl compute region list | awk '(NR == 1 || /Singapore/) {print $0}'
Slug	Name		Available
sgp1	Singapore 1	true
```

Rancher サーバーは docker コンテナとして起動するだけなので次のスクリプトを **user data** として渡せばサーバーの作成とともに Rancher サーバーまで起動できます。

```
#!/bin/bash
docker run -d --name rancher-server -p 80:8080 rancher/server
```

これを user-data.txt として保存します。**rancher/server** イメージでホストの port 80 にコンテナを port 8080 をマップして起動させるだけ。
ssh の public key 指定は **doctl compute ssh-key list** で ID を確認して指定します いよいよサーバーの作成です

```
$ doctl compute droplet create rancher-server --image docker-16-04 --region sgp1 --size 1gb --ssh-keys 76364 --user-data-file user-data.txt --wait
Notice: extracting volumes from []string{}


ID		Name		Public IPv4	Public IPv6	Memory	VCPUs	Disk	Region	Image				Status	Tags
37021557	rancher-server	128.199.xxx.yyy			1024	1	30	sgp1	Ubuntu Docker 1.12.5 on 16.04	active	
```

起動しました。

```
$ doctl compute ssh rancher-server
Welcome to Ubuntu 16.04.1 LTS (GNU/Linux 4.4.0-57-generic x86_64)

...

Last login: Thu Jan 12 10:22:56 2017 from 124.211.xxx.yyy
root@rancher-server:~# 
```

イメージの pull にすこし時間がかかりますが待っていると Rancher server が起動します

```
root@rancher-server:~# docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                            NAMES
da3eda013332        rancher/server      "/usr/bin/entry /usr/"   43 seconds ago      Up 41 seconds       3306/tcp, 0.0.0.0:80->8080/tcp   rancher-server
```

ブラウザで port 80 にアクセスしてみます。

{{< figure src="welcome_to_rancher.png" caption="Welcome to Rancher" >}}

{{< figure src="rancher_user_stacks.png" caption="Rancher user stacks" >}}

こんな画面が表示されます。

### 認証設定

初期状態では認証もなく誰でもアクセスできてしまうので、「**ADMIN**」→「**Access Control**」で認証設定を行います。

{{< figure src="rancher_access_control.png" caption="Rancher Access Control" >}}

* Active Directory
* Azure AD
* GitHub
* Local
* OpenLDAP
* Shibboleth

から選択できます。

[https://docs.rancher.com/rancher/v1.3/en/configuration/access-control/](https://docs.rancher.com/rancher/v1.3/en/configuration/access-control/) ここではチュートリアルに沿って GitHub 認証を設定してみます GitHub にはアカウントがすでにある前提です。[https://github.com/settings/developers](https://github.com/settings/developers) で新しいアプリケーションを作成します。

{{< figure src="github_new_oauth_application.png" caption="GitHub Register a new OAuth application" >}}

**Homepage URL**, **Authorization callback URL** にはさきほど作成した Rancher server の URL を指定します。これでアプリケーションを作成すると **Client ID**, **Client Secret** が得られるので、これを Rancher 側に設定すれば完了です。

{{< figure src="rancher_access_control_github_configration.png" caption="Rancher Access Control GitHub enabled" >}}

右下の **English** とあるところを **日本語** にすれば表示が日本語になります。

{{< figure src="rancher_access_control_github_configration_ja.png" caption="Rancher Access Control GitHub enabled (ja)" >}}

### 環境の追加

Rancher はアプリ（コンテナ）のデプロイ先クラスタを Environment と呼び、これを複数管理することができるようです。
"**dev**", "**test**", "**production**" などをひとつの Rancher server から管理することができるということですね。
それぞれが別のクラウドサービスであってもそこから Rancher server へアクセスできれば問題なさそうです。

ここではその Environment を追加してみます。

上部メニューの **Default** とあるところが Environment のメニューで、そこにある **Manage Environments** を選択します。

{{< figure src="rancher_manage_environments.png" caption="Rancher Manage Environments" >}}

**Add Environment** というボタンをクリック

{{< figure src="rancher_add_environtment.png" caption="Rancher Add Environtment" >}}

5つのテンプレートがあります **Swarm** は Swarmkit とあるので Docker 1.12 以降の swarm mode ですね

| Name       | Orchestration | Framework                                        | Networking    |
|------------|---------------|--------------------------------------------------|---------------|
| Cattle     | Cattle        | Network Services, Scheduler, Healthcheck Service | Rancher IPsec |
| Kubernetes | Kubernetes    | Network Services, Healthcheck Service            | Rancher IPsec |
| Mesos      | Mesos         | Network Services, Scheduler, Healthcheck Service | Rancher IPsec |
| Swarm      | SwarmKit      | Network Services, Scheduler, Healthcheck Service | Rancher IPsec |
| Windows    | Windows       | -                                                | -             |

テンプレートは次のようなかたちで追加することができます

{{< figure src="rancher_add_template.png" caption="Rancher Add Template" >}}

Name を **k8s** として **Kubernetes** テンプレートで Environment を作成してみました

{{< figure src="rancher_environment_added.png" caption="Rancher Environment Added" >}}

Environment を作成したらそこへホストを追加して Kubernetes を構築する必要がありますが、ホストさえ用意すれば後はテンプレートに従って Rancher がやってくれます 上部メニューの **Default** 部分を今作成した **k8s** に切り替えます
すると、次のような表示になりました

{{< figure src="rancher_setting_up_kubernetes.png" caption="Rancher Setting up Kubernetes" >}}

ぐるぐる回ってますが、ここで待っててもホストがないのでセットアップは進みません。上部メニューの **INFRASTRUCTURE** から **Hosts** を選択します

{{< figure src="rancher_hosts_1.png" caption="Rancher Hosts" >}}

まだホストがないので **Add Host** で追加します

{{< figure src="rancher_add_digitalocean_host_1.png" caption="Rancher Add DigitalOcean Host" >}}

今回は DigitalOcean なのでそれを選択し、Access Token を入力して次へ進みます Access Token は [https://cloud.digitalocean.com/settings/api/tokens](https://cloud.digitalocean.com/settings/api/tokens) で取得します 上の図に表示されていないクラウドサービス用の Machine Driver もあります

{{< figure src="rancher_machine_drivers.png" caption="Rancher Machine Drivers" >}}

が、これは置いておいて DigitalOcean で進めます

{{< figure src="rancher_add_digitalocean_host_2.png" caption="Rancher Add DigitalOcean Host (2)" >}}

**Name**（数字部分は数にあわせてインクリメントされます）、**Quantity**（数）、**Region**、**Image**、**Size** 等を指定して **Create** をクリック

{{< figure src="rancher_add_digitalocean_host_4.png" caption="Rancher Add DigitalOcean Host (3)" >}}

このような感じで状態がどんどん変わってゆき、ついに Kubernetes クラスタが完成するのです

{{< figure src="rancher_add_digitalocean_host_7.png" caption="Rancher Add DigitalOcean Host (4)" >}}

ただただインスタンス（Droplet）のサイズと数を指定しただけで Kubernetes クラスタが完成しました。便利すぎる。

etcd が 3 つ必要なので 3 台用意しましたが、リソースさえ足りていれば2台でも1台でも大丈夫なようです。もちろんホストの故障を考えたら 3 台以上が必要です。

が、、なぜか Kubernetes へのコンテナのデプロイができないな... どこがおかしいのか... やっぱり、こういう場合に困るよなぁ

**KUBERNETES** → **Dashboard** から Kubernetes Dashboard へアクセスできるはずですが Service Unavailable になってしまう ちなみにこの Kubernetes Dashboard は直接外からはアクセスできないため、Rancher server が proxy するようです。
Kubernetes を動かすには Droplet のサイズが小さすぎたかな？
（後で 2GB メモリのインスタンス 3 台で試したら Kubernetes Dashboard にもアクセスできました）

{{< figure src="rancher_host_info.png" caption="Rancher Host Info" >}}

ちょっと Kubernetes 環境は置いておいて **Default** Environment にホストを追加してためしてみます。**Default** は **Cattle** なので単体の Docker ホストを追加して使うようです。Rancher の agent がコンテナとして稼働しています。

カタログから Wordpress stack を追加してみました

{{< figure src="rancher_wordpress_stack1.png" caption="Rancher WordPress stack" >}}

Public Port を 80 に指定してある

{{< figure src="rancher_wordpress_stack2.png" caption="Rancher WordPress stack" >}}

起動しました。外からアクセスできました。ホストアドレスの Public Port で指定した port 80 でアクセスできました。

ということなので2つの Wordpress をひとつのホストでどちらも port 80 というわけにはいかないということですね。
[Scheduling Services](http://docs.rancher.com/rancher/v1.3/en/cattle/scheduling/) に scheduling policies が書かれていました

* port conflicts
* shared volumes
* host tagging
* shared network stack: –net=container:dependency
* strict and soft affinity/anti-affinity rules by using both env var (Swarm) and labels (Rancher)

Rancher の [Load Balancer](http://docs.rancher.com/rancher/v1.3/en/cattle/adding-load-balancers/) というのがどういうものか気になっている 夜も更けてきたので続きは次回
