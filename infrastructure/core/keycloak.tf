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
