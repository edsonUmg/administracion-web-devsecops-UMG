# Fases 5 y 6: Prometheus para que Argo Rollouts decida con métricas reales (Fase 5)
# y, en la Fase 6, Grafana (paneles) y Alertmanager (alertas por SLO).
# Se mantienen apagados los exporters extra y las reglas por defecto para cuidar la RAM.
# El secreto grafana-admin (usuario y clave de Grafana) se crea a mano en el clúster,
# no está en Git (igual que banca-secretos).
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.prometheus_stack_version
  namespace  = "observabilidad"
  wait       = true
  timeout    = 900

  values = [yamlencode({
    grafana = {
      enabled                  = true
      defaultDashboardsEnabled = false
      testFramework            = { enabled = false }
      admin = {
        existingSecret = "grafana-admin"
        userKey        = "admin-user"
        passwordKey    = "admin-password"
      }
      sidecar = {
        dashboards = {
          enabled         = true
          label           = "grafana_dashboard"
          labelValue      = "1"
          searchNamespace = "ALL"
          resource        = "configmap"
        }
        datasources = {
          resource = "configmap"
        }
        # 96 Mi no alcanzó: los ayudantes terminaron en OOMKilled
        resources = {
          requests = { cpu = "10m", memory = "48Mi" }
          limits   = { memory = "192Mi" }
        }
      }
      # Grafana 12 tarda en arrancar en el laboratorio: más memoria y más paciencia
      resources = {
        requests = { cpu = "100m", memory = "192Mi" }
        limits   = { memory = "512Mi" }
      }
      livenessProbe = {
        httpGet             = { path = "/api/health", port = 3000 }
        initialDelaySeconds = 180
        periodSeconds       = 10
        timeoutSeconds      = 30
        failureThreshold    = 10
      }
    }

    alertmanager = {
      enabled = true
      alertmanagerSpec = {
        retention = "6h"
        resources = {
          requests = { cpu = "10m", memory = "32Mi" }
          limits   = { memory = "96Mi" }
        }
      }
    }

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
