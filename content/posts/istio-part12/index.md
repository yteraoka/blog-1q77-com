---
title: 'Istio 導入への道 – sidecar の調整編'
description: |
  Istio sidecar の調整可能な設定項目の紹介
date: 2020-03-29T17:01:29+00:00
draft: false
tags: ['Istio', 'Kubernetes']
author: "@yteraoka"
image: cover.png
categories:
  - IT
---

[Istio シリーズ](/tags/istio/) 第12回です。

Istio は各 Pod に sidecar として Envoy コンテナを差し込み、通信の受信も送信も Envoy を経由します。アプリの更新時などに旧バージョンの Pod の停止する時、先に Envoy コンテナが停止してしまうとアプリのコンテナが通信できなくなり処理が完了できなくなったりします。開始時にもコンテナの起動順序は不定であるため起動スクリプトの調整や LivnessProbe, ReadinessProbe は重要です。

preStop フック
-----------

そこで、sidecar である Envoy が先に終了してしまわないようにするために Pod の [preStop hook](https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/#hook-details) を活用することができます。

Envoy sidecar は istio によって deploy 時に inject されますが、どんな設定を inject するかは istio-system ネームスペースにある istio-sidecar-injector という ConfigMap に定義されています。

```
$ kubectl get configmap -n istio-system
NAME                     DATA   AGE
istio                    3      21d
istio-ca-root-cert       1      21d
istio-leader             0      21d
istio-security           1      21d
istio-sidecar-injector   2      21d
pilot-envoy-config       1      21d
prometheus               1      21d
```

config にテンプレートなどと、そのテンプレートに渡す values という変数が入っています。

### istio-sidecar-injector ConfigMap の config

```bash
kubectl get configmap -n istio-system istio-sidecar-injector -o jsonpath='{.data.config}'
```

```yaml
policy: enabled
alwaysInjectSelector:
        []
neverInjectSelector:
        []
injectedAnnotations:

# Configmap optimized for Istiod. Please DO NOT MERGE all changes from istio - in particular those dependent on
# Values.yaml, which should not be used by istiod.

# Istiod only uses SDS based config ( files will mapped/handled by SDS).

template: |
  rewriteAppHTTPProbe: {{ valueOrDefault .Values.sidecarInjectorWebhook.rewriteAppHTTPProbe false }}
  initContainers:
  {{ if ne (annotation .ObjectMeta `sidecar.istio.io/interceptionMode` .ProxyConfig.InterceptionMode) `NONE` }}
  {{ if .Values.istio_cni.enabled -}}
  - name: istio-validation
  {{ else -}}
  - name: istio-init
  {{ end -}}
  {{- if contains "/" .Values.global.proxy_init.image }}
    image: "{{ .Values.global.proxy_init.image }}"
  {{- else }}
    image: "{{ .Values.global.hub }}/{{ .Values.global.proxy_init.image }}:{{ .Values.global.tag }}"
  {{- end }}
    command:
    - istio-iptables
    - "-p"
    - 15001
    - "-z"
    - "15006"
    - "-u"
    - 1337
    - "-m"
    - "{{ annotation .ObjectMeta `sidecar.istio.io/interceptionMode` .ProxyConfig.InterceptionMode }}"
    - "-i"
    - "{{ annotation .ObjectMeta `traffic.sidecar.istio.io/includeOutboundIPRanges` .Values.global.proxy.includeIPRanges }}"
    - "-x"
    - "{{ annotation .ObjectMeta `traffic.sidecar.istio.io/excludeOutboundIPRanges` .Values.global.proxy.excludeIPRanges }}"
    - "-b"
    - "{{ annotation .ObjectMeta `traffic.sidecar.istio.io/includeInboundPorts` `*` }}"
    - "-d"
    - "15090,{{ excludeInboundPort (annotation .ObjectMeta `status.sidecar.istio.io/port` .Values.global.proxy.statusPort) (annotation .ObjectMeta `traffic.sidecar.istio.io/excludeInboundPorts` .Values.global.proxy.excludeInboundPorts) }}"
    {{ if or (isset .ObjectMeta.Annotations `traffic.sidecar.istio.io/excludeOutboundPorts`) (ne (valueOrDefault .Values.global.proxy.excludeOutboundPorts "") "") -}}
    - "-o"
    - "{{ annotation .ObjectMeta `traffic.sidecar.istio.io/excludeOutboundPorts` .Values.global.proxy.excludeOutboundPorts }}"
    {{ end -}}
    {{ if (isset .ObjectMeta.Annotations `traffic.sidecar.istio.io/kubevirtInterfaces`) -}}
    - "-k"
    - "{{ index .ObjectMeta.Annotations `traffic.sidecar.istio.io/kubevirtInterfaces` }}"
    {{ end -}}
    {{ if .Values.istio_cni.enabled -}}
    - "--run-validation"
    - "--skip-rule-apply"
    {{ end -}}
    imagePullPolicy: "{{ valueOrDefault .Values.global.imagePullPolicy `Always` }}"
  {{- if .Values.global.proxy_init.resources }}
    resources:
      {{ toYaml .Values.global.proxy_init.resources | indent 4 }}
  {{- else }}
    resources: {}
  {{- end }}
    securityContext:
      allowPrivilegeEscalation: {{ .Values.global.proxy.privileged }}
      privileged: {{ .Values.global.proxy.privileged }}
      capabilities:
    {{- if not .Values.istio_cni.enabled }}
        add:
        - NET_ADMIN
        - NET_RAW
    {{- end }}
        drop:
        - ALL
      readOnlyRootFilesystem: false
    {{- if not .Values.istio_cni.enabled }}
      runAsGroup: 0
      runAsNonRoot: false
      runAsUser: 0
    {{- else }}
      runAsGroup: 1337
      runAsUser: 1337
      runAsNonRoot: true
    {{- end }}
    restartPolicy: Always
  {{ end -}}
  {{- if eq .Values.global.proxy.enableCoreDump true }}
  - name: enable-core-dump
    args:
    - -c
    - sysctl -w kernel.core_pattern=/var/lib/istio/core.proxy && ulimit -c unlimited
    command:
      - /bin/sh
  {{- if contains "/" .Values.global.proxy_init.image }}
    image: "{{ .Values.global.proxy_init.image }}"
  {{- else }}
    image: "{{ .Values.global.hub }}/{{ .Values.global.proxy_init.image }}:{{ .Values.global.tag }}"
  {{- end }}
    imagePullPolicy: "{{ valueOrDefault .Values.global.imagePullPolicy `Always` }}"
    resources: {}
    securityContext:
      allowPrivilegeEscalation: true
      capabilities:
        add:
        - SYS_ADMIN
        drop:
        - ALL
      privileged: true
      readOnlyRootFilesystem: false
      runAsGroup: 0
      runAsNonRoot: false
      runAsUser: 0
  {{ end }}
  containers:
  - name: istio-proxy
  {{- if contains "/" (annotation .ObjectMeta `sidecar.istio.io/proxyImage` .Values.global.proxy.image) }}
    image: "{{ annotation .ObjectMeta `sidecar.istio.io/proxyImage` .Values.global.proxy.image }}"
  {{- else }}
    image: "{{ .Values.global.hub }}/{{ .Values.global.proxy.image }}:{{ .Values.global.tag }}"
  {{- end }}
    ports:
    - containerPort: 15090
      protocol: TCP
      name: http-envoy-prom
    args:
    - proxy
    - sidecar
    - --domain
    - $(POD_NAMESPACE).svc.{{ .Values.global.proxy.clusterDomain }}
    - --configPath
    - "/etc/istio/proxy"
    - --binaryPath
    - "/usr/local/bin/envoy"
    - --serviceCluster
    {{ if ne "" (index .ObjectMeta.Labels "app") -}}
    - "{{ index .ObjectMeta.Labels `app` }}.$(POD_NAMESPACE)"
    {{ else -}}
    - "{{ valueOrDefault .DeploymentMeta.Name `istio-proxy` }}.{{ valueOrDefault .DeploymentMeta.Namespace `default` }}"
    {{ end -}}
    - --drainDuration
    - "{{ formatDuration .ProxyConfig.DrainDuration }}"
    - --parentShutdownDuration
    - "{{ formatDuration .ProxyConfig.ParentShutdownDuration }}"
    - --discoveryAddress
    - "{{ annotation .ObjectMeta `sidecar.istio.io/discoveryAddress` .ProxyConfig.DiscoveryAddress }}"
  {{- if eq .Values.global.proxy.tracer "lightstep" }}
    - --lightstepAddress
    - "{{ .ProxyConfig.GetTracing.GetLightstep.GetAddress }}"
    - --lightstepAccessToken
    - "{{ .ProxyConfig.GetTracing.GetLightstep.GetAccessToken }}"
    - --lightstepSecure={{ .ProxyConfig.GetTracing.GetLightstep.GetSecure }}
    - --lightstepCacertPath
    - "{{ .ProxyConfig.GetTracing.GetLightstep.GetCacertPath }}"
  {{- else if eq .Values.global.proxy.tracer "zipkin" }}
    - --zipkinAddress
    - "{{ .ProxyConfig.GetTracing.GetZipkin.GetAddress }}"
  {{- else if eq .Values.global.proxy.tracer "datadog" }}
    - --datadogAgentAddress
    - "{{ .ProxyConfig.GetTracing.GetDatadog.GetAddress }}"
  {{- end }}
    - --proxyLogLevel={{ annotation .ObjectMeta `sidecar.istio.io/logLevel` .Values.global.proxy.logLevel}}
    - --proxyComponentLogLevel={{ annotation .ObjectMeta `sidecar.istio.io/componentLogLevel` .Values.global.proxy.componentLogLevel}}
    - --connectTimeout
    - "{{ formatDuration .ProxyConfig.ConnectTimeout }}"
  {{- if .Values.global.proxy.envoyStatsd.enabled }}
    - --statsdUdpAddress
    - "{{ .ProxyConfig.StatsdUdpAddress }}"
  {{- end }}
  {{- if .Values.global.proxy.envoyMetricsService.enabled }}
    - --envoyMetricsService
    - '{{ protoToJSON .ProxyConfig.EnvoyMetricsService }}'
  {{- end }}
  {{- if .Values.global.proxy.envoyAccessLogService.enabled }}
    - --envoyAccessLogService
    - '{{ protoToJSON .ProxyConfig.EnvoyAccessLogService }}'
  {{- end }}
    - --proxyAdminPort
    - "{{ .ProxyConfig.ProxyAdminPort }}"
    {{ if gt .ProxyConfig.Concurrency 0 -}}
    - --concurrency
    - "{{ .ProxyConfig.Concurrency }}"
    {{ end -}}
    {{- if .Values.global.istiod.enabled }}
    - --controlPlaneAuthPolicy
    - NONE
    {{- else if .Values.global.controlPlaneSecurityEnabled }}
    - --controlPlaneAuthPolicy
    - MUTUAL_TLS
    {{- else }}
    - --controlPlaneAuthPolicy
    - NONE
    {{- end }}
    - --dnsRefreshRate
    - {{ valueOrDefault .Values.global.proxy.dnsRefreshRate "300s" }}
  {{- if (ne (annotation .ObjectMeta "status.sidecar.istio.io/port" .Values.global.proxy.statusPort) "0") }}
    - --statusPort
    - "{{ annotation .ObjectMeta `status.sidecar.istio.io/port` .Values.global.proxy.statusPort }}"
  {{- end }}
  {{- if .Values.global.sts.servicePort }}
    - --stsPort={{ .Values.global.sts.servicePort }}
  {{- end }}
  {{- if .Values.global.trustDomain }}
    - --trust-domain={{ .Values.global.trustDomain }}
  {{- end }}
  {{- if .Values.global.logAsJson }}
    - --log_as_json
  {{- end }}
    - --controlPlaneBootstrap=false
  {{- if .Values.global.proxy.lifecycle }}
    lifecycle:
      {{ toYaml .Values.global.proxy.lifecycle | indent 4 }}
    {{- end }}
    env:
    - name: JWT_POLICY
      value: {{ .Values.global.jwtPolicy }}
    - name: PILOT_CERT_PROVIDER
      value: {{ .Values.global.pilotCertProvider }}
    # Temp, pending PR to make it default or based on the istiodAddr env
    - name: CA_ADDR
    {{- if .Values.global.configNamespace }}
      value: istio-pilot.{{ .Values.global.configNamespace }}.svc:15012
    {{- else }}
      value: istio-pilot.istio-system.svc:15012
    {{- end }}
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    - name: POD_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    - name: INSTANCE_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    - name: SERVICE_ACCOUNT
      valueFrom:
        fieldRef:
          fieldPath: spec.serviceAccountName
    - name: HOST_IP
      valueFrom:
        fieldRef:
          fieldPath: status.hostIP
  {{- if eq .Values.global.proxy.tracer "datadog" }}
  {{- if isset .ObjectMeta.Annotations `apm.datadoghq.com/env` }}
  {{- range $key, $value := fromJSON (index .ObjectMeta.Annotations `apm.datadoghq.com/env`) }}
    - name: {{ $key }}
      value: "{{ $value }}"
  {{- end }}
  {{- end }}
  {{- end }}
    - name: ISTIO_META_POD_PORTS
      value: |-
        [
        {{- $first := true }}
        {{- range $index1, $c := .Spec.Containers }}
          {{- range $index2, $p := $c.Ports }}
            {{- if (structToJSON $p) }}
            {{if not $first}},{{end}}{{ structToJSON $p }}
            {{- $first = false }}
            {{- end }}
          {{- end}}
        {{- end}}
        ]
    - name: ISTIO_META_CLUSTER_ID
      value: "{{ valueOrDefault .Values.global.multiCluster.clusterName `Kubernetes` }}"
    - name: ISTIO_META_POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    - name: ISTIO_META_CONFIG_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    - name: ISTIO_META_INTERCEPTION_MODE
      value: "{{ or (index .ObjectMeta.Annotations `sidecar.istio.io/interceptionMode`) .ProxyConfig.InterceptionMode.String }}"
    {{- if .Values.global.network }}
    - name: ISTIO_META_NETWORK
      value: "{{ .Values.global.network }}"
    {{- end }}
    {{ if .ObjectMeta.Annotations }}
    - name: ISTIO_METAJSON_ANNOTATIONS
      value: |
             {{ toJSON .ObjectMeta.Annotations }}
    {{ end }}
    {{- if .DeploymentMeta.Name }}
    - name: ISTIO_META_WORKLOAD_NAME
      value: {{ .DeploymentMeta.Name }}
    {{ end }}
    {{- if and .TypeMeta.APIVersion .DeploymentMeta.Name }}
    - name: ISTIO_META_OWNER
      value: kubernetes://apis/{{ .TypeMeta.APIVersion }}/namespaces/{{ valueOrDefault .DeploymentMeta.Namespace `default` }}/{{ toLower .TypeMeta.Kind}}s/{{ .DeploymentMeta.Name }}
    {{- end}}
    {{- if (isset .ObjectMeta.Annotations `sidecar.istio.io/bootstrapOverride`) }}
    - name: ISTIO_BOOTSTRAP_OVERRIDE
      value: "/etc/istio/custom-bootstrap/custom_bootstrap.json"
    {{- end }}
    {{- if .Values.global.meshID }}
    - name: ISTIO_META_MESH_ID
      value: "{{ .Values.global.meshID }}"
    {{- else if .Values.global.trustDomain }}
    - name: ISTIO_META_MESH_ID
      value: "{{ .Values.global.trustDomain }}"
    {{- end }}
    {{- if eq .Values.global.proxy.tracer "stackdriver" }}
    - name: STACKDRIVER_TRACING_ENABLED
      value: "true"
    - name: STACKDRIVER_TRACING_DEBUG
      value: "{{ .ProxyConfig.GetTracing.GetStackdriver.GetDebug }}"
    - name: STACKDRIVER_TRACING_MAX_NUMBER_OF_ANNOTATIONS
      value: "{{ .ProxyConfig.GetTracing.GetStackdriver.GetMaxNumberOfAnnotations.Value }}"
    - name: STACKDRIVER_TRACING_MAX_NUMBER_OF_ATTRIBUTES
      value: "{{ .ProxyConfig.GetTracing.GetStackdriver.GetMaxNumberOfAttributes.Value }}"
    - name: STACKDRIVER_TRACING_MAX_NUMBER_OF_MESSAGE_EVENTS
      value: "{{ .ProxyConfig.GetTracing.GetStackdriver.GetMaxNumberOfMessageEvents.Value }}"
    {{- end }}
    {{- if and (eq .Values.global.proxy.tracer "datadog") (isset .ObjectMeta.Annotations `apm.datadoghq.com/env`) }}
    {{- range $key, $value := fromJSON (index .ObjectMeta.Annotations `apm.datadoghq.com/env`) }}
      - name: {{ $key }}
        value: "{{ $value }}"
    {{- end }}
    {{- end }}
    {{- range $key, $value := .ProxyConfig.ProxyMetadata }}
    - name: {{ $key }}
      value: "{{ $value }}"
    {{- end }}
    imagePullPolicy: "{{ valueOrDefault .Values.global.imagePullPolicy `Always` }}"
    {{ if ne (annotation .ObjectMeta `status.sidecar.istio.io/port` .Values.global.proxy.statusPort) `0` }}
    readinessProbe:
      httpGet:
        path: /healthz/ready
        port: {{ annotation .ObjectMeta `status.sidecar.istio.io/port` .Values.global.proxy.statusPort }}
      initialDelaySeconds: {{ annotation .ObjectMeta `readiness.status.sidecar.istio.io/initialDelaySeconds` .Values.global.proxy.readinessInitialDelaySeconds }}
      periodSeconds: {{ annotation .ObjectMeta `readiness.status.sidecar.istio.io/periodSeconds` .Values.global.proxy.readinessPeriodSeconds }}
      failureThreshold: {{ annotation .ObjectMeta `readiness.status.sidecar.istio.io/failureThreshold` .Values.global.proxy.readinessFailureThreshold }}
    {{ end -}}
    securityContext:
      allowPrivilegeEscalation: {{ .Values.global.proxy.privileged }}
      capabilities:
        {{ if or (eq (annotation .ObjectMeta `sidecar.istio.io/interceptionMode` .ProxyConfig.InterceptionMode) `TPROXY`) (eq (annotation .ObjectMeta `sidecar.istio.io/capNetBindService` .Values.global.proxy.capNetBindService) `true`) -}}
        add:
        {{ if eq (annotation .ObjectMeta `sidecar.istio.io/interceptionMode` .ProxyConfig.InterceptionMode) `TPROXY` -}}
        - NET_ADMIN
        {{- end }}
        {{ if eq (annotation .ObjectMeta `sidecar.istio.io/capNetBindService` .Values.global.proxy.capNetBindService) `true` -}}
        - NET_BIND_SERVICE
        {{- end }}
        {{- end }}
        drop:
        - ALL
      privileged: {{ .Values.global.proxy.privileged }}
      readOnlyRootFilesystem: {{ not .Values.global.proxy.enableCoreDump }}
      runAsGroup: 1337
      fsGroup: 1337
      {{ if or (eq (annotation .ObjectMeta `sidecar.istio.io/interceptionMode` .ProxyConfig.InterceptionMode) `TPROXY`) (eq (annotation .ObjectMeta `sidecar.istio.io/capNetBindService` .Values.global.proxy.capNetBindService) `true`) -}}
      runAsNonRoot: false
      runAsUser: 0
      {{- else -}}
      runAsNonRoot: true
      runAsUser: 1337
      {{- end }}
    resources:
      {{ if or (isset .ObjectMeta.Annotations `sidecar.istio.io/proxyCPU`) (isset .ObjectMeta.Annotations `sidecar.istio.io/proxyMemory`) -}}
      requests:
        {{ if (isset .ObjectMeta.Annotations `sidecar.istio.io/proxyCPU`) -}}
        cpu: "{{ index .ObjectMeta.Annotations `sidecar.istio.io/proxyCPU` }}"
        {{ end}}
        {{ if (isset .ObjectMeta.Annotations `sidecar.istio.io/proxyMemory`) -}}
        memory: "{{ index .ObjectMeta.Annotations `sidecar.istio.io/proxyMemory` }}"
        {{ end }}
    {{ else -}}
  {{- if .Values.global.proxy.resources }}
      {{ toYaml .Values.global.proxy.resources | indent 4 }}
  {{- end }}
    {{  end -}}
    volumeMounts:
    {{- if eq .Values.global.pilotCertProvider "istiod" }}
    - mountPath: /var/run/secrets/istio
      name: istiod-ca-cert
    {{- end }}
    {{ if (isset .ObjectMeta.Annotations `sidecar.istio.io/bootstrapOverride`) }}
    - mountPath: /etc/istio/custom-bootstrap
      name: custom-bootstrap-volume
    {{- end }}
    # SDS channel between istioagent and Envoy
    - mountPath: /etc/istio/proxy
      name: istio-envoy
    {{- if eq .Values.global.jwtPolicy "third-party-jwt" }}
    - mountPath: /var/run/secrets/tokens
      name: istio-token
    {{- end }}
    {{- if .Values.global.mountMtlsCerts }}
    # Use the key and cert mounted to /etc/certs/ for the in-cluster mTLS communications.
    - mountPath: /etc/certs/
      name: istio-certs
      readOnly: true
    {{- end }}
    - name: podinfo
      mountPath: /etc/istio/pod
    {{- if and (eq .Values.global.proxy.tracer "lightstep") .Values.global.tracer.lightstep.cacertPath }}
    - mountPath: {{ directory .ProxyConfig.GetTracing.GetLightstep.GetCacertPath }}
      name: lightstep-certs
      readOnly: true
    {{- end }}
      {{- if isset .ObjectMeta.Annotations `sidecar.istio.io/userVolumeMount` }}
      {{ range $index, $value := fromJSON (index .ObjectMeta.Annotations `sidecar.istio.io/userVolumeMount`) }}
    - name: "{{  $index }}"
      {{ toYaml $value | indent 4 }}
      {{ end }}
      {{- end }}
  volumes:
  {{- if (isset .ObjectMeta.Annotations `sidecar.istio.io/bootstrapOverride`) }}
  - name: custom-bootstrap-volume
    configMap:
      name: {{ annotation .ObjectMeta `sidecar.istio.io/bootstrapOverride` "" }}
  {{- end }}
  # SDS channel between istioagent and Envoy
  - emptyDir:
      medium: Memory
    name: istio-envoy
  - name: podinfo
    downwardAPI:
      items:
        - path: "labels"
          fieldRef:
            fieldPath: metadata.labels
        - path: "annotations"
          fieldRef:
            fieldPath: metadata.annotations
  {{- if eq .Values.global.jwtPolicy "third-party-jwt" }}
  - name: istio-token
    projected:
      sources:
      - serviceAccountToken:
          path: istio-token
          expirationSeconds: 43200
          audience: {{ .Values.global.sds.token.aud }}
  {{- end }}
  {{- if eq .Values.global.pilotCertProvider "istiod" }}
  - name: istiod-ca-cert
    configMap:
      name: istio-ca-root-cert
  {{- end }}
  {{- if .Values.global.mountMtlsCerts }}
  # Use the key and cert mounted to /etc/certs/ for the in-cluster mTLS communications.
  - name: istio-certs
    secret:
      optional: true
      {{ if eq .Spec.ServiceAccountName "" }}
      secretName: istio.default
      {{ else -}}
      secretName: {{  printf "istio.%s" .Spec.ServiceAccountName }}
      {{  end -}}
  {{- end }}
    {{- if isset .ObjectMeta.Annotations `sidecar.istio.io/userVolume` }}
    {{range $index, $value := fromJSON (index .ObjectMeta.Annotations `sidecar.istio.io/userVolume`) }}
  - name: "{{ $index }}"
    {{ toYaml $value | indent 2 }}
    {{ end }}
    {{ end }}
  {{- if and (eq .Values.global.proxy.tracer "lightstep") .Values.global.tracer.lightstep.cacertPath }}
  - name: lightstep-certs
    secret:
      optional: true
      secretName: lightstep.cacert
  {{- end }}
  {{- if .Values.global.podDNSSearchNamespaces }}
  dnsConfig:
    searches:
      {{- range .Values.global.podDNSSearchNamespaces }}
      - {{ render . }}
      {{- end }}
  {{- end }}
  podRedirectAnnot:
    sidecar.istio.io/interceptionMode: "{{ annotation .ObjectMeta `sidecar.istio.io/interceptionMode` .ProxyConfig.InterceptionMode }}"
    traffic.sidecar.istio.io/includeOutboundIPRanges: "{{ annotation .ObjectMeta `traffic.sidecar.istio.io/includeOutboundIPRanges` .Values.global.proxy.includeIPRanges }}"
    traffic.sidecar.istio.io/excludeOutboundIPRanges: "{{ annotation .ObjectMeta `traffic.sidecar.istio.io/excludeOutboundIPRanges` .Values.global.proxy.excludeIPRanges }}"
    traffic.sidecar.istio.io/includeInboundPorts: "{{ annotation .ObjectMeta `traffic.sidecar.istio.io/includeInboundPorts` (includeInboundPorts .Spec.Containers) }}"
    traffic.sidecar.istio.io/excludeInboundPorts: "{{ excludeInboundPort (annotation .ObjectMeta `status.sidecar.istio.io/port` .Values.global.proxy.statusPort) (annotation .ObjectMeta `traffic.sidecar.istio.io/excludeInboundPorts` .Values.global.proxy.excludeInboundPorts) }}"
  {{ if or (isset .ObjectMeta.Annotations `traffic.sidecar.istio.io/excludeOutboundPorts`) (ne .Values.global.proxy.excludeOutboundPorts "") }}
    traffic.sidecar.istio.io/excludeOutboundPorts: "{{ annotation .ObjectMeta `traffic.sidecar.istio.io/excludeOutboundPorts` .Values.global.proxy.excludeOutboundPorts }}"
  {{- end }}
    traffic.sidecar.istio.io/kubevirtInterfaces: "{{ index .ObjectMeta.Annotations `traffic.sidecar.istio.io/kubevirtInterfaces` }}"
```

### istio-sidecar-injector ConfigMap の values

```
$ kubectl get configmap -n istio-system istio-sidecar-injector -o jsonpath='{.data.values}'
```

```json
{
  "global": {
    "arch": {
      "amd64": 2,
      "ppc64le": 2,
      "s390x": 2
    },
    "certificates": [],
    "configNamespace": "istio-system",
    "configValidation": true,
    "controlPlaneSecurityEnabled": true,
    "defaultNodeSelector": {},
    "defaultPodDisruptionBudget": {
      "enabled": true
    },
    "defaultResources": {
      "requests": {
        "cpu": "10m"
      }
    },
    "disablePolicyChecks": true,
    "enableHelmTest": false,
    "enableTracing": true,
    "enabled": true,
    "hub": "docker.io/istio",
    "imagePullPolicy": "IfNotPresent",
    "imagePullSecrets": [],
    "istioNamespace": "istio-system",
    "istiod": {
      "enabled": true
    },
    "jwtPolicy": "first-party-jwt",
    "k8sIngress": {
      "enableHttps": false,
      "enabled": false,
      "gatewayName": "ingressgateway"
    },
    "localityLbSetting": {
      "enabled": true
    },
    "logAsJson": false,
    "logging": {
      "level": "default:info"
    },
    "meshExpansion": {
      "enabled": false,
      "useILB": false
    },
    "meshNetworks": {},
    "mountMtlsCerts": false,
    "mtls": {
      "auto": true,
      "enabled": false
    },
    "multiCluster": {
      "clusterName": "",
      "enabled": false
    },
    "namespace": "istio-system",
    "network": "",
    "omitSidecarInjectorConfigMap": false,
    "oneNamespace": false,
    "operatorManageWebhooks": false,
    "outboundTrafficPolicy": {
      "mode": "ALLOW_ANY"
    },
    "pilotCertProvider": "istiod",
    "policyCheckFailOpen": false,
    "policyNamespace": "istio-system",
    "priorityClassName": "",
    "prometheusNamespace": "istio-system",
    "proxy": {
      "accessLogEncoding": "JSON",
      "accessLogFile": "/dev/stdout",
      "accessLogFormat": "",
      "autoInject": "enabled",
      "clusterDomain": "cluster.local",
      "componentLogLevel": "misc:error",
      "concurrency": 2,
      "dnsRefreshRate": "300s",
      "enableCoreDump": false,
      "envoyAccessLogService": {
        "enabled": false
      },
      "envoyMetricsService": {
        "enabled": false,
        "tcpKeepalive": {
          "interval": "10s",
          "probes": 3,
          "time": "10s"
        },
        "tlsSettings": {
          "mode": "DISABLE",
          "subjectAltNames": []
        }
      },
      "envoyStatsd": {
        "enabled": false
      },
      "excludeIPRanges": "",
      "excludeInboundPorts": "",
      "excludeOutboundPorts": "",
      "image": "proxyv2",
      "includeIPRanges": "*",
      "includeInboundPorts": "*",
      "kubevirtInterfaces": "",
      "logLevel": "warning",
      "privileged": false,
      "protocolDetectionTimeout": "100ms",
      "readinessFailureThreshold": 30,
      "readinessInitialDelaySeconds": 1,
      "readinessPeriodSeconds": 2,
      "resources": {
        "limits": {
          "cpu": "2000m",
          "memory": "1024Mi"
        },
        "requests": {
          "cpu": "100m",
          "memory": "128Mi"
        }
      },
      "statusPort": 15020,
      "tracer": "zipkin"
    },
    "proxy_init": {
      "image": "proxyv2",
      "resources": {
        "limits": {
          "cpu": "100m",
          "memory": "50Mi"
        },
        "requests": {
          "cpu": "10m",
          "memory": "10Mi"
        }
      }
    },
    "sds": {
      "enabled": false,
      "token": {
        "aud": "istio-ca"
      },
      "udsPath": ""
    },
    "securityNamespace": "istio-system",
    "sts": {
      "servicePort": 0
    },
    "tag": "1.5.0",
    "telemetryNamespace": "istio-system",
    "tracer": {
      "datadog": {
        "address": "$(HOST_IP):8126"
      },
      "lightstep": {
        "accessToken": "",
        "address": "",
        "cacertPath": "",
        "secure": true
      },
      "stackdriver": {
        "debug": false,
        "maxNumberOfAnnotations": 200,
        "maxNumberOfAttributes": 200,
        "maxNumberOfMessageEvents": 200
      },
      "zipkin": {
        "address": ""
      }
    },
    "trustDomain": "cluster.local",
    "useMCP": false
  },
  "istio_cni": {
    "enabled": false
  },
  "sidecarInjectorWebhook": {
    "alwaysInjectSelector": [],
    "enableNamespacesByDefault": false,
    "enabled": false,
    "image": "sidecar_injector",
    "injectLabel": "istio-injection",
    "injectedAnnotations": {},
    "namespace": "istio-system",
    "neverInjectSelector": [],
    "objectSelector": {
      "autoInject": true,
      "enabled": false
    },
    "rewriteAppHTTPProbe": false,
    "selfSigned": false
  }
}
```

### preStop hook のカスタマイズ

**template** の中に次のような箇所があります。よって、**values** でこの `global.proxy.lifecycle` を定義してやれば preStop hook を入れることが可能になります。

```
  {{- if .Values.global.proxy.lifecycle }}
    lifecycle:
      {{ toYaml .Values.global.proxy.lifecycle | indent 4 }}
    {{- end }}
```

preStop hook にどんなコマンドを入れるかですが「[本番環境のマルチテナント Kubernetes クラスタへの Istio 導入](https://medium.com/google-cloud-jp/adopting-istio-for-a-multi-tenant-kubernetes-cluster-in-production-jp-f37865f5009a)」で Istio の [issue #7136](https://github.com/istio/istio/issues/7136) に投稿されているものが紹介されています。

```yaml
lifecycle:
  preStop:
    exec:
      command:
        - "/bin/sh"
        - "-c"
        - "while [ $(netstat -plunt | grep tcp | grep -v envoy | wc -l | xargs) -ne 0 ]; do sleep 1; done"
```

netstat で envoy 以外に port を listen しているプロセスが存在するかどうかを確認して、存在しなくなるまで sleep 1 して再チェックを繰り返し、存在しなくなったら終了します。その後コンテナのプロセスに対して SIGTERM が送られます。

試しに Istio 1.5 環境で netstat -plunt を実行してみると次のようになりました。pilot-agent も istio-proxy コンテナ内で実行されているため、このコマンドのままでは terminationGracePeriodSeconds （デフォルト30秒） を待っても終了せず、その2秒後に SIGTERM が送られることになります。

```
$ netstat -plunt
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      -                   
tcp        0      0 0.0.0.0:15090           0.0.0.0:*               LISTEN      18/envoy            
tcp        0      0 127.0.0.1:15000         0.0.0.0:*               LISTEN      18/envoy            
tcp        0      0 0.0.0.0:15001           0.0.0.0:*               LISTEN      18/envoy            
tcp        0      0 0.0.0.0:15006           0.0.0.0:*               LISTEN      18/envoy            
tcp6       0      0 :::15020                :::*                    LISTEN      1/pilot-agent
```

ところで、netstat に `-u` がついてるけど `grep tcp` してるから意味ないな。あと、`xargs` って何の意味があるんだろうか？？

ということで `global.proxy.lifecycle` に設定するのは次のようになる。`kubectl edit cm istio-sidecar-injector -n istio-system` で編集します。

```
$ kubectl -n istio-system get configmap istio-sidecar-injector -o=jsonpath='{.data.values}' | jq .global.proxy.lifecycle 
{
  "preStop": {
    "exec": {
      "command": [
        "/bin/sh",
        "-c",
        "while [ $(netstat -plnt | grep tcp | egrep -v 'envoy|pilot-agent' | wc -l) -ne 0 ]; do sleep 1; done"
      ]
    }
  }
}
```

Deployment の Pod を削除すれば新しい Pod が作成される時に新しい設定で istio-proxy が Inject されるため、`kubectl get pod` で確認できる。

```
$ kubectl get pod httpbin-deployment-v2-ccd49cc9c-5z9mt -o jsonpath='{.spec.containers[*].lifecycle.preStop}'
map[exec:map[command:[/bin/sh -c while [ $(netstat -plnt | grep tcp | egrep -v 'envoy|pilot-agent' | wc -l) -ne 0 ]; do sleep 1; done]]]
```

* * *

Istio 導入への道シリーズ

* [Istio 導入への道 (1) – インストール編](/2020/03/istio-part1/)
* [Istio 導入への道 (2) – サービス間通信編](/2020/03/istio-part2/)
* [Istio 導入への道 (3) – VirtualService 編](/2020/03/istio-part3/)
* [Istio 導入への道 (4) – Fault Injection 編](/2020/03/istio-part4/)
* [Istio 導入への道 (5) – OutlierDetection と Retry 編](/2020/03/istio-part5/)
* [Istio 導入への道 (6) – Ingress Gatway 編](/2020/03/istio-part6/)
* [Istio 導入への道 (7) – 外部へのアクセス / ServiceEntry 編](/2020/03/istio-part7/)
* [Istio 導入への道 (8) – 外部へのアクセスでも Fault Injection 編](/2020/03/istio-part8/)
* [Istio 導入への道 (9) – gRPC でも Fault Injection 編](/2020/03/istio-part9/)
* [Istio 導入への道 (10) – 図解](/2020/03/istio-part10/)
* [Istio 導入への道 (11) – Ingress Gateway で TLS Termination 編](/2020/03/istio-part11/)
* Istio 導入への道 (12) – sidecar の調整編
