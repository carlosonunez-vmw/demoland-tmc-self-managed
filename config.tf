terraform {
  backend "s3" {}
  required_providers {
    aws = {
      version = "4.67.0"
      source  = "hashicorp/aws"
    }
    okta = {
      version = "4.1.0"
      source  = "okta/okta"
    }
  }
}

provider "aws" {
  ignore_tags {
    key_prefixes = ["kubernetes.io/cluster"]
  }
}

provider "okta" {}
