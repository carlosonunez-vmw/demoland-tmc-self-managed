module "eks_unmanaged" {
  source                         = "terraform-aws-modules/eks/aws"
  version                        = "19.15.3"
  cluster_name                   = "tmc-example-cluster-to-add"
  cluster_version                = "1.27"
  cluster_endpoint_public_access = true
  cluster_addons = {
    coredns = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }
    vpc-cni = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.public_subnets
  eks_managed_node_group_defaults = {
    instance_types = ["t3a.2xlarge"]
    capacity_type  = "SPOT"
    desired_size   = 1
    min_size       = 1
  }
  eks_managed_node_groups = {
    default = {
      max_size = 8
    }
  }
  aws_auth_users = [
    {
      userarn  = data.aws_caller_identity.self.arn
      username = "self"
      groups   = ["system:masters"]
    }
  ]
}

module "ebs_irsa_role_unmanaged_cluster" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name             = "ebs-csi-tmc-cluster-unmanaged-cluster"
  attach_ebs_csi_policy = true

  oidc_providers = {
    p = {
      provider_arn               = module.eks_unmanaged.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

module "eks_unmanaged-kubeconfig" {
  depends_on = [
    module.eks_unmanaged
  ]
  source       = "hyperbadger/eks-kubeconfig/aws"
  version      = "2.0.0"
  cluster_name = module.eks_unmanaged.cluster_name
}
