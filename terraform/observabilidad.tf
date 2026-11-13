# Fase 5: Prometheus mínimo para que Argo Rollouts decida con métricas reales.
# Sin Grafana, Alertmanager ni exporters extra (la Fase 6 los amplía).
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.prometheus_stack_version
  namespace  = "observabilidad"
  wait       = true
  timeout    = 600

  values = [yamlencode({
    grafana               = { enabled = false }
    alertmanager          = { enabled = false }
    nodeExporter          = { enabled = false }
    kubeStateMetrics      = { enabled = false }
    kubeApiServer         = { enabled = false }
    kubelet               = { enabled = false }
    kubeControllerManager = { enabled = false }
    kubeEtcd              = { enabled = false }
    kubeScheduler         = { enabled = false }
    kubeProxy             = { enabled = false }
    coreDns               = { enabled = false }
    defaultRules          = { create = false }

    prometheusOperator = {
      admissionWebhooks = { enabled = false }
      tls               = { enabled = false }
      resources = {
        requests = { cpu = "50m", memory = "64Mi" }
        limits   = { memory = "192Mi" }
      }
    }

    prometheus = {
      prometheusSpec = {
        retention                               = "6h"
        scrapeInterval                          = "15s"
        serviceMonitorSelectorNilUsesHelmValues = false
        podMonitorSelectorNilUsesHelmValues     = false
        ruleSelectorNilUsesHelmValues           = false
        resources = {
          requests = { cpu = "100m", memory = "256Mi" }
          limits   = { memory = "768Mi" }
        }
      }
    }
  })]

  depends_on = [kubernetes_namespace.zona]
}
