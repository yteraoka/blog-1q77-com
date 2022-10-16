---
title: 'GKE Service の NEG を Terraform で作成する'
date: Tue, 09 Aug 2022 20:13:48 +0900
draft: false
tags: ['GKE', 'Terraform']
---

GKE の Ingress で Load Balancer を作成すると、同一 namespace 内の Service にしか振り分けられないとか、単一の Cluster でしか使えないとか不都合な場合があります。その場合 Load Balancer 関連のリソースは Terraform で作成したくなりますが、NEG まで作らなければ BackendService を作成できません。 しかし、NEG は GKE のコントローラが作成するため、鶏卵問題で悲しい思いをしたことはないでしょうか。 この NEG は GKE が作るのを待たずに Terraform で作成することも可能だったのでそのメモです。

答えを先に書いておくと、次のようになります。

```tf
data "google_compute_zones" "available" {}

resource "google_compute_network_endpoint_group" "igw" {
  for_each = toset([for zone in data.google_compute_zones.available.names : zone if substr(zone, 0, length(var.region)) == var.region])

  name        = "${var.env}-igw"
  description = "{\"cluster-uid\":\"${data.kubernetes_namespace_v1.kube_system.metadata[0].uid}\",\"namespace\":\"istio-ingress\",\"service-name\":\"istio-ingressgateway\",\"port\":\"80\"}"
  network     = google_compute_network.vpc.id
  subnetwork  = google_compute_subnetwork.tokyo.id
  zone        = each.key

  depends_on = [
    google_container_cluster.cluster,
  ]
}
```

ポイントは **description** に謎の JSON をセットしている部分です。 GKE のコントローラが作成する場合にこれがセットされるようになっており、それを真似て作ってやると endpoint として GKE の Pod が登録されるようになります。

```json
{
  "cluster-uid": "5052b0f9-569a-44cc-a407-72554fb21913",
  "namespace": "istio-ingress",
  "service-name": "istio-ingressgateway",
  "port": "80"
}
```

問題はこの **cluster-uid** というものの値はどこから取得できるのかということですが、**kube-system** namespace の **metadata** にある **uid** が使われるようです。（Google に確認しました)

NEG は Zonal リソースなので zone ごとに作成しています。 [google_compute_zones](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_zones) という data source から対象のリージョンのものだけ取り出すようにしました。
