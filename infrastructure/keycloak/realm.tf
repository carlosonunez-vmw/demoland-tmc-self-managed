resource "keycloak_realm" "tmc" {
  realm        = "TMC"
  enabled      = true
  display_name = "Tanzu Mission Control"
}

