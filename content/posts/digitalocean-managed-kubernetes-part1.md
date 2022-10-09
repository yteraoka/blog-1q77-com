---
title: 'DigitalOcean の managed kubernetes サービスを試す その１'
date: 
draft: true
tags: ['未分類']
---

> I’m the product manager for DigitalOcean Kubernetes and I’d like to invite you to our Limited Availability! DigitalOcean Kubernetes Limited Availability is designed to help simplify the management of your container workloads while providing the benefits of Kubernetes:
> 
> *   Accelerates the velocity of deploying new features
> *   Adds application scalability
> *   Abstracts infrastructure making applications more portable
> *   Provides efficiency gains across your infrastructure
> *   Ultimately improves application reliability and availability
> 
> ...

私の DigitalOcean アカウントでは beta の managed kubernetes を試せるのでちょっと触ってみる。```
\[ytera@DESKTOP-6C495NI ~\]$ curl -Lo bin/kubectl.exe https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/windows/amd64/kubectl.exe
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100 54.9M  100 54.9M    0     0  4826k      0  0:00:11  0:00:11 --:--:-- 5461k
\[ytera@DESKTOP-6C495NI ~\]$ kubectl get nodes
NAME               STATUS   ROLES    AGE     VERSION
clever-lewin-krb   Ready    94s     v1.12.1
clever-lewin-krr   Ready    4m40s   v1.12.1
clever-lewin-krw   Ready    4m38s   v1.12.1
\[ytera@DESKTOP-6C495NI ~\]$ kubectl get pods
No resources found.
\[ytera@DESKTOP-6C495NI ~\]$ kubectl get pods --all-namespaces
NAMESPACE     NAME                          READY   STATUS    RESTARTS   AGE
kube-system   csi-do-controller-0           3/3     Running   0          6m52s
kube-system   csi-do-node-cmrpd             2/2     Running   0          5m3s
kube-system   csi-do-node-cp5bw             2/2     Running   0          3m22s
kube-system   csi-do-node-zp2jf             2/2     Running   0          5m2s
kube-system   kube-dns-55cf9576c4-d7ww5     3/3     Running   0          6m52s
kube-system   kube-proxy-clever-lewin-krb   1/1     Running   0          3m30s
kube-system   kube-proxy-clever-lewin-krr   1/1     Running   0          6m36s
kube-system   kube-proxy-clever-lewin-krw   1/1     Running   1          6m34s
\[ytera@DESKTOP-6C495NI ~\]$ kubectl get pods --namespace system
No resources found.
\[ytera@DESKTOP-6C495NI ~\]$ kubectl get namespaces
NAME          STATUS   AGE
default       Active   7m31s
kube-public   Active   7m31s
kube-system   Active   7m31s
\[ytera@DESKTOP-6C495NI ~\]$ kubectl get services --all-namespaces
NAMESPACE     NAME         TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)         AGE
default       kubernetes   ClusterIP   10.245.0.1    443/TCP         7m59s
kube-system   kube-dns     ClusterIP   10.245.0.10   53/UDP,53/TCP   7m57s
\[ytera@DESKTOP-6C495NI ~\]$ dols
ID           Name                Public IPv4       Private IPv4      Public IPv6    Memory    VCPUs   Disk    Region    Image                  Status    Tags                                                      Features              Volumes
117375638    clever-lewin-krr    68.183.97.121     10.136.124.185                   1024      1       25      nyc1      Debian do-kube-base    active    k8s:4c2f60b3-dac2-4c07-bb56-8b881f8db41b,k8s,k8s:worker    private\_networking
117375639    clever-lewin-krw    68.183.107.151    10.136.141.242                   1024      1       25      nyc1      Debian do-kube-base    active    k8s:4c2f60b3-dac2-4c07-bb56-8b881f8db41b,k8s,k8s:worker    private\_networking
117375641    clever-lewin-krb    68.183.118.229    10.136.143.186                   1024      1       25      nyc1      Debian do-kube-base    active    k8s:4c2f60b3-dac2-4c07-bb56-8b881f8db41b,k8s,k8s:worker    private\_networking
\[ytera@DESKTOP-6C495NI ~\]$ 
```