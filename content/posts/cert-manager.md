---
title: 'cert-manager で証明書管理'
date: Sat, 28 Mar 2020 14:02:59 +0000
draft: false
tags: ['Kubernetes', 'Kubernetes', 'cert-manager']
---

前回の「[ArgoCD と Istio Ingress Gateway](/2020/03/argocd-istio-ingress/)」と、前々回の「 [Istio 導入への道 – Ingress Gateway で TLS Termination 編](/2020/03/istio-part11/) 」で TLS の証明書を手動で取得して Secret として登録したが、登録もさることながら更新が大変です。これを [cert-manager](https://cert-manager.io/) にやってもらうことにします。

cert-manager のインストール
--------------------

[ドキュメント](https://cert-manager.io/docs/installation/kubernetes/)にある通りです。

```
$ kubectl apply -f [https://github.com/jetstack/cert-manager/releases/download/v0.14.1/cert-manager.yaml](https://github.com/jetstack/cert-manager/releases/download/v0.14.1/cert-manager.yaml)

```

沢山のリソースが作成されます。

```
customresourcedefinition.apiextensions.k8s.io/certificaterequests.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/certificates.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/challenges.acme.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/clusterissuers.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/issuers.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/orders.acme.cert-manager.io created
namespace/cert-manager created
serviceaccount/cert-manager-cainjector created
serviceaccount/cert-manager created
serviceaccount/cert-manager-webhook created
clusterrole.rbac.authorization.k8s.io/cert-manager-cainjector created
clusterrole.rbac.authorization.k8s.io/cert-manager-controller-certificates created
clusterrole.rbac.authorization.k8s.io/cert-manager-controller-issuers created
clusterrole.rbac.authorization.k8s.io/cert-manager-view created
clusterrole.rbac.authorization.k8s.io/cert-manager-controller-orders created
clusterrole.rbac.authorization.k8s.io/cert-manager-controller-challenges created
clusterrole.rbac.authorization.k8s.io/cert-manager-controller-ingress-shim created
clusterrole.rbac.authorization.k8s.io/cert-manager-controller-clusterissuers created
clusterrole.rbac.authorization.k8s.io/cert-manager-edit created
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-cainjector created
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-controller-challenges created
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-controller-issuers created
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-controller-certificates created
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-controller-orders created
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-controller-clusterissuers created
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-controller-ingress-shim created
role.rbac.authorization.k8s.io/cert-manager-cainjector:leaderelection created
role.rbac.authorization.k8s.io/cert-manager:leaderelection created
rolebinding.rbac.authorization.k8s.io/cert-manager-cainjector:leaderelection created
rolebinding.rbac.authorization.k8s.io/cert-manager:leaderelection created
service/cert-manager created
service/cert-manager-webhook created
deployment.apps/cert-manager-cainjector created
deployment.apps/cert-manager created
deployment.apps/cert-manager-webhook created
mutatingwebhookconfiguration.admissionregistration.k8s.io/cert-manager-webhook created
validatingwebhookconfiguration.admissionregistration.k8s.io/cert-manager-webhook created

```

**cert-manager** ネームスペースに **cert-manager**, **cert-manager-cainjector** (CA Injector), **cert-manager-webhook** Deployment がデプロイされています。

```
$ kubectl get pods --namespace cert-manager
NAME                                       READY   STATUS    RESTARTS   AGE
cert-manager-665f89d4d6-vfpdx              1/1     Running   0          83m
cert-manager-cainjector-78c8947f5c-r8rsd   1/1     Running   0          83m
cert-manager-webhook-84f59fdf49-l59ld      1/1     Running   0          83m

```

リソースの登録
-------

ここでは [Let's Encrypt](https://letsencrypt.org/) の証明書を [dns01](https://cert-manager.io/docs/configuration/acme/dns01/) で取得します。DNS には [Route53](https://cert-manager.io/docs/configuration/acme/dns01/route53/) を使います。Kubernetes クラスタは相変わらず [Minikube](https://kubernetes.io/ja/docs/setup/learning-environment/minikube/) なので IAM Role ではなく IAM User を作成して Access Key ID と Secret Access Key を使います。

### Secret Access Key を K8s Secret に登録

`route53-credentials-secret` という名前の Secret を cert-manager ネームスペースに登録します。キーは `secret-access-key` とします。

```
$ kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: route53-credentials-secret
  namespace: cert-manager
type: Opeque
stringData:
  secret-access-key: ai/Vdmhv2qhekGe1nE1u39HC48LIAwtBap+5TP81
EOF

```

### Issuer の登録

**Issuer** と **ClusterIssuer** があり、Issuer は namespace に閉じたリソースです。ネームスペースを跨いで利用する場合は **ClusterIssuer** を使います。Issuer には Let's Encrypt などを使用するのに必要な情報をセットします。今回は [Let's Encrypt の dns01](https://letsencrypt.org/docs/challenge-types/#dns-01-challenge) と [Route53](https://cert-manager.io/docs/configuration/acme/dns01/route53/) ですから、

Let's Encrypt 用に

*   メールアドレス
*   ACME サーバーの URL
*   Private Key の保存先としての Secret 名

Route53 用に

*   Region 名
*   Access Key ID
*   Secret Access Key を登録した Secret 名

を設定します。

```
$ kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt
  namespace: cert-manager
spec:
  acme:
    # The ACME server URL
    server: https://acme-v02.api.letsencrypt.org/directory
    # Email address used for ACME registration
    email: username@gmail.com
    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: letsencrypt
    solvers:
    - dns01:
        route53:
          region: ap-northeast-1
          accessKeyID: AKIA5Z6TEOZE8VOPCH6K
          secretAccessKeySecretRef:
            name: route53-credentials-secret
            key: secret-access-key
EOF

```

**solvers** はリストで複数のプロバイダを登録できます。ドメインによって DNS プロバイダが違う場合や Route53 用の AWS Account が違う場合、または dns01 ではなく web01 を使う場合などの混在が可能です。

### Certificate の登録

`issuerRef` でどの **Issuer** を使うのかを指定します。ClusterIssuer を使ったため default ネームスペースからでも発行可能です。`secretName` で指定した Secret に秘密鍵と証明書が保存されます。

```
$ kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1alpha2
kind: Certificate
metadata:
  name: wildcard-local-1q77-com
  namespace: default
spec:
  secretName: wildcard-local-1q77-com
  dnsNames:
  - '\*.local.1q77.com'
  - local.1q77.com
  issuerRef:
    name: letsencrypt
    kind: ClusterIssuer
EOF

```

これで次のような CommonName, SANs の証明書を取得することができます。

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            04:94:64:04:e7:54:ba:6a:b5:cf:30:3a:fd:e3:d3:7f:95:af
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: C=US, O=Let's Encrypt, CN=Let's Encrypt Authority X3
        Validity
            Not Before: Mar 28 08:21:40 2020 GMT
            Not After : Jun 26 08:21:40 2020 GMT
        Subject: CN=\*.local.1q77.com
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:c5:5f:18:bd:46:7e:91:6c:d3:0e:04:0e:fc:6c:
                    ef:9d:25:98:10:e9:c1:a1:68:3c:23:5e:13:98:cd:
                    2d:60:4e:5d:06:87:f3:10:c1:86:cb:4e:7d:cf:b4:
                    fe:9f:20:3a:88:5a:4d:0a:ff:01:34:23:74:a4:22:
                    a8:c3:32:74:b1:23:25:f2:f1:11:f1:7c:77:ee:7e:
                    41:d9:7b:4f:ac:ca:ea:c0:6d:f1:46:bf:d1:c3:06:
                    fa:45:66:dc:ee:03:e9:25:23:46:c9:54:57:88:eb:
                    35:53:f5:ea:db:5c:09:d3:fa:a5:98:34:2d:c6:50:
                    aa:80:ef:25:72:48:04:9b:48:4d:bb:dc:f8:9a:56:
                    dc:f5:e4:f6:b4:34:d2:d0:a8:54:ce:77:4a:d5:83:
                    60:e3:16:20:6e:12:6b:d5:0c:86:d2:3c:5a:ba:64:
                    5f:cf:05:cb:db:0a:64:35:3d:e9:8d:18:65:2b:fd:
                    11:fe:32:c5:5e:29:44:f6:85:61:4c:ae:9d:33:f6:
                    e1:d8:9a:4c:2d:9e:fa:58:ff:0b:45:89:61:1c:3d:
                    cf:8c:58:b5:c6:76:ca:95:e3:6d:14:ef:4e:81:8d:
                    dd:a0:85:52:4b:b3:61:e4:c0:f5:be:12:c7:7e:35:
                    ab:36:b7:ea:54:55:2d:8d:a5:3f:cc:3e:84:a5:84:
                    4d:a1
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication, TLS Web Client Authentication
            X509v3 Basic Constraints: critical
                CA:FALSE
            X509v3 Subject Key Identifier: 
                A8:0D:95:E2:F2:CA:5A:11:4A:DD:83:70:A6:07:77:83:12:36:27:7A
            X509v3 Authority Key Identifier: 
                keyid:A8:4A:6A:63:04:7D:DD:BA:E6:D1:39:B7:A6:45:65:EF:F3:A8:EC:A1

            Authority Information Access: 
                OCSP - URI:http://ocsp.int-x3.letsencrypt.org
                CA Issuers - URI:http://cert.int-x3.letsencrypt.org/

            X509v3 Subject Alternative Name: 
                DNS:\*.local.1q77.com, DNS:local.1q77.com
            X509v3 Certificate Policies: 
                Policy: 2.23.140.1.2.1
                Policy: 1.3.6.1.4.1.44947.1.1.1
                  CPS: http://cps.letsencrypt.org

```

**Certificate** リソースは次のような状態。

```
$ kubectl get certificate
NAME                      READY   SECRET                    AGE
wildcard-local-1q77-com   True    wildcard-local-1q77-com   4h36m

``````
$ kubectl describe certificate                
Name:         wildcard-local-1q77-com
Namespace:    default
Labels:       <none>
Annotations:  kubectl.kubernetes.io/last-applied-configuration:
                {"apiVersion":"cert-manager.io/v1alpha2","kind":"Certificate","metadata":{"annotations":{},"name":"wildcard-local-1q77-com","namespace":"d...
API Version:  cert-manager.io/v1alpha3
Kind:         Certificate
Metadata:
  Creation Timestamp:  2020-03-28T08:59:27Z
  Generation:          2
  Resource Version:    1027821
  Self Link:           /apis/cert-manager.io/v1alpha3/namespaces/default/certificates/wildcard-local-1q77-com
  UID:                 f5e5d067-2fac-4fdd-8a4b-59ba26916137
Spec:
  Dns Names:
    \*.local.1q77.com
    local.1q77.com
  Issuer Ref:
    Kind:       ClusterIssuer
    Name:       letsencrypt
  Secret Name:  wildcard-local-1q77-com
Status:
  Conditions:
    Last Transition Time:  2020-03-28T09:21:41Z
    Message:               Certificate is up to date and has not expired
    Reason:                Ready
    Status:                True
    Type:                  Ready
  Not After:               2020-06-26T08:21:40Z
Events:                     
```

Certificate を作成すると CertificateRequest リソースが作成されます。何か問題がある場合はこの中身をみると原因が分かったりします。

```
$ kubectl get certificaterequest
NAME                                 READY   AGE
wildcard-local-1q77-com-4173496889   True    4h17m

``````
$ kubectl describe certificaterequest     
Name:         wildcard-local-1q77-com-4173496889
Namespace:    default
Labels:       <none>
Annotations:  cert-manager.io/certificate-name: wildcard-local-1q77-com
              cert-manager.io/private-key-secret-name: wildcard-local-1q77-com
              kubectl.kubernetes.io/last-applied-configuration:
                {"apiVersion":"cert-manager.io/v1alpha2","kind":"Certificate","metadata":{"annotations":{},"name":"wildcard-local-1q77-com","namespace":"d...
API Version:  cert-manager.io/v1alpha3
Kind:         CertificateRequest
Metadata:
  Creation Timestamp:  2020-03-28T09:17:50Z
  Generation:          1
  Owner References:
    API Version:           cert-manager.io/v1alpha2
    Block Owner Deletion:  true
    Controller:            true
    Kind:                  Certificate
    Name:                  wildcard-local-1q77-com
    UID:                   f5e5d067-2fac-4fdd-8a4b-59ba26916137
  Resource Version:        1027815
  Self Link:               /apis/cert-manager.io/v1alpha3/namespaces/default/certificaterequests/wildcard-local-1q77-com-4173496889
  UID:                     8c73b0a5-172e-4fee-bed1-5208406d3e50
Spec:
  Csr:  LS0tLS1C (中略... PEM がさらに Base64 されて表示されている) U1QtLS0tLQo=
  Issuer Ref:
    Kind:  ClusterIssuer
    Name:  letsencrypt
Status:
  Certificate:  LS0tLS1CRU (中略... PEM がさらに Base64 されて表示されている) LS0tLS0K
  Conditions:
    Last Transition Time:  2020-03-28T09:21:40Z
    Message:               Certificate fetched from issuer successfully
    Reason:                Issued
    Status:                True
    Type:                  Ready
Events:                    <none>

```

**Certificate** リソースで指定した Secret に証明書と秘密鍵が入っています。

```
$ kubectl get secret wildcard-local-1q77-com
NAME                      TYPE                DATA   AGE
wildcard-local-1q77-com   kubernetes.io/tls   3      4h37m

``````
$ kubectl describe secret wildcard-local-1q77-com
Name:         wildcard-local-1q77-com
Namespace:    default
Labels:       <none>
Annotations:  cert-manager.io/alt-names: \*.local.1q77.com,local.1q77.com
              cert-manager.io/certificate-name: wildcard-local-1q77-com
              cert-manager.io/common-name: \*.local.1q77.com
              cert-manager.io/ip-sans: 
              cert-manager.io/issuer-kind: ClusterIssuer
              cert-manager.io/issuer-name: letsencrypt
              cert-manager.io/uri-sans: 

Type:  kubernetes.io/tls

Data
====
ca.crt:   0 bytes
tls.crt:  3582 bytes
tls.key:  1675 bytes

```

**Certificate** 設定をミスってた時に **CertificateRequest** で確認されたメッセージです。

```
status:
  conditions:
  - lastTransitionTime: "2020-03-28T08:59:27Z"
    message: 'The CSR PEM requests a commonName that is not present in the list of
      dnsNames. If a commonName is set, ACME requires that the value is also present
      in the list of dnsNames: "local.1q77.com" does not exist in \[\*.local.1q77.com\]'
    reason: Failed
    status: "False"
    type: Ready
  failureTime: "2020-03-28T08:59:27Z"

```

自動更新
----

自動更新までは動作確認できていませんが、[ドキュメント](https://cert-manager.io/docs/tutorials/acme/dns-validation/)には次のように書いてあります。

> Once our certificate has been obtained, cert-manager will periodically check its validity and attempt to renew it if it gets close to expiry. cert-manager considers certificates to be close to expiry when the ‘Not After’ field on the certificate is less than the current time plus 30 days.

証明書取得後、cert-manager は定期的に有効性を確認し、期限が近づくと更新を試みます。cert-manager は Not After フィールドの日付が現在時刻プラス30日よりも近い場合に期限切れ間近と判断する。