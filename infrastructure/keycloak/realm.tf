resource "keycloak_realm" "tmc" {
  realm        = "TMC"
  enabled      = true
  display_name = "Tanzu Mission Control"
}


resource "keycloak_user" "test_user" {
  realm_id       = keycloak_realm.tmc.id
  username       = var.keycloak_test_user
  enabled        = true
  email          = var.keycloak_test_user
  email_verified = true
  first_name     = "TMC"
  last_name      = "User"
  initial_password {
    value     = var.keycloak_test_password
    temporary = false
  }
}
