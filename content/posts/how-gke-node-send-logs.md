---
title: 'GKE の node はどのようにログを転送しているのか'
date: Fri, 13 Mar 2020 15:40:41 +0000
draft: false
tags: ['GCP', 'GCP', 'Kubernetes', 'fluentd']
---

GKE は何もしなくてもログを Cloud Logging (旧 Stackdriver Logging) に送ってくれて便利なんだけどどうやって送ってるのかな？と思って調べたメモ。なかなか興味深かった。

メトリクスの方も調べてみたがそれはまた別途、と思ったけどここでも登場した。

GKE クラスタの作成
-----------

クラスタの作成。画面ポチポチして取得した gcloud コマンドは省略可能なものも沢山ついてて長い。gcloud の config に compute/region, compute/zone が設定されている前提。でも設定されてたら指定の必要もないのか？

```
$ PROJECT\_ID=$(gcloud config get-value project)
$ REGION=$(gcloud config get-value compute/region)
$ ZONE=$(gcloud config get-value compute/zone)
$ CLUSTER\_NAME=cluster-1
$ gcloud beta container --project "${PROJECT\_ID}" clusters create "${CLUSTER\_NAME}" \\
    --zone "${ZONE}" \\
    --no-enable-basic-auth \\
    --cluster-version "1.14.10-gke.17" \\
    --machine-type "n1-standard-1" \\
    --image-type "COS" \\
    --disk-type "pd-standard" \\
    --disk-size "100" \\
    --metadata disable-legacy-endpoints=true \\
    --scopes \\
"https://www.googleapis.com/auth/devstorage.read\_only",\\
"https://www.googleapis.com/auth/logging.write",\\
"https://www.googleapis.com/auth/monitoring",\\
"https://www.googleapis.com/auth/servicecontrol",\\
"https://www.googleapis.com/auth/service.management.readonly",\\
"https://www.googleapis.com/auth/trace.append" \\
    --preemptible \\
    --num-nodes "1" \\
    --enable-stackdriver-kubernetes \\
    --enable-ip-alias \\
    --network "projects/${PROJECT\_ID}/global/networks/default" \\
    --subnetwork "projects/${PROJECT\_ID}/regions/${REGION}/subnetworks/default" \\
    --default-max-pods-per-node "110" \\
    --enable-autoscaling --min-nodes "0" --max-nodes "1" \\
    --no-enable-master-authorized-networks \\
    --addons HorizontalPodAutoscaling,HttpLoadBalancing \\
    --enable-autoupgrade \\
    --enable-autorepair \\
    --max-surge-upgrade 1 \\
    --max-unavailable-upgrade 0

```

kube-system 内の Pod などを確認
------------------------

kube-system 内に作られているものを確認。この中の **daemonset.apps/fluentd-gcp-v3.1.1** がログを送っている。

```
$ kubectl get all -n kube-system
NAME                                                            READY   STATUS    RESTARTS   AGE
pod/event-exporter-v0.2.5-7df89f4b8f-kzzz5                      2/2     Running   0          4m5s
pod/fluentd-gcp-scaler-54ccb89d5-6c6cf                          1/1     Running   0          4m1s
pod/fluentd-gcp-v3.1.1-w8rhw                                    2/2     Running   0          3m38s
pod/heapster-gke-54fdfc9bd4-gs9cf                               3/3     Running   0          3m6s
pod/kube-dns-5877696fb4-5b2dp                                   4/4     Running   0          4m6s
pod/kube-dns-autoscaler-8687c64fc-gj9rg                         1/1     Running   0          4m1s
pod/kube-proxy-gke-cluster-1-default-pool-fe6f5f88-br21         1/1     Running   0          3m57s
pod/l7-default-backend-8f479dd9-fpcch                           1/1     Running   0          4m6s
pod/metrics-server-v0.3.1-5c6fbf777-rs45z                       2/2     Running   0          3m43s
pod/prometheus-to-sd-84v7h                                      2/2     Running   0          3m57s
pod/stackdriver-metadata-agent-cluster-level-69454f8dd5-p7w7b   1/1     Running   0          4m5s

NAME                           TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)         AGE
service/default-http-backend   NodePort    10.0.5.107   <none>        80:30406/TCP    4m6s
service/heapster               ClusterIP   10.0.0.114   <none>        80/TCP          4m5s
service/kube-dns               ClusterIP   10.0.0.10    <none>        53/UDP,53/TCP   4m7s
service/metrics-server         ClusterIP   10.0.5.80    <none>        443/TCP         4m3s

NAME                                      DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR                                                              AGE
daemonset.apps/fluentd-gcp-v3.1.1         1         1         1       1            1           beta.kubernetes.io/fluentd-ds-ready=true,beta.kubernetes.io/os=linux       4m6s
daemonset.apps/metadata-proxy-v0.1        0         0         0       0            0           beta.kubernetes.io/metadata-proxy-ready=true,beta.kubernetes.io/os=linux   4m5s
daemonset.apps/nvidia-gpu-device-plugin   0         0         0       0            0           <none>                                                                     4m1s
daemonset.apps/prometheus-to-sd           1         1         1       1            1           beta.kubernetes.io/os=linux                                                4m5s

NAME                                                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/event-exporter-v0.2.5                      1/1     1            1           4m5s
deployment.apps/fluentd-gcp-scaler                         1/1     1            1           4m1s
deployment.apps/heapster-gke                               1/1     1            1           4m6s
deployment.apps/kube-dns                                   1/1     1            1           4m7s
deployment.apps/kube-dns-autoscaler                        1/1     1            1           4m6s
deployment.apps/l7-default-backend                         1/1     1            1           4m6s
deployment.apps/metrics-server-v0.3.1                      1/1     1            1           4m4s
deployment.apps/stackdriver-metadata-agent-cluster-level   1/1     1            1           4m5s

NAME                                                                  DESIRED   CURRENT   READY   AGE
replicaset.apps/event-exporter-v0.2.5-7df89f4b8f                      1         1         1       4m5s
replicaset.apps/fluentd-gcp-scaler-54ccb89d5                          1         1         1       4m1s
replicaset.apps/heapster-gke-54fdfc9bd4                               1         1         1       3m6s
replicaset.apps/heapster-gke-7fbb79848                                0         0         0       4m6s
replicaset.apps/kube-dns-5877696fb4                                   1         1         1       4m7s
replicaset.apps/kube-dns-autoscaler-8687c64fc                         1         1         1       4m6s
replicaset.apps/l7-default-backend-8f479dd9                           1         1         1       4m6s
replicaset.apps/metrics-server-v0.3.1-5c6fbf777                       1         1         1       3m43s
replicaset.apps/metrics-server-v0.3.1-8559697b9c                      0         0         0       4m4s
replicaset.apps/stackdriver-metadata-agent-cluster-level-69454f8dd5   1         1         1       4m5s

```

fluentd-gcp-v3.1.1 の定義を確認
-------------------------

Pod 内には fluentd-gcp と prometheus-to-sd-exporter という2つのコンテナが含まれています。後者は fluentd の prometheus plugin が提供する endpoint を polling して定期的にメトリクスを Cloud Monitoring (旧 Stackdriver Monitoring) に送信しています。似たようなやつが DamonSet にもいて、各 node で kubelet, kube-proxy の Prometheus 用メトリクスを Cloud Monitoring に送っています。

```
$ kubectl get -n kube-system daemonset.apps/fluentd-gcp-v3.1.1 -o yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  annotations:
    (省略)
  generation: 2
  labels:
    addonmanager.kubernetes.io/mode: Reconcile
    k8s-app: fluentd-gcp
    kubernetes.io/cluster-service: "true"
    version: v3.1.1
  name: fluentd-gcp-v3.1.1
  namespace: kube-system
  resourceVersion: "786"
  selfLink: /apis/apps/v1/namespaces/kube-system/daemonsets/fluentd-gcp-v3.1.1
  uid: 3eeada2a-6530-11ea-a16f-42010a920085
spec:
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      k8s-app: fluentd-gcp
      kubernetes.io/cluster-service: "true"
      version: v3.1.1
  template:
    metadata:
      annotations:
        scheduler.alpha.kubernetes.io/critical-pod: ""
      creationTimestamp: null
      labels:
        k8s-app: fluentd-gcp
        kubernetes.io/cluster-service: "true"
        version: v3.1.1
    spec:
      containers:
      - env:
        - name: NODE\_NAME
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: spec.nodeName
        - name: K8S\_NODE\_NAME
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: spec.nodeName
        - name: STACKDRIVER\_METADATA\_AGENT\_URL
          value: http://$(NODE\_NAME):8799
        image: gcr.io/stackdriver-agents/stackdriver-logging-agent:1.6.17-16060
        imagePullPolicy: IfNotPresent
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - |2

              LIVENESS\_THRESHOLD\_SECONDS=${LIVENESS\_THRESHOLD\_SECONDS:-300}; STUCK\_THRESHOLD\_SECONDS=${STUCK\_THRESHOLD\_SECONDS:-900}; if \[ ! -e /var/run/google-fluentd/buffers \]; then
                exit 1;
              fi; touch -d "${STUCK\_THRESHOLD\_SECONDS} seconds ago" /tmp/marker-stuck; if \[ -z "$(find /var/run/google-fluentd/buffers -type d -newer /tmp/marker-stuck -print -quit)" \]; then
                rm -rf /var/run/google-fluentd/buffers;
                exit 1;
              fi; touch -d "${LIVENESS\_THRESHOLD\_SECONDS} seconds ago" /tmp/marker-liveness; if \[ -z "$(find /var/run/google-fluentd/buffers -type d -newer /tmp/marker-liveness -print -quit)" \]; then
                exit 1;
              fi;
          failureThreshold: 3
          initialDelaySeconds: 600
          periodSeconds: 60
          successThreshold: 1
          timeoutSeconds: 1
        name: fluentd-gcp
        resources:
          limits:
            cpu: "1"
            memory: 500Mi
          requests:
            cpu: 100m
            memory: 200Mi
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        volumeMounts:
        - mountPath: /var/run/google-fluentd
          name: varrun
        - mountPath: /var/log
          name: varlog
        - mountPath: /var/lib/docker/containers
          name: varlibdockercontainers
          readOnly: true
        - mountPath: /etc/google-fluentd/config.d
          name: config-volume
      - command:
        - /monitor
        - --stackdriver-prefix=container.googleapis.com/internal/addons
        - --api-override=https://monitoring.googleapis.com/
        - --source=fluentd:http://localhost:24231?whitelisted=stackdriver\_successful\_requests\_count,stackdriver\_failed\_requests\_count,stackdriver\_ingested\_entries\_count,stackdriver\_dropped\_entries\_count
        - --pod-id=$(POD\_NAME)
        - --namespace-id=$(POD\_NAMESPACE)
        env:
        - name: POD\_NAME
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: metadata.name
        - name: POD\_NAMESPACE
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: metadata.namespace
        image: k8s.gcr.io/prometheus-to-sd:v0.5.0
        imagePullPolicy: IfNotPresent
        name: prometheus-to-sd-exporter
        resources: {}
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      dnsPolicy: Default
      hostNetwork: true
      nodeSelector:
        beta.kubernetes.io/fluentd-ds-ready: "true"
        beta.kubernetes.io/os: linux
      priorityClassName: system-node-critical
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      serviceAccount: fluentd-gcp
      serviceAccountName: fluentd-gcp
      terminationGracePeriodSeconds: 30
      tolerations:
      - effect: NoExecute
        operator: Exists
      - effect: NoSchedule
        operator: Exists
      volumes:
      - hostPath:
          path: /var/run/google-fluentd
          type: ""
        name: varrun
      - hostPath:
          path: /var/log
          type: ""
        name: varlog
      - hostPath:
          path: /var/lib/docker/containers
          type: ""
        name: varlibdockercontainers
      - configMap:
          defaultMode: 420
          name: fluentd-gcp-config-v1.2.6
        name: config-volume
  updateStrategy:
    rollingUpdate:
      maxUnavailable: 1
    type: RollingUpdate
status:
  (省略)

```

fluentd の設定ファイルを読み解く
--------------------

fluentd の config file を確認します。**config.d** サブディレクトリ配下のファイルは **fluentd-gcp-config-v1.2.6** という ConfigMap に入っています。

```
$ kubectl -n kube-system exec -it -c fluentd-gcp \\
  $(kubectl get -n kube-system pods -l k8s-app=fluentd-gcp -o jsonpath='{.items\[0\].metadata.name}') \\
  -- ls -l /etc/google-fluentd/
total 12
drwxrwxrwx 3 root root 4096 Mar 13 13:41 config.d
-rw-r--r-- 1 root root 2195 Sep 24 21:11 google-fluentd.conf
drwxr-xr-x 2 root root 4096 Sep 24 21:11 plugin

$ kubectl -n kube-system exec -it -c fluentd-gcp \\
  $(kubectl get -n kube-system pods -l k8s-app=fluentd-gcp -o jsonpath='{.items\[0\].metadata.name}') \\
  -- ls -l /etc/google-fluentd/config.d/
total 0
lrwxrwxrwx 1 root root 28 Mar 13 13:41 containers.input.conf -> ..data/containers.input.conf
lrwxrwxrwx 1 root root 22 Mar 13 13:41 monitoring.conf -> ..data/monitoring.conf
lrwxrwxrwx 1 root root 18 Mar 13 13:41 output.conf -> ..data/output.conf
lrwxrwxrwx 1 root root 24 Mar 13 13:41 system.input.conf -> ..data/system.input.conf

```

### /etc/google-fluentd/google-fluentd.conf

まずはメインのファイルです。この中に `@include config.d/*.conf` とあり、**config.d** 配下のファイルが読み込まれています。

`@type prometheus`, `@type prometheus_monitor` というのがありますが。「[fluent-plugin-prometheusをリリースしました - Qiita](https://qiita.com/kazegusuri/items/d526cbbf9807d0daec75)」ですね。先に紹介した **prometheus-to-sd-exporter** コンテナはこの plugin が提供する endpoint にアクセスしています。

`@type add_insert_ids` は送った先で重複してログを保存（もしくは集計）しないように各行にユニークなIDを振っているようです。そんな工夫がされていたんですね。retry の影響でログが重複してるよーって事にならないのは嬉しい。([filter\_add\_insert\_ids.rb](https://github.com/GoogleCloudPlatform/fluent-plugin-google-cloud/blob/master/lib/fluent/plugin/filter_add_insert_ids.rb))

次の `@type google_cloud` も Google の plugin で BufferedOutput で Cloud Logging に送る部分を担当しています。([out\_google\_cloud.rb](https://github.com/GoogleCloudPlatform/fluent-plugin-google-cloud/blob/master/lib/fluent/plugin/out_google_cloud.rb))ファイルに buffering して複数スレッドで gRPC で送るみたいですね。

```
\# Master configuration file for google-fluentd

# Include any configuration files in the config.d directory.
#
# An example "catch-all" configuration can be found at
# https://github.com/GoogleCloudPlatform/fluentd-catch-all-config
@include config.d/\*.conf

# Prometheus monitoring.
<source>
  @type prometheus
  port 24231
</source>
<source>
  @type prometheus\_monitor
</source>

# Do not collect fluentd's own logs to avoid infinite loops.
<match fluent.\*\*>
  @type null
</match>

# Add a unique insertId to each log entry that doesn't already have it.
# This helps guarantee the order and prevent log duplication.
<filter \*\*>
  @type add\_insert\_ids
</filter>

# Configure all sources to output to Google Cloud Logging
<match \*\*>
  @type google\_cloud
  buffer\_type file
  buffer\_path /var/log/google-fluentd/buffers
  # Set the chunk limit conservatively to avoid exceeding the recommended
  # chunk size of 5MB per write request.
  buffer\_chunk\_limit 512KB
  # Flush logs every 5 seconds, even if the buffer is not full.
  flush\_interval 5s
  # Enforce some limit on the number of retries.
  disable\_retry\_limit false
  # After 3 retries, a given chunk will be discarded.
  retry\_limit 3
  # Wait 10 seconds before the first retry. The wait interval will be doubled on
  # each following retry (20s, 40s...) until it hits the retry limit.
  retry\_wait 10
  # Never wait longer than 5 minutes between retries. If the wait interval
  # reaches this limit, the exponentiation stops.
  # Given the default config, this limit should never be reached, but if
  # retry\_limit and retry\_wait are customized, this limit might take effect.
  max\_retry\_wait 300
  # Use multiple threads for processing.
  num\_threads 8
  detect\_json true
  # Enable metadata agent lookups.
  enable\_metadata\_agent true
  metadata\_agent\_url "http://local-metadata-agent.stackdriver.com:8000"
  # Use the gRPC transport.
  use\_grpc true
  # If a request is a mix of valid log entries and invalid ones, ingest the
  # valid ones and drop the invalid ones instead of dropping everything.
  partial\_success true
  # Enable monitoring via Prometheus integration.
  enable\_monitoring true
  monitoring\_type prometheus
</match>

```

### /etc/google-fluentd/config.d/containers.input.conf

次は containers.input.conf です。名前の通り各コンテナのログを **/var/log/containers/\*.log** をtail で読み出してます。そう、docker の fluentd log driver を使うわけではないんですね。(docker と containerd の関係とか良くわからん)

その後は kubernetes の metadata を付加して行きます。plugin 書いてたりするのに record\_modifier で ruby で処理したりもするんですね。

最後の `@type detect_exceptions` は複数行に渡る stack trace を発見すると1つのメッセージにまとめてくれる便利 plugin のようです。([GoogleCloudPlatform/fluent-plugin-detect-exceptions](https://github.com/GoogleCloudPlatform/fluent-plugin-detect-exceptions))

```
\# This configuration file for Fluentd is used
# to watch changes to Docker log files that live in the
# directory /var/lib/docker/containers/ and are symbolically
# linked to from the /var/log/containers directory using names that capture the
# pod name and container name. These logs are then submitted to
# Google Cloud Logging which assumes the installation of the cloud-logging plug-in.
#
# Example
# =======
# A line in the Docker log file might look like this JSON:
#
# {"log":"2014/09/25 21:15:03 Got request with path wombat\\\\n",
#  "stream":"stderr",
#   "time":"2014-09-25T21:15:03.499185026Z"}
#
# The original tag is derived from the log file's location.
# For example a Docker container's logs might be in the directory:
#  /var/lib/docker/containers/997599971ee6366d4a5920d25b79286ad45ff37a74494f262e3bc98d909d0a7b
# and in the file:
#  997599971ee6366d4a5920d25b79286ad45ff37a74494f262e3bc98d909d0a7b-json.log
# where 997599971ee6... is the Docker ID of the running container.
# The Kubernetes kubelet makes a symbolic link to this file on the host
# machine in the /var/log/containers directory which includes the pod name,
# the namespace name and the Kubernetes container name:
#    synthetic-logger-0.25lps-pod\_default\_synth-lgr-997599971ee6366d4a5920d25b79286ad45ff37a74494f262e3bc98d909d0a7b.log
#    ->
#    /var/lib/docker/containers/997599971ee6366d4a5920d25b79286ad45ff37a74494f262e3bc98d909d0a7b/997599971ee6366d4a5920d25b79286ad45ff37a74494f262e3bc98d909d0a7b-json.log
# The /var/log directory on the host is mapped to the /var/log directory in the container
# running this instance of Fluentd and we end up collecting the file:
#   /var/log/containers/synthetic-logger-0.25lps-pod\_default\_synth-lgr-997599971ee6366d4a5920d25b79286ad45ff37a74494f262e3bc98d909d0a7b.log
# This results in the tag:
#  var.log.containers.synthetic-logger-0.25lps-pod\_default\_synth-lgr-997599971ee6366d4a5920d25b79286ad45ff37a74494f262e3bc98d909d0a7b.log
# where 'synthetic-logger-0.25lps-pod' is the pod name, 'default' is the
# namespace name, 'synth-lgr' is the container name and '997599971ee6..' is
# the container ID.
# The record reformer is used to extract pod\_name, namespace\_name and
# container\_name from the tag and set them in a local\_resource\_id in the
# format of:
# 'k8s\_container.<NAMESPACE\_NAME>.<POD\_NAME>.<CONTAINER\_NAME>'.
# The reformer also changes the tags to 'stderr' or 'stdout' based on the
# value of 'stream'.
# local\_resource\_id is later used by google\_cloud plugin to determine the
# monitored resource to ingest logs against.

# Json Log Example:
# {"log":"\[info:2016-02-16T16:04:05.930-08:00\] Some log text here\\n","stream":"stdout","time":"2016-02-17T00:04:05.931087621Z"}
# CRI Log Example:
# 2016-02-17T00:04:05.931087621Z stdout F \[info:2016-02-16T16:04:05.930-08:00\] Some log text here
<source>
  @type tail
  
  path /var/log/containers/\*.log
  
  
  pos\_file /var/run/google-fluentd/pos-files/gcp-containers.pos
  
  # Tags at this point are in the format of:
  # reform.var.log.containers.<POD\_NAME>\_<NAMESPACE\_NAME>\_<CONTAINER\_NAME>-<CONTAINER\_ID>.log
  tag reform.\*
  read\_from\_head true
  <parse>
    @type multi\_format
    <pattern>
      format json
      time\_key time
      time\_format %Y-%m-%dT%H:%M:%S.%NZ
    </pattern>
    <pattern>
      format /^(?<time>.+) (?<stream>stdout|stderr) \[^ \]\* (?<log>.\*)$/
      time\_format %Y-%m-%dT%H:%M:%S.%N%:z
    </pattern>
  </parse>
</source>

<filter reform.\*\*>
  @type parser
  format /^(?<severity>\\w)(?<time>\\d{4} \[^\\s\]\*)\\s+(?<pid>\\d+)\\s+(?<source>\[^ \\\]\]+)\\\] (?<log>.\*)/
  reserve\_data true
  suppress\_parse\_error\_log true
  emit\_invalid\_record\_to\_error false
  key\_name log
</filter>


<filter reform.\*\*>
  # This plugin uses environment variables KUBERNETES\_SERVICE\_HOST and
  # KUBERNETES\_SERVICE\_PORT to talk to the API server. These environment
  # variables are added by kubelet automatically.
  @type kubernetes\_metadata
  # Interval in seconds to dump cache stats locally in the Fluentd log.
  stats\_interval 300
  # TTL in seconds of each cached element.
  cache\_ttl 30
  
  # Skip fetching unused metadata.
  skip\_container\_metadata true
  skip\_master\_url true
  skip\_namespace\_metadata true
  
</filter>

<filter reform.\*\*>
  # We have to use record\_modifier because only this plugin supports complex
  # logic to modify record the way we need.
  @type record\_modifier
  enable\_ruby true
  <record>
    # Extract "kubernetes"->"labels" and set them as
    # "logging.googleapis.com/labels". Prefix these labels with
    # "k8s-pod" to distinguish with other labels and avoid
    # label name collision with other types of labels.
    \_dummy\_ ${if record.is\_a?(Hash) && record.has\_key?('kubernetes') && record\['kubernetes'\].has\_key?('labels') && record\['kubernetes'\]\['labels'\].is\_a?(Hash); then; record\["logging.googleapis.com/labels"\] = record\['kubernetes'\]\['labels'\].map{ |k, v| \["k8s-pod/#{k}", v\]}.to\_h; end; nil}
  </record>
  # Delete this dummy field and the rest of "kubernetes" and "docker".
  remove\_keys \_dummy\_,kubernetes,docker
</filter>


<match reform.\*\*>
  @type record\_reformer
  enable\_ruby true
  <record>
    # Extract local\_resource\_id from tag for 'k8s\_container' monitored
    # resource. The format is:
    # 'k8s\_container.<namespace\_name>.<pod\_name>.<container\_name>'.
    "logging.googleapis.com/local\_resource\_id" ${"k8s\_container.#{tag\_suffix\[4\].rpartition('.')\[0\].split('\_')\[1\]}.#{tag\_suffix\[4\].rpartition('.')\[0\].split('\_')\[0\]}.#{tag\_suffix\[4\].rpartition('.')\[0\].split('\_')\[2\].rpartition('-')\[0\]}"}
    # Rename the field 'log' to a more generic field 'message'. This way the
    # fluent-plugin-google-cloud knows to flatten the field as textPayload
    # instead of jsonPayload after extracting 'time', 'severity' and
    # 'stream' from the record.
    message ${record\['log'\]}
    # If 'severity' is not set, assume stderr is ERROR and stdout is INFO.
    severity ${record\['severity'\] || if record\['stream'\] == 'stderr' then 'ERROR' else 'INFO' end}
  </record>
  tag ${if record\['stream'\] == 'stderr' then 'raw.stderr' else 'raw.stdout' end}
  remove\_keys stream,log
</match>

# Detect exceptions in the log output and forward them as one log entry.
<match {raw.stderr,raw.stdout}>
  @type detect\_exceptions

  remove\_tag\_prefix raw
  message message
  stream "logging.googleapis.com/local\_resource\_id"
  multiline\_flush\_interval 5
  max\_bytes 500000
  max\_lines 1000
</match>

```

### /etc/google-fluentd/config.d/monitoring.conf

次は monitoring.onf です。これは短い。

`@type exec` で `date +%s` コマンドを実行し、unix timestamp を process\_start\_timestamp という key に入れます。

その後、型を Integer に変換して終わり。続きは次のファイルです。

```
\# This source is used to acquire approximate process start timestamp,
# which purpose is explained before the corresponding output plugin.
<source>
  @type exec
  command /bin/sh -c 'date +%s'
  tag process\_start
  time\_format %Y-%m-%d %H:%M:%S
  keys process\_start\_timestamp
</source>

# This filter is used to convert process start timestamp to integer
# value for correct ingestion in the prometheus output plugin.
<filter process\_start>
  @type record\_transformer
  enable\_ruby true
  auto\_typecast true
  <record>
    process\_start\_timestamp ${record\["process\_start\_timestamp"\].to\_i}
  </record>
</filter>

```

### /etc/google-fluentd/config.d/output.conf

次は output.conf です。最初のファイルで全部 Cloud Logging に送るようになってたじゃんって思うわけですが、ここでも出てきます。

まずは `@type prometheus` です。なるほどそういうことかって感じですね。さっきの process\_start\_timestamp は prometheus で良くあるプロセスの起動時刻用だったのです。

次も prometheus 用で読み込んだログの行数カウンターです。

その次は stdout, stderr タグのメッセージについて、Cloud Logging は1メッセージあたり100KBという制限があるために、100000 Bytes を超える場合はそれ以降を切り捨てて `[Trimmed]` っていう prefix を入れます。しかし、**.length** だとマルチバイトの時に制限超えちゃうんじゃないの？？？

"This section is exclusive for k8s\_container logs." ってのは k8s\_container っていう新しい Kubernetes Engine Monitoring 専用って事ですね。

次は **fluent.\*** は fluentd 自身のログなので捨てる。

その後また `@type add_insert_ids` が出てくるけど、すでに unique id が存在したら何もしないらしいので重複して適用しても大丈夫みたい。

後はまた metadata いじって Cloud Logging に送る。

```
\# This match is placed before the all-matching output to provide metric
# exporter with a process start timestamp for correct exporting of
# cumulative metrics to Stackdriver.
<match process\_start>
  @type prometheus

  <metric>
    type gauge
    name process\_start\_time\_seconds
    desc Timestamp of the process start in seconds
    key process\_start\_timestamp
  </metric>
</match>

# This filter allows to count the number of log entries read by fluentd
# before they are processed by the output plugin. This in turn allows to
# monitor the number of log entries that were read but never sent, e.g.
# because of liveness probe removing buffer.
<filter \*\*>
  @type prometheus
  <metric>
    type counter
    name logging\_entry\_count
    desc Total number of log entries generated by either application containers or system components
  </metric>
</filter>

# This section is exclusive for k8s\_container logs. Those come with
# 'stderr'/'stdout' tags.
# TODO(instrumentation): Reconsider this workaround later.
# Trim the entries which exceed slightly less than 100KB, to avoid
# dropping them. It is a necessity, because Stackdriver only supports
# entries that are up to 100KB in size.
<filter {stderr,stdout}>
  @type record\_transformer
  enable\_ruby true
  <record>
    message ${record\['message'\].length > 100000 ? "\[Trimmed\]#{record\['message'\]\[0..100000\]}..." : record\['message'\]}
  </record>
</filter>

# Do not collect fluentd's own logs to avoid infinite loops.
<match fluent.\*\*>
  @type null
</match>

# Add a unique insertId to each log entry that doesn't already have it.
# This helps guarantee the order and prevent log duplication.
<filter \*\*>
  @type add\_insert\_ids
</filter>

# This filter parses the 'source' field created for glog lines into a single
# top-level field, for proper processing by the output plugin.
# For example, if a record includes:
#     {"source":"handlers.go:131"},
# then the following entry will be added to the record:
#     {"logging.googleapis.com/sourceLocation":
#          {"file":"handlers.go", "line":"131"}
#     }
<filter \*\*>
  @type record\_transformer
  enable\_ruby true
  <record>
    "logging.googleapis.com/sourceLocation" ${if record.is\_a?(Hash) && record.has\_key?('source'); source\_parts = record\['source'\].split(':', 2); {'file' => source\_parts\[0\], 'line' => source\_parts\[1\]} if source\_parts.length == 2; else; nil; end}
  </record>
</filter>


# This section is exclusive for k8s\_container logs. These logs come with
# 'stderr'/'stdout' tags.
# We use a separate output stanza for 'k8s\_node' logs with a smaller buffer
# because node logs are less important than user's container logs.
<match {stderr,stdout}>
  @type google\_cloud

  # Try to detect JSON formatted log entries.
  detect\_json true
  # Collect metrics in Prometheus registry about plugin activity.
  enable\_monitoring true
  monitoring\_type prometheus
  # Allow log entries from multiple containers to be sent in the same request.
  split\_logs\_by\_tag false
  # Set the buffer type to file to improve the reliability and reduce the memory consumption
  buffer\_type file
  
  buffer\_path /var/run/google-fluentd/buffers/kubernetes.containers.buffer
  
  # Set queue\_full action to block because we want to pause gracefully
  # in case of the off-the-limits load instead of throwing an exception
  buffer\_queue\_full\_action block
  # Set the chunk limit conservatively to avoid exceeding the recommended
  # chunk size of 5MB per write request.
  buffer\_chunk\_limit 512k
  # Cap the combined memory usage of this buffer and the one below to
  # 512KiB/chunk \* (6 + 2) chunks = 4 MiB
  buffer\_queue\_limit 6
  # Never wait more than 5 seconds before flushing logs in the non-error case.
  flush\_interval 5s
  # Never wait longer than 30 seconds between retries.
  max\_retry\_wait 30
  # Disable the limit on the number of retries (retry forever).
  disable\_retry\_limit
  # Use multiple threads for processing.
  num\_threads 2
  use\_grpc true
  # Skip timestamp adjustment as this is in a controlled environment with
  # known timestamp format. This helps with CPU usage.
  adjust\_invalid\_timestamps false
</match>

# Attach local\_resource\_id for 'k8s\_node' monitored resource.
<filter \*\*>
  @type record\_transformer
  enable\_ruby true
  <record>
    "logging.googleapis.com/local\_resource\_id" ${"k8s\_node.#{ENV\['NODE\_NAME'\]}"}
  </record>
</filter>

# This section is exclusive for 'k8s\_node' logs. These logs come with tags
# that are neither 'stderr' or 'stdout'.
# We use a separate output stanza for 'k8s\_container' logs with a larger
# buffer because user's container logs are more important than node logs.
<match \*\*>
  @type google\_cloud

  detect\_json true
  enable\_monitoring true
  monitoring\_type prometheus
  # Allow entries from multiple system logs to be sent in the same request.
  split\_logs\_by\_tag false
  detect\_subservice false
  buffer\_type file
  
  buffer\_path /var/run/google-fluentd/buffers/kubernetes.system.buffer
  
  buffer\_queue\_full\_action block
  buffer\_chunk\_limit 512k
  buffer\_queue\_limit 2
  flush\_interval 5s
  max\_retry\_wait 30
  disable\_retry\_limit
  num\_threads 2
  use\_grpc true
  # Skip timestamp adjustment as this is in a controlled environment with
  # known timestamp format. This helps with CPU usage.
  adjust\_invalid\_timestamps false
</match>

```

### /etc/google-fluentd/config.d/system.input.conf

これで最後、system.input.conf です。

/var/log 配下のログや systemd の journal log から読み出す設定です。Control Plane でも使われているのか api server とか etcd 用の設定も入ってますね。

```
\# Example:
# Dec 21 23:17:22 gke-foo-1-1-4b5cbd14-node-4eoj startupscript: Finished running startup script /var/run/google.startup.script
<source>
  @type tail
  format syslog
  path /var/log/startupscript.log
  
  pos\_file /var/run/google-fluentd/pos-files/gcp-startupscript.pos
  
  tag startupscript
</source>

# Examples:
# time="2016-02-04T06:51:03.053580605Z" level=info msg="GET /containers/json"
# time="2016-02-04T07:53:57.505612354Z" level=error msg="HTTP Error" err="No such image: -f" statusCode=404
# TODO(random-liu): Remove this after cri container runtime rolls out.
<source>
  @type tail
  format /^time="(?<time>\[^)\]\*)" level=(?<severity>\[^ \]\*) msg="(?<message>\[^"\]\*)"( err="(?<error>\[^"\]\*)")?( statusCode=($<status\_code>\\d+))?/
  path /var/log/docker.log
  
  pos\_file /var/run/google-fluentd/pos-files/gcp-docker.pos
  
  tag docker
</source>

# Example:
# 2016/02/04 06:52:38 filePurge: successfully removed file /var/etcd/data/member/wal/00000000000006d0-00000000010a23d1.wal
<source>
  @type tail
  # Not parsing this, because it doesn't have anything particularly useful to
  # parse out of it (like severities).
  format none
  path /var/log/etcd.log
  
  pos\_file /var/run/google-fluentd/pos-files/gcp-etcd.pos
  
  tag etcd
</source>

# Multi-line parsing is required for all the kube logs because very large log
# statements, such as those that include entire object bodies, get split into
# multiple lines by glog.

# Example:
# I0204 07:32:30.020537    3368 server.go:1048\] POST /stats/container/: (13.972191ms) 200 \[\[Go-http-client/1.1\] 10.244.1.3:40537\]
<source>
  @type tail
  format multiline
  multiline\_flush\_interval 5s
  format\_firstline /^\\w\\d{4}/
  format1 /^(?<severity>\\w)(?<time>\\d{4} \[^\\s\]\*)\\s+(?<pid>\\d+)\\s+(?<source>\[^ \\\]\]+)\\\] (?<message>.\*)/
  time\_format %m%d %H:%M:%S.%N
  path /var/log/kubelet.log
  
  pos\_file /var/run/google-fluentd/pos-files/gcp-kubelet.pos
  
  tag kubelet
</source>

# Example:
# I1118 21:26:53.975789       6 proxier.go:1096\] Port "nodePort for kube-system/default-http-backend:http" (:31429/tcp) was open before and is still needed
<source>
  @type tail
  format multiline
  multiline\_flush\_interval 5s
  format\_firstline /^\\w\\d{4}/
  format1 /^(?<severity>\\w)(?<time>\\d{4} \[^\\s\]\*)\\s+(?<pid>\\d+)\\s+(?<source>\[^ \\\]\]+)\\\] (?<message>.\*)/
  time\_format %m%d %H:%M:%S.%N
  path /var/log/kube-proxy.log
  
  pos\_file /var/run/google-fluentd/pos-files/gcp-kube-proxy.pos
  
  tag kube-proxy
</source>

# Example:
# I0204 07:00:19.604280       5 handlers.go:131\] GET /api/v1/nodes: (1.624207ms) 200 \[\[kube-controller-manager/v1.1.3 (linux/amd64) kubernetes/6a81b50\] 127.0.0.1:38266\]
<source>
  @type tail
  format multiline
  multiline\_flush\_interval 5s
  format\_firstline /^\\w\\d{4}/
  format1 /^(?<severity>\\w)(?<time>\\d{4} \[^\\s\]\*)\\s+(?<pid>\\d+)\\s+(?<source>\[^ \\\]\]+)\\\] (?<message>.\*)/
  time\_format %m%d %H:%M:%S.%N
  path /var/log/kube-apiserver.log
  
  pos\_file /var/run/google-fluentd/pos-files/gcp-kube-apiserver.pos
  
  tag kube-apiserver
</source>

# Example:
# I0204 06:55:31.872680       5 servicecontroller.go:277\] LB already exists and doesn't need update for service kube-system/kube-ui
<source>
  @type tail
  format multiline
  multiline\_flush\_interval 5s
  format\_firstline /^\\w\\d{4}/
  format1 /^(?<severity>\\w)(?<time>\\d{4} \[^\\s\]\*)\\s+(?<pid>\\d+)\\s+(?<source>\[^ \\\]\]+)\\\] (?<message>.\*)/
  time\_format %m%d %H:%M:%S.%N
  path /var/log/kube-controller-manager.log
  
  pos\_file /var/run/google-fluentd/pos-files/gcp-kube-controller-manager.pos
  
  tag kube-controller-manager
</source>

# Example:
# W0204 06:49:18.239674       7 reflector.go:245\] pkg/scheduler/factory/factory.go:193: watch of \*api.Service ended with: 401: The event in requested index is outdated and cleared (the requested history has been cleared \[2578313/2577886\]) \[2579312\]
<source>
  @type tail
  format multiline
  multiline\_flush\_interval 5s
  format\_firstline /^\\w\\d{4}/
  format1 /^(?<severity>\\w)(?<time>\\d{4} \[^\\s\]\*)\\s+(?<pid>\\d+)\\s+(?<source>\[^ \\\]\]+)\\\] (?<message>.\*)/
  time\_format %m%d %H:%M:%S.%N
  path /var/log/kube-scheduler.log
  
  pos\_file /var/run/google-fluentd/pos-files/gcp-kube-scheduler.pos
  
  tag kube-scheduler
</source>

# Example:
# I1104 10:36:20.242766       5 rescheduler.go:73\] Running Rescheduler
<source>
  @type tail
  format multiline
  multiline\_flush\_interval 5s
  format\_firstline /^\\w\\d{4}/
  format1 /^(?<severity>\\w)(?<time>\\d{4} \[^\\s\]\*)\\s+(?<pid>\\d+)\\s+(?<source>\[^ \\\]\]+)\\\] (?<message>.\*)/
  time\_format %m%d %H:%M:%S.%N
  path /var/log/rescheduler.log
  
  pos\_file /var/run/google-fluentd/pos-files/gcp-rescheduler.pos
  
  tag rescheduler
</source>

# Example:
# I0603 15:31:05.793605       6 cluster\_manager.go:230\] Reading config from path /etc/gce.conf
<source>
  @type tail
  format multiline
  multiline\_flush\_interval 5s
  format\_firstline /^\\w\\d{4}/
  format1 /^(?<severity>\\w)(?<time>\\d{4} \[^\\s\]\*)\\s+(?<pid>\\d+)\\s+(?<source>\[^ \\\]\]+)\\\] (?<message>.\*)/
  time\_format %m%d %H:%M:%S.%N
  path /var/log/glbc.log
  
  pos\_file /var/run/google-fluentd/pos-files/gcp-glbc.pos
  
  tag glbc
</source>

# Example:
# I0603 15:31:05.793605       6 cluster\_manager.go:230\] Reading config from path /etc/gce.conf
<source>
  @type tail
  format multiline
  multiline\_flush\_interval 5s
  format\_firstline /^\\w\\d{4}/
  format1 /^(?<severity>\\w)(?<time>\\d{4} \[^\\s\]\*)\\s+(?<pid>\\d+)\\s+(?<source>\[^ \\\]\]+)\\\] (?<message>.\*)/
  time\_format %m%d %H:%M:%S.%N
  path /var/log/cluster-autoscaler.log
  
  pos\_file /var/run/google-fluentd/pos-files/gcp-cluster-autoscaler.pos
  
  tag cluster-autoscaler
</source>

# Logs from systemd-journal for interesting services.
# TODO(random-liu): Keep this for compatibility, remove this after
# cri container runtime rolls out.
<source>
  @type systemd
  filters \[{ "\_SYSTEMD\_UNIT": "docker.service" }\]
  
  <storage>
    @type local
    path /var/run/google-fluentd/pos-files/gcp-journald-docker.pos
  </storage>
  
  read\_from\_head true
  tag docker
</source>

<source>
  @type systemd
  filters \[{ "\_SYSTEMD\_UNIT": "docker.service" }\]
  
  <storage>
    @type local
    path /var/run/google-fluentd/pos-files/gcp-journald-container-runtime.pos
  </storage>
  
  read\_from\_head true
  tag container-runtime
</source>

<source>
  @type systemd
  filters \[{ "\_SYSTEMD\_UNIT": "kubelet.service" }\]
  
  <storage>
    @type local
    path /var/run/google-fluentd/pos-files/gcp-journald-kubelet.pos
  </storage>
  
  read\_from\_head true
  tag kubelet
</source>


# kube-node-installation, kube-node-configuration, and kube-logrotate are
# oneshots, but it's extremely valuable to have their logs on Stackdriver
# as they can diagnose critical issues with node startup.
# See http://cs/cloud-gke-kubernetes/cluster/gce/gci/node.yaml.
<source>
  @type systemd
  filters \[{ "\_SYSTEMD\_UNIT": "kube-node-installation.service" }\]
  
  <storage>
    @type local
    path /var/run/google-fluentd/pos-files/gcp-journald-kube-node-installation.pos
  </storage>
  
  read\_from\_head true
  tag kube-node-installation
</source>

<source>
  @type systemd
  filters \[{ "\_SYSTEMD\_UNIT": "kube-node-configuration.service" }\]
  
  <storage>
    @type local
    path /var/run/google-fluentd/pos-files/gcp-journald-kube-node-configuration.pos
  </storage>
  
  read\_from\_head true
  tag kube-node-configuration
</source>

<source>
  @type systemd
  filters \[{ "\_SYSTEMD\_UNIT": "kube-logrotate.service" }\]
  
  <storage>
    @type local
    path /var/run/google-fluentd/pos-files/gcp-journald-kube-logrotate.pos
  </storage>
  
  read\_from\_head true
  tag kube-logrotate
</source>


<source>
  @type systemd
  filters \[{ "\_SYSTEMD\_UNIT": "node-problem-detector.service" }\]
  pos\_file /var/log/gcp-journald-node-problem-detector.pos
  read\_from\_head true
  tag node-problem-detector
</source>


<source>
  @type systemd
  filters \[{ "\_SYSTEMD\_UNIT": "kube-container-runtime-monitor.service" }\]
  pos\_file /var/log/gcp-journald-kube-container-runtime-monitor.pos
  read\_from\_head true
  tag kube-container-runtime-monitor
</source>

<source>
  @type systemd
  filters \[{ "\_SYSTEMD\_UNIT": "kubelet-monitor.service" }\]
  pos\_file /var/log/gcp-journald-kubelet-monitor.pos
  read\_from\_head true
  tag kubelet-monitor
</source>

```

まとめ
---

へぇ、GCP でもそんな風にやってるのかあって感じられて興味深かったです。