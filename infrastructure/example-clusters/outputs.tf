output "azure_kubeconfig" {
  value     = azurerm_kubernetes_cluster.tmc-example.kube_config_raw
  sensitive = true
}

output "eks_kubeconfig" {
  value     = module.eks-kubeconfig.kubeconfig
  sensitive = true
}

output "eks_kubeconfig_to_add" {
  value     = module.eks-kubeconfig-to-add.kubeconfig
  sensitive = true
}
