output "tmc_sm_client_id" {
  value = local.tmc_oauth_client_id
}

output "tmc_sm_client_secret" {
  value     = random_string.tmc_client_secret.result
  sensitive = true
}

output "tmc_sm_realm" {
  value = keycloak_realm.tmc.id
}

output "keycloak_test_user" {
  value = var.keycloak_test_user
}

output "keycloak_test_password" {
  value = var.keycloak_test_password
}
