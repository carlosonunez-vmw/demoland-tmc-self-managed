data "okta_idp_oidc" "default" {
  name = "Developer Registration SSO"
}

data "okta_app_oauth" "app" {
  label = "TMC Self Managed Keycloak Provider"
}

