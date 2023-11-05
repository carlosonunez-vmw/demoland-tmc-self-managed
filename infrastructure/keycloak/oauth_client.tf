resource "random_string" "tmc_client_secret" {
  length  = 32
  special = false
}

resource "keycloak_openid_client" "tmc" {
  realm_id      = keycloak_realm.tmc.id
  client_id     = local.tmc_oauth_client_id
  client_secret = random_string.tmc_client_secret.result
  name          = "Tanzu Mission Control Self-Managed"
  access_type   = "PUBLIC"
  enabled       = true
  valid_redirect_uris = [
    local.tmc_pinniped_supervisor_redirect_uri,
    "http://127.0.0.1:8080"
  ]
  login_theme                  = "keycloak"
  implicit_flow_enabled        = true
  standard_flow_enabled        = true
  direct_access_grants_enabled = true
}

resource "keycloak_openid_client_default_scopes" "scopes" {
  realm_id  = keycloak_realm.tmc.id
  client_id = keycloak_openid_client.tmc.id
  default_scopes = [
    "email",
    "profile",
    keycloak_openid_client_scope.full_name.name,
    keycloak_openid_client_scope.tenant_id.name,
    keycloak_openid_client_scope.groups.name,
  ]
}
