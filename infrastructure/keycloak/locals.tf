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

variable "keycloak_test_user" {
  description = <<-EOF
A test user to create within Keycloak. This user must be an email address and must match the user that's provided to Okta
EOF
}

variable "keycloak_test_password" {
  description = "A test password to initialize 'keycloak_test_user' with"
}
