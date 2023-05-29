variable "create_eks_cluster" {
  description = "Create a test EKS cluster to join to TMC Local. Disabled by default"
  default     = 0
}

module "eks_vpc" {
  count   = var.create_eks_cluster == 0 ? 0 : 1
  source  = "terraform-aws-modules/vpc/aws"
  version = "4.0.1"

  name = "eks-land"
  cidr = "172.16.0.0/16"

  private_subnets = ["172.16.0.0/24",
    "172.16.1.0/24",
  "172.16.2.0/24"]
  public_subnets = ["172.16.3.0/24",
    "172.16.4.0/24",
  "172.16.5.0/24"]
  enable_nat_gateway = true
  azs                = slice(sort(data.aws_availability_zones.available.names), 0, 3)
}
module "eks" {
  count   = var.create_eks_cluster == 0 ? 0 : 1
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

  vpc_id                   = module.eks_vpc[0].vpc_id
  subnet_ids               = module.eks_vpc[0].private_subnets
  control_plane_subnet_ids = module.eks_vpc[0].private_subnets

  eks_managed_node_group_defaults = {
    instance_types = ["t2.2xlarge", "t2.4xlarge"]
  }
}
