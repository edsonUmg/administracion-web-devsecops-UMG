variable "cluster_name" {
  type    = string
  default = "banca"
}

variable "node_image" {
  description = "Imagen del nodo kind. null = la que trae la versión instalada de kind."
  type        = string
  default     = null
}

variable "calico_version" {
  description = "Versión del chart tigera-operator (verificar con helm search repo)."
  type        = string
  default     = "v3.30.3"
}

variable "prometheus_stack_version" {
  description = "Versión del chart kube-prometheus-stack (fijada, SSDF PS.3)."
  type        = string
  default     = "93.2.2"
}

variable "argocd_version" {
  description = "Versión del chart argo-cd (fijada, SSDF PS.3)."
  type        = string
  default     = "10.18.0"
}

variable "argo_rollouts_version" {
  description = "Versión del chart argo-rollouts (fijada, SSDF PS.3)."
  type        = string
  default     = "2.43.12"
}
