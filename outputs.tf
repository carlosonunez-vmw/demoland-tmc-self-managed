output "jumpbox_ip" {
  value = module.jumpbox.public_ip
}

output "jumpbox_private_key" {
  value     = module.key_pair.private_key_openssh
  sensitive = true
}

output "user" {
  value     = "ubuntu"
  sensitive = true
}

output "ami_id" {
  value = local.ami_id
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "subnet_1" {
  value = module.vpc.private_subnets[0]
}

output "subnet_2" {
  value = module.vpc.private_subnets[1]
}

output "public_subnet_1" {
  value = module.vpc.public_subnets[0]
}

output "public_subnet_2" {
  value = module.vpc.public_subnets[1]
}

output "region" {
  value = data.aws_region.current.name
}

output "key" {
  value = module.key_pair.key_pair_name
}
