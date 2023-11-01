terraform {
  backend "s3" {}
  required_providers {
    keycloak = {
      version = "4.3.1"
      source  = "mrparkers/keycloak"
    }
    okta = {
      version = "4.1.0"
      source  = "okta/okta"
    }
  }
}

provider "keycloak" {}

provider "okta" {}
