---
title: 'eksctl で何ができるのか'
date: Sat, 11 Jan 2020 15:02:03 +0000
draft: false
tags: ['AWS', 'EKS']
---

[eksctl](https://eksctl.io/) が何をやってくれるのが、何ができるのかを確認します。

eksctl create cluster
---------------------

いきなり `eksctl create cluster` を実行するだけでクラスタが作れるっぽいのでひとまず試してみる。

```
$ eksctl create cluster
[ℹ]  eksctl version 0.12.0
[ℹ]  using region ap-northeast-1
[ℹ]  setting availability zones to [ap-northeast-1c ap-northeast-1d ap-northeast-1b]
[ℹ]  subnets for ap-northeast-1c - public:192.168.0.0/19 private:192.168.96.0/19
[ℹ]  subnets for ap-northeast-1d - public:192.168.32.0/19 private:192.168.128.0/19
[ℹ]  subnets for ap-northeast-1b - public:192.168.64.0/19 private:192.168.160.0/19
[ℹ]  nodegroup "ng-bb178f10" will use "ami-07296175bc6b826a5" [AmazonLinux2/1.14]
[ℹ]  using Kubernetes version 1.14
[ℹ]  creating EKS cluster "beautiful-badger-1578666058" in "ap-northeast-1" region with un-managed nodes
[ℹ]  will create 2 separate CloudFormation stacks for cluster itself and the initial nodegroup
[ℹ]  if you encounter any issues, check CloudFormation console or try 'eksctl utils describe-stacks --region=ap-northeast-1 --cluster=beautiful-badger-1578666058'
[ℹ]  CloudWatch logging will not be enabled for cluster "beautiful-badger-1578666058" in "ap-northeast-1"
[ℹ]  you can enable it with 'eksctl utils update-cluster-logging --region=ap-northeast-1 --cluster=beautiful-badger-1578666058'
[ℹ]  Kubernetes API endpoint access will use default of {publicAccess=true, privateAccess=false} for cluster "beautiful-badger-1578666058" in "ap-northeast-1"
[ℹ]  2 sequential tasks: { create cluster control plane "beautiful-badger-1578666058", create nodegroup "ng-bb178f10" }
[ℹ]  building cluster stack "eksctl-beautiful-badger-1578666058-cluster"
[ℹ]  deploying stack "eksctl-beautiful-badger-1578666058-cluster"
```

VPC から一式全部作る CloudFormation の stack (ここでは eksctl-beautiful-badger-1578666058-cluster という名前) が作成されて deploy が開始されました。AWS Console で CloudFormation の stack を確認すれば状況がわかります。ありゃ？エラーが...

```
[✖]  unexpected status "ROLLBACK_IN_PROGRESS" while waiting for CloudFormation stack "eksctl-beautiful-badger-1578666058-nodegroup-ng-bb178f10"
[ℹ]  fetching stack events in attempt to troubleshoot the root cause of the failure
[!]  AWS::EC2::SecurityGroupEgress/EgressInterClusterAPI: DELETE_IN_PROGRESS
[!]  AWS::EC2::SecurityGroupIngress/IngressInterClusterAPI: DELETE_IN_PROGRESS
[!]  AWS::EC2::SecurityGroupIngress/IngressInterClusterCP: DELETE_IN_PROGRESS
[!]  AWS::EC2::SecurityGroupEgress/EgressInterCluster: DELETE_IN_PROGRESS
[!]  AWS::AutoScaling::AutoScalingGroup/NodeGroup: DELETE_IN_PROGRESS
[!]  AWS::EC2::SecurityGroupIngress/IngressInterCluster: DELETE_IN_PROGRESS
[✖]  AWS::AutoScaling::AutoScalingGroup/NodeGroup: CREATE_FAILED – "AWS was not able to validate the provided access credentials (Service: AmazonAutoScaling; Status Code: 400; Error Code: ValidationError; Request ID: a31c5a54-33b6-11ea-9896-5308bff4139a)"
[ℹ]  1 error(s) occurred and cluster hasn't been created properly, you may wish to check CloudFormation console
[ℹ]  to cleanup resources, run 'eksctl delete cluster --region=ap-northeast-1 --name=beautiful-badger-1578666058'
[✖]  waiting for CloudFormation stack "eksctl-beautiful-badger-1578666058-nodegroup-ng-bb178f10": ResourceNotReady: failed waiting for successful resource state
Error: failed to create cluster "beautiful-badger-1578666058"
```

NodeGroup の作成でこけたらしいことは分かったが... 😣

```
AWS was not able to validate the provided access credentials (Service: AmazonAutoScaling; Status Code: 400; Error Code: ValidationError; Request ID: a31c5a54-33b6-11ea-9896-5308bff4139a)
```

再チャレンジしたら今度は別のところでコケた...

```
[✖]  AWS::EC2::Subnet/SubnetPublicAPNORTHEAST1A: CREATE_FAILED – "Value (ap-northeast-1a) for parameter availabilityZone is invalid. Subnets can currently only be created in the following availability zones: ap-northeast-1d, ap-northeast-1c, ap-northeast-1b. (Service: AmazonEC2; Status Code: 400; Error Code: InvalidParameterValue; Request ID: 28f3bfed-2939-4efd-ad9c-7f6152d6b041)"
[✖]  AWS::EC2::Subnet/SubnetPrivateAPNORTHEAST1A: CREATE_FAILED – "Value (ap-northeast-1a) for parameter availabilityZone is invalid. Subnets can currently only be created in the following availability zones: ap-northeast-1b, ap-northeast-1c, ap-northeast-1d. (Service: AmazonEC2; Status Code: 400; Error Code: InvalidParameterValue; Request ID: 0e402395-2b61-4b7f-ac5b-6e9f01625f0c)"
```

この後、数回試したが、全部この AZ の問題でコケた...

それでもあと1回、あと1回と思って試してたら成功した。(eksctl create cluster --zones=ap-northeast-1b,ap-northeast-1c,ap-northeast-1d と --zones を指定すれば良いのかな) しかし、AZ の問題はわかるんだけど、初回のエラーは必ず再発するのかと思ってたので意外

```
$ eksctl create cluster                                                           
[ℹ]  eksctl version 0.12.0
[ℹ]  using region ap-northeast-1
[ℹ]  setting availability zones to [ap-northeast-1c ap-northeast-1d ap-northeast-1b]
[ℹ]  subnets for ap-northeast-1c - public:192.168.0.0/19 private:192.168.96.0/19
[ℹ]  subnets for ap-northeast-1d - public:192.168.32.0/19 private:192.168.128.0/19
[ℹ]  subnets for ap-northeast-1b - public:192.168.64.0/19 private:192.168.160.0/19
[ℹ]  nodegroup "ng-c384e850" will use "ami-07296175bc6b826a5" [AmazonLinux2/1.14]
[ℹ]  using Kubernetes version 1.14
[ℹ]  creating EKS cluster "wonderful-painting-1578669435" in "ap-northeast-1" region with un-managed nodes
[ℹ]  will create 2 separate CloudFormation stacks for cluster itself and the initial nodegroup
[ℹ]  if you encounter any issues, check CloudFormation console or try 'eksctl utils describe-stacks --region=ap-northeast-1 --cluster=wonderful-painting-1578669435'
[ℹ]  CloudWatch logging will not be enabled for cluster "wonderful-painting-1578669435" in "ap-northeast-1"
[ℹ]  you can enable it with 'eksctl utils update-cluster-logging --region=ap-northeast-1 --cluster=wonderful-painting-1578669435'
[ℹ]  Kubernetes API endpoint access will use default of {publicAccess=true, privateAccess=false} for cluster "wonderful-painting-1578669435" in "ap-northeast-1"
[ℹ]  2 sequential tasks: { create cluster control plane "wonderful-painting-1578669435", create nodegroup "ng-c384e850" }
[ℹ]  building cluster stack "eksctl-wonderful-painting-1578669435-cluster"
[ℹ]  deploying stack "eksctl-wonderful-painting-1578669435-cluster"
[ℹ]  building nodegroup stack "eksctl-wonderful-painting-1578669435-nodegroup-ng-c384e850"
[ℹ]  --nodes-min=2 was set automatically for nodegroup ng-c384e850
[ℹ]  --nodes-max=2 was set automatically for nodegroup ng-c384e850
[ℹ]  deploying stack "eksctl-wonderful-painting-1578669435-nodegroup-ng-c384e850"
[✔]  all EKS cluster resources for "wonderful-painting-1578669435" have been created
[✔]  saved kubeconfig as "/Users/teraoka/.kube/config"
[ℹ]  adding identity "arn:aws:iam::949160801735:role/eksctl-wonderful-painting-1578669-NodeInstanceRole-18QXALFB6Y0W2" to auth ConfigMap
[ℹ]  nodegroup "ng-c384e850" has 0 node(s)
[ℹ]  waiting for at least 2 node(s) to become ready in "ng-c384e850"
[ℹ]  nodegroup "ng-c384e850" has 2 node(s)
[ℹ]  node "ip-192-168-12-245.ap-northeast-1.compute.internal" is ready
[ℹ]  node "ip-192-168-94-158.ap-northeast-1.compute.internal" is ready
[ℹ]  kubectl command should work with "/Users/teraoka/.kube/config", try 'kubectl get nodes'
[✔]  EKS cluster "wonderful-painting-1578669435" in "ap-northeast-1" region is ready
```

`~/.kube/config` に保存したよって出てるから kubectl コマンドを試してみる。

```
$ kubectl get nodes
NAME                                                STATUS   ROLES    AGE     VERSION
ip-192-168-12-245.ap-northeast-1.compute.internal   Ready    3m25s   v1.14.8-eks-b8860f
ip-192-168-94-158.ap-northeast-1.compute.internal   Ready    3m24s   v1.14.8-eks-b8860f 
```

```
$ kubectl get svc --all-namespaces
NAMESPACE     NAME         TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)         AGE
default       kubernetes   ClusterIP   10.100.0.1    443/TCP         16m
kube-system   kube-dns     ClusterIP   10.100.0.10   53/UDP,53/TCP   16m 
```

```
$ kubectl get ns 
NAME              STATUS   AGE
default           Active   17m
kube-node-lease   Active   17m
kube-public       Active   17m
kube-system       Active   17m
```

```
$ kubectl get pods --all-namespaces
NAMESPACE     NAME                       READY   STATUS    RESTARTS   AGE
kube-system   aws-node-b74p7             1/1     Running   0          11m
kube-system   aws-node-xx89x             1/1     Running   0          11m
kube-system   coredns-58986cd576-nc45g   1/1     Running   0          17m
kube-system   coredns-58986cd576-wcxcj   1/1     Running   0          17m
kube-system   kube-proxy-cfqcd           1/1     Running   0          11m
kube-system   kube-proxy-kzlgz           1/1     Running   0          11m
```

動いてる 😍

さて、どんなリソースが作られているのか。

- VPC
  - VPC から新しく作られる
- Subnet
  - Public と Private という2種類の Subnet がそれぞれ3つの Availability zone に作成される
- Internet Gateway
  - 新しい VPC を作って Public subnet を作成するので当然 Internet Gateway も必要になる
- Role
  - ServiceRole (Controle Plane 用)、NodeInstanceRole (EC2 Workder Node 用)、FargatePodExecutionRole の3つが作成される。ServiceRole は EKS のドキュメントにある AmazonEKSClusterPolicy、AmazonEKSServicePolicy と eksctl が作る PutMetrics 用 Policy と NLB 管理用の Policy が紐付けられている。NodeInstanceRole は EKS のドキュメントにある AmazonEKSWorkerNodePolicy、AmazonEC2ContainerRegistryReadOnly、AmazonEKS\_CNI\_Policy の3つが、FargatePodExecutionRole には AmazonEKSFargatePodExecutionRolePolicy が紐付けられている
- NAT Gateway
  - Private subnet があるので NAT Gateway も作成される。デフォルトでは1つの Availability zone にしか作られないが、--vpc-nat-mode で HighlyAvailable, Single, Disable から選択して指定することが可能。デフォルトは Single
- SecurityGroup
  - クラスタ内の node 間での通信用に作成される
- ControlePlane
  - もちろん Kubernetes の Controle Plane が作られる
- AutoScalingGroup
  - Worker node 用の AutoScalingGroup が作られる
- LaunchTemplate
  - Worker node 用の AutoScalingGroup で使われる LaunchTemplate で AMI Image や InstanceType、InstanceProflie、Userdata が設定されている

Worker node として EC2 インスタンスが作成されたらログインしてみたいはず。でも `eksctl create cluster` に `--ssh-access` (ファイルを指定するなら `--ssh-public-key` も) をつけておかないと Public Key が設定されないため worker node へのアクセスには [EC2 Instance Connect](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-connect-methods.html) で接続する必要がある。[aws-instance-connect-cli](https://github.com/aws/aws-ec2-instance-connect-cli) を使えば `mssh <instance-id>` だけで接続できる。 しかし Instance Connect は Instance Metadata Service v1 (IDMSv1) しかサポートしていないらしい。接続先インスタンスは Global IP address を持っている必要があり、SSH (22/tcp) が SecurityGroup で許可されている必要がある。Web Console から AWS のアドレスからの接続を許可しておく必要がある。また、接続する人は IAM Policy で [ec2-instance-connect:SendSSHPublicKey](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-connect-set-up.html#ec2-instance-connect-configure-IAM-role) 権限を持っている必要がある。公開鍵を送りつけて一時的にログインできるようにしてくれるんですね。

ところで、worker node にログインしてみたら Pod ごとに2つのコンテナが起動していました。複数コンテナが指定された Pod じゃないのになんでだろ？って思ったらどれも "/pause" が実行されてるものと、名前に合ったプログラムが実行されているコンテナの2つでした。

```
CONTAINER ID        IMAGE                                                                   COMMAND                  CREATED             STATUS              PORTS               NAMES
df061216904c        602401143452.dkr.ecr.ap-northeast-1.amazonaws.com/eks/coredns           "/coredns -conf /etc…"   2 hours ago         Up 2 hours                              k8s_coredns_coredns-58986cd576-6kl57_kube-system_00aec73c-3449-11ea-a7e3-069c17bfdc00_0
379bc8e2844a        602401143452.dkr.ecr.ap-northeast-1.amazonaws.com/eks/pause-amd64:3.1   "/pause"                 2 hours ago         Up 2 hours                              k8s_POD_coredns-58986cd576-6kl57_kube-system_00aec73c-3449-11ea-a7e3-069c17bfdc00_0
09ee64a82565        602401143452.dkr.ecr.ap-northeast-1.amazonaws.com/amazon-k8s-cni        "/bin/sh -c /app/ins…"   2 hours ago         Up 2 hours                              k8s_aws-node_aws-node-7l99l_kube-system_6f2001d2-344e-11ea-a7e3-069c17bfdc00_0
79eef819a1f4        602401143452.dkr.ecr.ap-northeast-1.amazonaws.com/eks/kube-proxy        "kube-proxy --v=2 --…"   2 hours ago         Up 2 hours                              k8s_kube-proxy_kube-proxy-d599c_kube-system_6f202763-344e-11ea-a7e3-069c17bfdc00_0
40ae949a2e0c        602401143452.dkr.ecr.ap-northeast-1.amazonaws.com/eks/pause-amd64:3.1   "/pause"                 2 hours ago         Up 2 hours                              k8s_POD_aws-node-7l99l_kube-system_6f2001d2-344e-11ea-a7e3-069c17bfdc00_0
eeed9d5bf85f        602401143452.dkr.ecr.ap-northeast-1.amazonaws.com/eks/pause-amd64:3.1   "/pause"                 2 hours ago         Up 2 hours                              k8s_POD_kube-proxy-d599c_kube-system_6f202763-344e-11ea-a7e3-069c17bfdc00_0
```

[The Almighty Pause Container](https://www.ianlewis.org/en/almighty-pause-container) ってのを見つけた。これが Pod という複数コンテナをまとめるキモだったんですね。

Worker node は起動時に Kubernetes のクラスタに参加する必要があるが、これは AutoScalingGroup の LaunchTemplate に userdata 設定があります。テキストが gzip されて base64 エンコードされていました、デコードすると次の内容でした。

userdata

```yaml
#cloud-config
packages: null
runcmd:
- /var/lib/cloud/scripts/per-instance/bootstrap.al2.sh
write_files:
- content: |
    # eksctl-specific systemd drop-in unit for kubelet, for Amazon Linux 2 (AL2)

    [Service]
    # Local metadata parameters: REGION, AWS_DEFAULT_REGION
    EnvironmentFile=/etc/eksctl/metadata.env
    # Global and static parameters: CLUSTER_DNS, NODE_LABELS, NODE_TAINTS
    EnvironmentFile=/etc/eksctl/kubelet.env
    # Local non-static parameters: NODE_IP, INSTANCE_ID
    EnvironmentFile=/etc/eksctl/kubelet.local.env

    ExecStart=
    ExecStart=/usr/bin/kubelet \
      --node-ip=${NODE_IP} \
      --node-labels=${NODE_LABELS},alpha.eksctl.io/instance-id=${INSTANCE_ID} \
      --max-pods=${MAX_PODS} \
      --register-node=true --register-with-taints=${NODE_TAINTS} \
      --allow-privileged=true \
      --cloud-provider=aws \
      --container-runtime=docker \
      --network-plugin=cni \
      --cni-bin-dir=/opt/cni/bin \
      --cni-conf-dir=/etc/cni/net.d \
      --pod-infra-container-image=${AWS_EKS_ECR_ACCOUNT}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/eks/pause-amd64:3.1 \
      --kubeconfig=/etc/eksctl/kubeconfig.yaml \
      --config=/etc/eksctl/kubelet.yaml
  owner: root:root
  path: /etc/systemd/system/kubelet.service.d/10-eksclt.al2.conf
  permissions: "0644"
- content: |-
    NODE_LABELS=alpha.eksctl.io/cluster-name=hilarious-hideout-1578729265,alpha.eksctl.io/nodegroup-name=ng-b50c30b5
    NODE_TAINTS=
  owner: root:root
  path: /etc/eksctl/kubelet.env
  permissions: "0644"
- content: |
    address: 0.0.0.0
    apiVersion: kubelet.config.k8s.io/v1beta1
    authentication:
      anonymous:
        enabled: false
      webhook:
        cacheTTL: 2m0s
        enabled: true
      x509:
        clientCAFile: /etc/eksctl/ca.crt
    authorization:
      mode: Webhook
      webhook:
        cacheAuthorizedTTL: 5m0s
        cacheUnauthorizedTTL: 30s
    cgroupDriver: cgroupfs
    clusterDNS:
    - 10.100.0.10
    clusterDomain: cluster.local
    featureGates:
      RotateKubeletServerCertificate: true
    kind: KubeletConfiguration
    serverTLSBootstrap: true
  owner: root:root
  path: /etc/eksctl/kubelet.yaml
  permissions: "0644"
- content: |
    -----BEGIN CERTIFICATE-----
    (省略)
    -----END CERTIFICATE-----
  owner: root:root
  path: /etc/eksctl/ca.crt
  permissions: "0644"
- content: |
    apiVersion: v1
    clusters:
    - cluster:
        certificate-authority: /etc/eksctl/ca.crt
        server: https://7950C8F5B4E86FAF920EB443279E8896.sk1.ap-northeast-1.eks.amazonaws.com
      name: hilarious-hideout-1578729265.ap-northeast-1.eksctl.io
    contexts:
    - context:
        cluster: hilarious-hideout-1578729265.ap-northeast-1.eksctl.io
        user: kubelet@hilarious-hideout-1578729265.ap-northeast-1.eksctl.io
      name: kubelet@hilarious-hideout-1578729265.ap-northeast-1.eksctl.io
    current-context: kubelet@hilarious-hideout-1578729265.ap-northeast-1.eksctl.io
    kind: Config
    preferences: {}
    users:
    - name: kubelet@hilarious-hideout-1578729265.ap-northeast-1.eksctl.io
      user:
        exec:
          apiVersion: client.authentication.k8s.io/v1alpha1
          args:
          - token
          - -i
          - hilarious-hideout-1578729265
          command: aws-iam-authenticator
          env: null
  owner: root:root
  path: /etc/eksctl/kubeconfig.yaml
  permissions: "0644"
- content: |
    m5.24xlarge 737
    g4dn.4xlarge 29
    i3.xlarge 58
    ... (省略) ...
    t2.nano 4
    c3.xlarge 58
    c5.large 29
  owner: root:root
  path: /etc/eksctl/max_pods.map
  permissions: "0644"
- content: |-
    AWS_DEFAULT_REGION=ap-northeast-1
    AWS_EKS_CLUSTER_NAME=hilarious-hideout-1578729265
    AWS_EKS_ENDPOINT=https://7950C8F5B4E86FAF920EB443279E8896.sk1.ap-northeast-1.eks.amazonaws.com
    AWS_EKS_ECR_ACCOUNT=602401143452
  owner: root:root
  path: /etc/eksctl/metadata.env
  permissions: "0644"
- content: |
    #!/bin/bash

    set -o errexit
    set -o pipefail
    set -o nounset

    function get_max_pods() {
      while read instance_type pods; do
        if  [[ "${instance_type}" == "${1}" ]] && [[ "${pods}" =~ ^[0-9]+$ ]] ; then
          echo ${pods}
          return
        fi
      done < /etc/eksctl/max_pods.map
    }

    NODE_IP="$(curl --silent http://169.254.169.254/latest/meta-data/local-ipv4)"
    INSTANCE_ID="$(curl --silent http://169.254.169.254/latest/meta-data/instance-id)"
    INSTANCE_TYPE="$(curl --silent http://169.254.169.254/latest/meta-data/instance-type)"

    source /etc/eksctl/kubelet.env # this can override MAX_PODS

    cat > /etc/eksctl/kubelet.local.env <<EOF
    NODE_IP=${NODE_IP}
    INSTANCE_ID=${INSTANCE_ID}
    INSTANCE_TYPE=${INSTANCE_TYPE}
    MAX_PODS=${MAX_PODS:-$(get_max_pods "${INSTANCE_TYPE}")}
    EOF

    systemctl daemon-reload
    systemctl enable kubelet
    systemctl start kubelet
  owner: root:root
  path: /var/lib/cloud/scripts/per-instance/bootstrap.al2.sh
  permissions: "0755"
```

でも今は [Managed Node Group](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html) ってのがあるのでこれを使うのが良いのかな。eksctl create cluster に --managed をつけるだけで良さそう。また、--fargate をつければ Fargate で実行する設定が入るっぽい。この辺りを確認して terraform で EKS 環境を構築できるようにしてみることにする。
