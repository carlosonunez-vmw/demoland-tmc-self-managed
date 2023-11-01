resource "keycloak_custom_identity_provider_mapper" "email" {
  realm                    = keycloak_realm.tmc.id
  identity_provider_alias  = keycloak_oidc_identity_provider.okta.alias
  name                     = "email"
  identity_provider_mapper = "oidc-user-attribute-idp-mapper"
  extra_config = {
    syncMode                 = "INHERIT"
    "are.claim.values.regex" = "false"
    claim                    = "email"
    "user.attribute"         = "email"
    attribute                = "firstName"
  }
}

resource "keycloak_custom_identity_provider_mapper" "email_verified" {
  realm                    = keycloak_realm.tmc.id
  identity_provider_alias  = keycloak_oidc_identity_provider.okta.alias
  name                     = "email_verified"
  identity_provider_mapper = "hardcoded-attribute-idp-mapper"
  extra_config = {
    syncMode                 = "INHERIT"
    "are.claim.values.regex" = "false"
    attribute                = "emailVerified"
    "attribute.value"        = "true"
  }
}

resource "keycloak_custom_identity_provider_mapper" "first_name" {
  realm                    = keycloak_realm.tmc.id
  identity_provider_alias  = keycloak_oidc_identity_provider.okta.alias
  name                     = "first_name"
  identity_provider_mapper = "hardcoded-attribute-idp-mapper"
  extra_config = {
    syncMode                 = "INHERIT"
    "are.claim.values.regex" = "false"
    attribute                = "firstName"
    "attribute.value"        = local.hardcoded_first_name
  }
}

resource "keycloak_custom_identity_provider_mapper" "last_name" {
  realm                    = keycloak_realm.tmc.id
  identity_provider_alias  = keycloak_oidc_identity_provider.okta.alias
  name                     = "last_name"
  identity_provider_mapper = "hardcoded-attribute-idp-mapper"
  extra_config = {
    syncMode                 = "INHERIT"
    "are.claim.values.regex" = "false"
    attribute                = "lastName"
    "attribute.value"        = local.hardcoded_last_name
  }
}

resource "keycloak_custom_identity_provider_mapper" "user_name" {
  realm                    = keycloak_realm.tmc.id
  identity_provider_alias  = keycloak_oidc_identity_provider.okta.alias
  name                     = "user-name"
  identity_provider_mapper = "oidc-user-attribute-idp-mapper"
  extra_config = {
    syncMode                 = "INHERIT"
    "are.claim.values.regex" = "false"
    claim                    = "email"
    "user.attribute"         = "username"
  }
}

resource "keycloak_custom_identity_provider_mapper" "tmc_admins" {
  realm                    = keycloak_realm.tmc.id
  identity_provider_alias  = keycloak_oidc_identity_provider.okta.alias
  name                     = "tmc:admin"
  identity_provider_mapper = "oidc-advanced-group-idp-mapper"
  extra_config = {
    syncMode                 = "INHERIT"
    "are.claim.values.regex" = "true"
    group                    = "/${keycloak_group.admins.name}"
    claim = jsonencode([{
      key   = "groups",
      value = "tmc:admin"
    }])
  }
}
