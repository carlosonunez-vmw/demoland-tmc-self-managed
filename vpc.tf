data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "4.0.1"

  name = "tkg-land"
  cidr = "172.16.0.0/16"

  private_subnets = ["172.16.0.0/24",
    "172.16.1.0/24",
  "172.16.2.0/24"]
  public_subnets = ["172.16.3.0/24",
    "172.16.4.0/24",
  "172.16.5.0/24"]
  enable_nat_gateway = true
  azs                = slice(sort(data.aws_availability_zones.available.names), 0, 3)
  tags = {
    "kubernetes.io/cluster/tmc-test"          = "shared"
    "kubernetes.io/cluster/tmc-test-worker-1" = "shared"
    "kubernetes.io/cluster/tmc-test-worker-2" = "shared"
    "kubernetes.io/cluster/tmc-test-worker-3" = "shared"
    "kubernetes.io/role/elb"                  = "1"
  }
}

module "eks_vpc" {
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
