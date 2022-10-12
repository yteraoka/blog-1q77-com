---
title: 'GKE Hello Wordpress チュートリアルを試す'
date: Sun, 12 Jul 2015 16:10:56 +0000
draft: false
tags: ['Docker', 'GCP', 'GKE', 'Kubernetes']
---

[Hello WordPress - Container Engine — Google Cloud Platform](https://cloud.google.com/container-engine/docs/tutorials/hello-wordpress) をなぞってみます。

[Before You Begin](https://cloud.google.com/container-engine/docs/before-you-begin) で [kubectl](https://cloud.google.com/container-engine/docs/kubectl/?hl=ja) コマンドが使えるようにします。

Step 1: Create your cluster
---------------------------

まずは[クラスタ](https://cloud.google.com/container-engine/docs/clusters/?hl=ja)の作成。クラスタはひとつのマスターインスタンスといくつかのワーカーノードで構成されます。これらは Compute Engine の仮想マシンです。いくつのワーカーノードを作成するかはクラスタ生成時に指定できます。

Hello Wordpress のチュートリアルではあまりリソースを必要としないので g1-small 1つで作成します。

```
$ gcloud beta container clusters create hello-world --num-nodes 1 --machine-type g1-small
Creating cluster hello-world...done.
Created [https://container.googleapis.com/v1/projects/PROJECTID/zones/asia-east1-c/clusters/hello-world].
kubeconfig entry generated for hello-world. To switch context to the cluster, run

$ kubectl config use-context gke_PROJECTID_asia-east1-c_hello-world

NAME         ZONE          MASTER_VERSION  MASTER_IP        MACHINE_TYPE  STATUS
hello-world  asia-east1-c  0.21.1          203.0.113.245    g1-small      RUNNING
```

Compure Engine のインスタンスを確認してみる

```
$ gcloud compute instances list
NAME                               ZONE         MACHINE_TYPE PREEMPTIBLE INTERNAL_IP   EXTERNAL_IP     STATUS
gke-hello-world-9a51d286-node-5b6i asia-east1-c g1-small                 10.240.147.88 203.0.113.237   RUNNING
```

SSH で仮想マシンにログインできます

```
$ gcloud compute ssh gke-hello-world-9a51d286-node-5b6i
```

こんな motd が設定されてました

```
$ cat /etc/motd

=== GCE Kubernetes node setup complete ===
```

`docker ps` を実行してみる。`/pause` ってなにしてるんだろ？

```
$ sudo docker ps -a --no-trunc=true
CONTAINER ID                                                       IMAGE                                            COMMAND                                                                                                                                                                                       CREATED             STATUS              PORTS               NAMES
b8deba1de24333df5e2f2cd1fb445827ce676d475f479d450be341593818fb27   gcr.io/google_containers/skydns:2015-03-11-001   "/skydns -machines=http://localhost:4001 -addr=0.0.0.0:53 -domain=cluster.local."                                                                                                             About an hour ago   Up About an hour                        k8s_skydns.bc99c0c0_kube-dns-v6-d2chz_kube-system_370cef57-2876-11e5-afa0-42010af0b13a_d6fe6fff                                                     
54727acc2b03937792e867a7f3988ae898ec6814216925a8763f34acddc63f45   gcr.io/google_containers/heapster:v0.15.0        "/heapster --source=kubernetes:''"                                                                                                                                                            About an hour ago   Up About an hour                        k8s_heapster.c2816f0b_monitoring-heapster-v5-hi3cc_kube-system_370f7e40-2876-11e5-afa0-42010af0b13a_0bafdc86                                        
aa5facac3aca1444fc37bb945621a06cf90c39940c6cbf16f291f84dca6304fb   gcr.io/google_containers/kube2sky:1.11           "/kube2sky -domain=cluster.local"                                                                                                                                                             About an hour ago   Up About an hour                        k8s_kube2sky.54c6a36_kube-dns-v6-d2chz_kube-system_370cef57-2876-11e5-afa0-42010af0b13a_690dff48                                                    
1756481deaab0382f6c3d0b83560d23e5590443a30c8814f5ba324072965ba48   gcr.io/google_containers/kube-ui:v1              "/kube-ui"                                                                                                                                                                                    About an hour ago   Up About an hour                        k8s_kube-ui.484b832c_kube-ui-v1-hzr55_kube-system_371210d2-2876-11e5-afa0-42010af0b13a_5e76bbeb                                                     
c433d0e2fadde42262161e06861c27b3bc7b2f18612f42c3484d0665ba0a7893   gcr.io/google_containers/etcd:2.0.9              "/usr/local/bin/etcd -listen-client-urls http://127.0.0.1:2379,http://127.0.0.1:4001 -advertise-client-urls http://127.0.0.1:2379,http://127.0.0.1:4001 -initial-cluster-token skydns-etcd"   About an hour ago   Up About an hour                        k8s_etcd.f9e6987c_kube-dns-v6-d2chz_kube-system_370cef57-2876-11e5-afa0-42010af0b13a_9ab851ad                                                       
f9e9fc96d1b514605f048c332a90addd4d2250a36f8c5278a17345867368652a   gcr.io/google_containers/pause:0.8.0             "/pause"                                                                                                                                                                                      About an hour ago   Up About an hour                        k8s_POD.3b46e8b9_kube-ui-v1-hzr55_kube-system_371210d2-2876-11e5-afa0-42010af0b13a_1fd41fda                                                         
8dd19c0c51ffc9269d8d3b91af4c661e0cdfbc5f54dfdd4afcbce1c8093d20ed   gcr.io/google_containers/pause:0.8.0             "/pause"                                                                                                                                                                                      About an hour ago   Up About an hour                        k8s_POD.e4cc795_monitoring-heapster-v5-hi3cc_kube-system_370f7e40-2876-11e5-afa0-42010af0b13a_fbf88044                                              
56561a56f421f92d98c96ae70178f54171d66466728d6a2811a5d2930f40b7e0   gcr.io/google_containers/pause:0.8.0             "/pause"                                                                                                                                                                                      About an hour ago   Up About an hour                        k8s_POD.8fdb0e41_kube-dns-v6-d2chz_kube-system_370cef57-2876-11e5-afa0-42010af0b13a_47ffc351                                                        
037e26826835806068f4714b62338ea41c4c3a36aa02a3c7813c1f281eabe068   gcr.io/google_containers/fluentd-gcp:1.8         "\"/bin/sh -c '/usr/sbin/google-fluentd \"$FLUENTD_ARGS\" > /var/log/google-fluentd.log'\""                                                                                                   About an hour ago   Up About an hour                        k8s_fluentd-cloud-logging.7721935b_fluentd-cloud-logging-gke-hello-world-9a51d286-node-5b6i_kube-system_d0feac1ad02da9e97c4bf67970ece7a1_17ce15ff   
259b13a26f0ca23dfc30cd39db674e62da4578351948f50ab8ac8ff8440dc439   gcr.io/google_containers/pause:0.8.0             "/pause"                                                                                                                                                                                      About an hour ago   Up About an hour                        k8s_POD.e4cc795_fluentd-cloud-logging-gke-hello-world-9a51d286-node-5b6i_kube-system_d0feac1ad02da9e97c4bf67970ece7a1_dc38b285
```

Step 2: Create your pod
-----------------------

`tutum/wordpress` イメージを使って [Pod](https://cloud.google.com/container-engine/docs/pods/?hl=ja) を作成する。

この wordpress のチュートリアルでは単一 container の Pod ですが、複数の container をまとめた pod を作成することもできます。実際の運用では複数の container をまとめたもののほうが主流となりそうです。

```
$ kubectl run wordpress --image=tutum/wordpress --port=80
CONTROLLER   CONTAINER(S)   IMAGE(S)          SELECTOR        REPLICAS
wordpress    wordpress      tutum/wordpress   run=wordpress   1
```

```
$ kubectl get rc wordpress
CONTROLLER   CONTAINER(S)   IMAGE(S)          SELECTOR        REPLICAS
wordpress    wordpress      tutum/wordpress   run=wordpress   1
```

```
$ sudo docker ps -a --no-trunc=true
CONTAINER ID                                                       IMAGE                                            COMMAND                                                                                                                                                                                       CREATED             STATUS              PORTS               NAMES
364f8dc700b305473bedf1099ab85acbc714d3f19debb28b56703937e5029dbc   tutum/wordpress:latest                           "/run.sh"                                                                                                                                                                                     4 minutes ago       Up 4 minutes                            k8s_wordpress.b91f4b7e_wordpress-jalj8_default_9ddba397-2883-11e5-afa0-42010af0b13a_c9481e56                                                        
477e90ae29c4dd75162b857f91829dc714fe224853e1cc24dd9bc45028a4ef72   gcr.io/google_containers/pause:0.8.0             "/pause"                                                                                                                                                                                      4 minutes ago       Up 4 minutes                            k8s_POD.ef28e851_wordpress-jalj8_default_9ddba397-2883-11e5-afa0-42010af0b13a_529d3a4d                                                              
b8deba1de24333df5e2f2cd1fb445827ce676d475f479d450be341593818fb27   gcr.io/google_containers/skydns:2015-03-11-001   "/skydns -machines=http://localhost:4001 -addr=0.0.0.0:53 -domain=cluster.local."                                                                                                             About an hour ago   Up About an hour                        k8s_skydns.bc99c0c0_kube-dns-v6-d2chz_kube-system_370cef57-2876-11e5-afa0-42010af0b13a_d6fe6fff                                                     
54727acc2b03937792e867a7f3988ae898ec6814216925a8763f34acddc63f45   gcr.io/google_containers/heapster:v0.15.0        "/heapster --source=kubernetes:''"                                                                                                                                                            About an hour ago   Up About an hour                        k8s_heapster.c2816f0b_monitoring-heapster-v5-hi3cc_kube-system_370f7e40-2876-11e5-afa0-42010af0b13a_0bafdc86                                        
aa5facac3aca1444fc37bb945621a06cf90c39940c6cbf16f291f84dca6304fb   gcr.io/google_containers/kube2sky:1.11           "/kube2sky -domain=cluster.local"                                                                                                                                                             About an hour ago   Up About an hour                        k8s_kube2sky.54c6a36_kube-dns-v6-d2chz_kube-system_370cef57-2876-11e5-afa0-42010af0b13a_690dff48                                                    
1756481deaab0382f6c3d0b83560d23e5590443a30c8814f5ba324072965ba48   gcr.io/google_containers/kube-ui:v1              "/kube-ui"                                                                                                                                                                                    About an hour ago   Up About an hour                        k8s_kube-ui.484b832c_kube-ui-v1-hzr55_kube-system_371210d2-2876-11e5-afa0-42010af0b13a_5e76bbeb                                                     
c433d0e2fadde42262161e06861c27b3bc7b2f18612f42c3484d0665ba0a7893   gcr.io/google_containers/etcd:2.0.9              "/usr/local/bin/etcd -listen-client-urls http://127.0.0.1:2379,http://127.0.0.1:4001 -advertise-client-urls http://127.0.0.1:2379,http://127.0.0.1:4001 -initial-cluster-token skydns-etcd"   About an hour ago   Up About an hour                        k8s_etcd.f9e6987c_kube-dns-v6-d2chz_kube-system_370cef57-2876-11e5-afa0-42010af0b13a_9ab851ad                                                       
f9e9fc96d1b514605f048c332a90addd4d2250a36f8c5278a17345867368652a   gcr.io/google_containers/pause:0.8.0             "/pause"                                                                                                                                                                                      About an hour ago   Up About an hour                        k8s_POD.3b46e8b9_kube-ui-v1-hzr55_kube-system_371210d2-2876-11e5-afa0-42010af0b13a_1fd41fda                                                         
8dd19c0c51ffc9269d8d3b91af4c661e0cdfbc5f54dfdd4afcbce1c8093d20ed   gcr.io/google_containers/pause:0.8.0             "/pause"                                                                                                                                                                                      About an hour ago   Up About an hour                        k8s_POD.e4cc795_monitoring-heapster-v5-hi3cc_kube-system_370f7e40-2876-11e5-afa0-42010af0b13a_fbf88044                                              
56561a56f421f92d98c96ae70178f54171d66466728d6a2811a5d2930f40b7e0   gcr.io/google_containers/pause:0.8.0             "/pause"                                                                                                                                                                                      About an hour ago   Up About an hour                        k8s_POD.8fdb0e41_kube-dns-v6-d2chz_kube-system_370cef57-2876-11e5-afa0-42010af0b13a_47ffc351                                                        
037e26826835806068f4714b62338ea41c4c3a36aa02a3c7813c1f281eabe068   gcr.io/google_containers/fluentd-gcp:1.8         "\"/bin/sh -c '/usr/sbin/google-fluentd \"$FLUENTD_ARGS\" > /var/log/google-fluentd.log'\""                                                                                                   About an hour ago   Up About an hour                        k8s_fluentd-cloud-logging.7721935b_fluentd-cloud-logging-gke-hello-world-9a51d286-node-5b6i_kube-system_d0feac1ad02da9e97c4bf67970ece7a1_17ce15ff   
259b13a26f0ca23dfc30cd39db674e62da4578351948f50ab8ac8ff8440dc439   gcr.io/google_containers/pause:0.8.0             "/pause"                                                                                                                                                                                      About an hour ago   Up About an hour                        k8s_POD.e4cc795_fluentd-cloud-logging-gke-hello-world-9a51d286-node-5b6i_kube-system_d0feac1ad02da9e97c4bf67970ece7a1_dc38b285
```

Step 3: Allow external traffic
------------------------------

外部からアクセスできるようにする。

Pod へのアクセスは標準では内部ネットワークからのアクセスしかできないので、外部からアクセスできるようにする。

`kubectl` の [`expose`](https://cloud.google.com/container-engine/docs/kubectl/expose?hl=ja) (さらす、露出する) コマンドで公開します。

```
$ kubectl expose rc wordpress --create-external-load-balancer=true
NAME        LABELS          SELECTOR        IP(S)     PORT(S)
wordpress   run=wordpress   run=wordpress             80/TCP
```

```
$ kubectl get services wordpress
NAME        LABELS          SELECTOR        IP(S)             PORT(S)
wordpress   run=wordpress   run=wordpress   10.191.254.84     80/TCP
```

```
$ kubectl get nodes
NAME                                 LABELS                                                      STATUS
gke-hello-world-9a51d286-node-5b6i   kubernetes.io/hostname=gke-hello-world-9a51d286-node-5b6i   Ready
```

この `NAME` の `-node` までが `node-name-prefix` で、firewall-rule の設定にこれを使います。

```
$ gcloud compute firewall-rules create hello-world-80 --allow tcp:80 \
    --target-tags gke-hello-world-9a51d286-node
Created [https://www.googleapis.com/compute/v1/projects/PROJECTID/global/firewalls/hello-world-80].
NAME           NETWORK SRC_RANGES RULES  SRC_TAGS TARGET_TAGS
hello-world-80 default 0.0.0.0/0  tcp:80          gke-hello-world-9a51d286-node
```

Wordpressにアクセス可能なことを確認
----------------------

```
$ kubectl get services wordpress
NAME        LABELS          SELECTOR        IP(S)             PORT(S)
wordpress   run=wordpress   run=wordpress   10.191.254.84     80/TCP
```

http://203.0.113.9/ にアクセスして Wordpress が動いてることを確認します。

クラスタを削除する
---------

使い終わったクラスタは削除しないとお金がかかるので忘れずに削除しましょう

```
$ kubectl delete services wordpress
services/wordpress
```

```
$ kubectl stop rc wordpress
replicationcontrollers/wordpress
```

```
$ gcloud beta container clusters delete hello-world
The following clusters will be deleted.
 - [hello-world] in [asia-east1-c]

Do you want to continue (Y/n)?  Y

Deleting cluster hello-world...done.
Deleted [https://container.googleapis.com/v1/projects/PROJECTID/zones/asia-east1-c/clusters/hello-world].
```

```
$ gcloud compute firewall-rules delete hello-world-80
The following firewalls will be deleted:
 - [hello-world-80]

Do you want to continue (Y/n)?  Y

Deleted [https://www.googleapis.com/compute/v1/projects/PROJECTID/global/firewalls/hello-world-80].

```

次は [Guestbook](/2015/07/gke-guestbook-tutorial/) のチュートリアルを試してみます
