data "aws_caller_identity" "self" {}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "4.0.1"

  name = "tmc-example-clusters"
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
  source                         = "terraform-aws-modules/eks/aws"
  version                        = "19.15.3"
  cluster_name                   = "tmc-example-cluster"
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
    instance_types = ["t3a.xlarge"]
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

module "eks-kubeconfig" {
  depends_on = [
    module.eks
  ]
  source       = "hyperbadger/eks-kubeconfig/aws"
  version      = "2.0.0"
  cluster_name = module.eks.cluster_name
}
