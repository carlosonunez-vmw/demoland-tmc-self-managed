resource "tanzu-mission-control_cluster_group" "public_cloud" {
  name = "cloud-clusters"
  meta {
    description = "Clusters managed by a cloud provider"
  }
}

resource "tanzu-mission-control_cluster_group" "private_cloud" {
  name = "private-clusters"
  meta {
    description = "Clusters managed by a cloud provider"
  }
}

# Trying to attach clusters yields a HTTP 500 with no additional info provided...
resource "tanzu-mission-control_cluster" "eks" {
  management_cluster_name = "attached"
  provisioner_name        = "attached"
  name                    = "test-eks-cluster"
  attach_k8s_cluster {
    kubeconfig_raw = module.eks-kubeconfig.kubeconfig
    description    = "EKS cluster"
  }
  meta {
    description = "Test EKS cluster"
    labels = {
      "cloud" : "aws"
    }
  }
  spec {
    cluster_group = tanzu-mission-control_cluster_group.public_cloud.name
  }
}

resource "tanzu-mission-control_cluster" "aks" {
  management_cluster_name = "attached"
  provisioner_name        = "attached"
  name                    = "test-aks-cluster"
  attach_k8s_cluster {
    kubeconfig_raw = azurerm_kubernetes_cluster.tmc-example.kube_config_raw
    description    = "AKS cluster"
  }
  meta {
    description = "Test AKS cluster"
    labels = {
      "cloud" : "azure"
    }
  }
  spec {
    cluster_group = tanzu-mission-control_cluster_group.public_cloud.name
  }
}
