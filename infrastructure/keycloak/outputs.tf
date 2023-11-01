output "tmc_sm_client_id" {
  value = local.tmc_oauth_client_id
}

output "tmc_sm_client_secret" {
  value     = keycloak_openid_client.tmc.client_secret
  sensitive = true
}
