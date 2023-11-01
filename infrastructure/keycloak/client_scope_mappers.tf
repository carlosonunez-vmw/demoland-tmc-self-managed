resource "keycloak_generic_protocol_mapper" "groups" {
  realm_id        = keycloak_realm.tmc.id
  name            = "groups"
  client_scope_id = keycloak_openid_client_scope.groups.id
  protocol        = "openid-connect"
  protocol_mapper = "oidc-group-membership-mapper"
  config = {
    "claim.name"         = "tenant"
    "access.token.claim" = "true"
    "id.token.claim"     = "true"
  }
}
resource "keycloak_generic_protocol_mapper" "tenant_id" {
  realm_id        = keycloak_realm.tmc.id
  name            = "tenant_id"
  client_scope_id = keycloak_openid_client_scope.groups.id
  protocol        = "openid-connect"
  protocol_mapper = "oidc-hardcoded-claim-mapper"
  config = {
    "claim.name"         = "tenant_id"
    "claim.value"        = local.tenant_id
    "jsonType.label"     = "String"
    "access.token.claim" = "true"
    "id.token.claim"     = "true"
  }
}
resource "keycloak_generic_protocol_mapper" "full_name" {
  realm_id        = keycloak_realm.tmc.id
  name            = "full_name"
  client_scope_id = keycloak_openid_client_scope.groups.id
  protocol        = "openid-connect"
  protocol_mapper = "oidc-full-name-mapper"
  config = {
    "access.token.claim" = "true"
    "id.token.claim"     = "true"
  }
}
