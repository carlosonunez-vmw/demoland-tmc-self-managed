resource "keycloak_oidc_identity_provider" "okta" {
  realm             = keycloak_realm.tmc.id
  alias             = "Okta"
  authorization_url = "${data.okta_auth_server.default.issuer}/v1/authorize"
  token_url         = "${data.okta_auth_server.default.issuer}/v1/token"
  client_id         = data.okta_app_oauth.app.client_id
  client_secret     = data.okta_app_oauth.app.client_secret
  default_scopes    = local.okta_default_scopes
}
