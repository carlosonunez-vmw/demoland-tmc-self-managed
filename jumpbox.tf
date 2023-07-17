locals {
  ami_id = "ami-0a14db46282743a66" # Ubuntu Focal in us-east-2; TODO: Use a data provider here
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

data "aws_region" "current" {}

resource "aws_ebs_volume" "extra" {
  availability_zone = element(data.aws_availability_zones.available.names, 0)
  size              = 20
}


module "jumpbox" {

  ami                         = local.ami_id
  source                      = "terraform-aws-modules/ec2-instance/aws"
  version                     = "5.0.0"
  name                        = "tkg-jumpbox"
  instance_type               = "t3a.xlarge"
  key_name                    = module.key_pair.key_pair_name
  monitoring                  = false
  vpc_security_group_ids      = [module.jumpbox-sg.security_group_id]
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  create_iam_instance_profile = true
  iam_role_description        = "Jumpbox IAM role"
  iam_role_policies = {
    AdministratorAccess = "arn:aws:iam::aws:policy/AdministratorAccess"
  }
}

resource "aws_volume_attachment" "extras" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.extra.id
  instance_id = module.jumpbox.id
}
