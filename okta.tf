data "okta_user" "me" {
  user_id = "me"
}

data "okta_auth_server" "default" {
  name = "default"
}

resource "okta_auth_server_scope" "groups" {
  auth_server_id   = data.okta_auth_server.default.id
  metadata_publish = "ALL_CLIENTS"
  name             = "groups"
  consent          = "IMPLICIT"
}

resource "okta_auth_server_claim" "groups" {
  auth_server_id          = data.okta_auth_server.default.id
  name                    = "groups"
  value                   = "tmc:.*"
  value_type              = "GROUPS"
  claim_type              = "IDENTITY"
  always_include_in_token = true
  group_filter_type       = "REGEX"
}

resource "okta_group" "admin" {
  name        = "tmc:admin"
  description = "TMC Admin Group"
}
resource "okta_group" "member" {
  name        = "tmc:member"
  description = "TMC Member Group"
}

resource "okta_group_memberships" "self" {
  group_id = okta_group.admin.id
  users    = [data.okta_user.me.id]
}

resource "okta_app_oauth" "tmc" {
  type  = "web"
  label = "TMC Self Managed Keycloak Provider"
  grant_types = [
    "authorization_code",
    "refresh_token",
    "client_credentials",
    "implicit"
  ]
  redirect_uris = [
    "https://keycloak.${local.dns_tmc_domain}/realms/tanzu-products/broker/okta-integration/endpoint"
  ]
  response_types         = ["token", "code"]
  refresh_token_rotation = "ROTATE"
  refresh_token_leeway   = 60
  groups_claim {
    type        = "FILTER"
    filter_type = "REGEX"
    name        = "groups"
    value       = "tmc:.*"
  }
}

resource "okta_app_group_assignments" "tmc" {
  app_id = okta_app_oauth.tmc.id
  group {
    id       = okta_group.admin.id
    priority = 1
  }
}
