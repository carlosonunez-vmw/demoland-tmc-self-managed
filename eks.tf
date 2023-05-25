module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.13.1"

  cluster_name    = "tmc-eks-test"
  cluster_version = "1.24"

  cluster_endpoint_public_access = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  vpc_id                   = module.eks_vpc.vpc_id
  subnet_ids               = module.eks_vpc.private_subnets
  control_plane_subnet_ids = module.eks_vpc.private_subnets

  eks_managed_node_group_defaults = {
    instance_types = ["t2.2xlarge", "t2.4xlarge"]
  }
}
