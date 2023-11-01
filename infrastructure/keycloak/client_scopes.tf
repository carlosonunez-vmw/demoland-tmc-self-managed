resource "keycloak_openid_client_scope" "groups" {
  realm_id    = keycloak_realm.tmc.id
  name        = "groups"
  description = "TMC groups"
}

resource "keycloak_openid_client_scope" "tenant_id" {
  realm_id    = keycloak_realm.tmc.id
  name        = "tenant_id"
  description = "TMC tenant_id"
}

resource "keycloak_openid_client_scope" "full_name" {
  realm_id    = keycloak_realm.tmc.id
  name        = "full_name"
  description = "TMC full_name"
}
