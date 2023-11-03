terraform {
  backend "s3" {}
  required_providers {
    kind = {
      version = "0.17.0"
      source  = "justenwalker/kind"
    }
    aws = {
      version = "4.67.0"
      source  = "hashicorp/aws"
    }
    azurerm = {
      version = "3.79.0"
      source  = "hashicorp/azurerm"
    }
  }
}

provider "kind" {}
provider "aws" {}
provider "azurerm" {
  features {}
}
