locals {
  client_scopes = {
    groups    = "TMC groups",
    email     = "User's email",
    tenant_id = "TMC tenant ID",
    full_name = "User's full name"
  }
}

resource "random_string" "keycloak_password" {
  length = 16
}

resource "keycloak_realm" "tmc" {
  count        = var.configure_keycloak == 1 ? 1 : 0
  realm        = "TMC"
  enabled      = true
  display_name = "Tanzu Mission Control"
}

resource "keycloak_openid_client_scope" "scopes" {
  count       = var.configure_keycloak == 1 ? len(local.client_scopes.keys) : 0
  realm_id    = keycloak_realm.tmc.id
  name        = local.client_scopes.keys[count.index]
  description = local.client_scopes[local.client_scopes.keys[count.index]]
}
