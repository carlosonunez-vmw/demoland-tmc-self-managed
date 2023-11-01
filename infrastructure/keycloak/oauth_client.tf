resource "keycloak_openid_client" "tmc" {
  realm_id    = keycloak_realm.tmc.id
  client_id   = local.tmc_oauth_client_id
  name        = "Tanzu Mission Control Self-Managed"
  access_type = "PUBLIC"
  enabled     = true
  valid_redirect_uris = [
    local.tmc_pinniped_supervisor_redirect_uri
  ]
  login_theme = "keycloak"
}

resource "keycloak_openid_client_default_scopes" "scopes" {
  realm_id  = keycloak_realm.tmc.id
  client_id = keycloak_openid_client.tmc.id
  default_scopes = [
    "groups",
    "email",
    "profile",
    keycloak_openid_client_scope.full_name.name,
    keycloak_openid_client_scope.tenant_id.name,
    keycloak_openid_client_scope.groups.name,
  ]
}
