locals {
  okta_default_scopes                  = "openid email groups profile"
  tmc_oauth_client_id                  = "tmc-sm"
  tmc_pinniped_supervisor_redirect_uri = "https://pinniped-supervisor.${var.dns_tmc_domain}/provider/pinniped/callback"
  tenant_id                            = "tmc-sm-tenant"
  # Hardcoding name fields until I can figure out how to split them up or get
  # them from Okta.
  hardcoded_first_name = "TMC"
  hardcoded_last_name  = "User"
}


variable "dns_tmc_domain" {
  description = "The DNS domain serving TMC. You can find this in 'dns.tf' in infrastructure/core"
}
