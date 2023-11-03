output "azure_kubeconfig" {
  value     = azurerm_kubernetes_cluster.tmc-example.kube_admin_config
  sensitive = true
}

output "kind_kubeconfig" {
  value     = kind_cluster.local.kubeconfig
  sensitive = true
}

output "eks_kubeconfig" {
  value     = module.eks-kubeconfig.kubeconfig
  sensitive = true
}
