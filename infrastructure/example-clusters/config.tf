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
    tanzu-mission-control = {
      version = "1.3.0"
      source  = "vmware/tanzu-mission-control"
    }
  }
}

provider "kind" {}
provider "aws" {}
provider "azurerm" {
  features {}
}

// So the documentation states that the OIDC provider is the
// "URL of the OpenID Connect (OIDC) issuer configured with the
// self-managed Taznu (sic) mission control instance.
//
// However, they don't specify which issuer to use here.
//
// There is an "edge" issuer that the Landing service talks to, which
// is always pinniped-supervisor. However, Pinniped always proxies
// to its downstream issuer, which in this case is Keycloak (who then
// delegates to Okta for the actual authn piece).
//
// The thing that's confusing here is the need for a "username" and
// "password". We don't manage pinniped at all, so where are
// we getting the username and password from? Is it the client ID and
// secret that Pinniped generated when the OIDCIdentityProvider was
// initially created?
//
// From looking at the code for this provider (which is closed-source),
// it's using the well-known client ID for the Pinniped CLI, so I'm
// guessing that it wants a client ID/secret pair.
//
// UPDATE: The identity provider upstream to Pinniped as defined in
// TMC's OIDCIdentityProviders needs to support Resource Owner Password Credentials, i.e.
// Direct Access Grants.
provider "tanzu-mission-control" {
  self_managed {}
}
