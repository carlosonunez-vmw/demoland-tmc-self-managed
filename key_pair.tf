module "key_pair" {
  source  = "terraform-aws-modules/key-pair/aws"
  version = "2.0.2"

  key_name           = "tkg-jumpbox"
  create_private_key = true
}
