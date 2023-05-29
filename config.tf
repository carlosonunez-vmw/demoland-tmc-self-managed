terraform {
  backend "s3" {}
  required_providers {
    aws = {
      version = "4.67.0"
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  ignore_tags {
    key_prefixes = ["kubernetes.io/"]
  }
}
