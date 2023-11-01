data "okta_auth_server" "default" {
  name = "default"
}

data "okta_app_oauth" "app" {
  label = "TMC Self Managed Keycloak Provider"
}
