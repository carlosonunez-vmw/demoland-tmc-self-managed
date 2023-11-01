terraform {
  backend "s3" {}
  required_providers {
    keycloak = {
      version = "4.3.1"
      source  = "mrparkers/keycloak"
    }
  }
}

provider "keycloak" {}
