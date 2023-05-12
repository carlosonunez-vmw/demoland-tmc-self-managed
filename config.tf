terraform {
  backend "s3" {}
  required_providers {
    aws = {
      version = "4.67.0"
      source = "hashicorp/aws"
    }
  }
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "4.0.1"
}
