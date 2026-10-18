output "kubeconfig_path" {
  value = local.kubeconfig
}

output "namespaces" {
  value = keys(local.namespaces)
}
