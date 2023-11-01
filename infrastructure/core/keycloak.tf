locals {
  client_scopes = {
    groups    = "TMC groups",
    email     = "User's email",
    tenant_id = "TMC tenant ID",
    full_name = "User's full name"
  }
}

resource "random_string" "keycloak_password" {
  length  = 16
  special = false
}

resource "random_string" "keycloak_db_password" {
  length  = 16
  special = false
}

resource "random_string" "keycloak_postgres_user_password" {
  length  = 16
  special = false
}
