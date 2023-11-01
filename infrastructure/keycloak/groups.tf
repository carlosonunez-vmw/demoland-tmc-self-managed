resource "keycloak_group" "admins" {
  realm_id = keycloak_realm.tmc.id
  name     = "tmc:admins"
}

resource "keycloak_group" "members" {
  realm_id = keycloak_realm.tmc.id
  name     = "tmc:members"
}
