resource "keycloak_group" "admins" {
  realm_id = keycloak_realm.tmc.id
  name     = "tmc:admin"
}

resource "keycloak_group" "members" {
  realm_id = keycloak_realm.tmc.id
  name     = "tmc:member"
}
