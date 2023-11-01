resource "keycloak_oidc_identity_provider" "okta" {
  realm             = keycloak_realm.tmc.id
  alias             = "okta"
  authorization_url = data.okta_idp_oidc.default.authorization_url
  client_id         = data.okta_app_oauth.app.client_id
  client_secret     = data.okta_app_oauth.app.client_secret
  token_url         = data.okta_idp_oidc.default.token_url
  default_scopes    = local.okta_default_scopes
}
