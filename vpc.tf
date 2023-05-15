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
}

module "key_pair" {
  source  = "terraform-aws-modules/key-pair/aws"
  version = "2.0.2"

  key_name           = "tkg-jumpbox"
  create_private_key = true
}

module "jumpbox-sg" {
  source              = "terraform-aws-modules/security-group/aws"
  version             = "4.17.2"
  name                = "jumpbox-sg"
  ingress_rules       = ["ssh-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  vpc_id              = module.vpc.vpc_id
  egress_rules        = ["all-all"]
}

module "jumpbox" {

  ami                         = "ami-0a14db46282743a66" # Ubuntu Focal in us-east-2; TODO: Use a data provider here
  source                      = "terraform-aws-modules/ec2-instance/aws"
  version                     = "5.0.0"
  name                        = "tkg-jumpbox"
  instance_type               = "t2.xlarge"
  key_name                    = module.key_pair.key_pair_name
  monitoring                  = false
  vpc_security_group_ids      = [module.jumpbox-sg.security_group_id]
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  create_iam_instance_profile = true
}
