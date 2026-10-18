locals {
  kubeconfig = pathexpand("~/.kube/banca-kind.yaml")

  # Zonas de red = namespaces. PSA: nivel de Pod Security por zona.
  namespaces = {
    "banca-prod"     = "restricted" # zona de aplicación: el nivel más estricto
    "ingress"        = "privileged"
    "seguridad"      = "baseline"
    "gitops"         = "baseline"
    "observabilidad" = "privileged" # node-exporter requiere hostPID/hostNetwork
  }
}

resource "kind_cluster" "banca" {
  name            = var.cluster_name
  node_image      = var.node_image
  kubeconfig_path = local.kubeconfig
  wait_for_ready  = false # sin CNI el nodo no está Ready hasta instalar Calico

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    networking {
      disable_default_cni = true # kindnet no aplica NetworkPolicy; usamos Calico
      pod_subnet          = "10.244.0.0/16"
    }

    node {
      role = "control-plane"

      kubeadm_config_patches = [<<-EOT
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
      EOT
      ]

      extra_port_mappings {
        container_port = 80
        host_port      = 80
        listen_address = "127.0.0.1"
      }
      extra_port_mappings {
        container_port = 443
        host_port      = 443
        listen_address = "127.0.0.1"
      }
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = local.kubeconfig
  }
}

provider "kubernetes" {
  config_path = local.kubeconfig
}

resource "helm_release" "calico" {
  name             = "calico"
  repository       = "https://docs.tigera.io/calico/charts"
  chart            = "tigera-operator"
  version          = var.calico_version
  namespace        = "tigera-operator"
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [yamlencode({
    installation = {
      calicoNetwork = {
        ipPools = [{ cidr = "10.244.0.0/16", encapsulation = "VXLAN" }]
      }
    }
  })]

  depends_on = [kind_cluster.banca]
}

resource "kubernetes_namespace" "zona" {
  for_each = local.namespaces

  metadata {
    name = each.key
    labels = {
      "pod-security.kubernetes.io/enforce" = each.value
      "pod-security.kubernetes.io/warn"    = "restricted"
      "zona"                               = each.key
    }
  }

  depends_on = [helm_release.calico]
}
