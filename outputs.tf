output "vpc_id" {
  value = module.vpc.vpc_id
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "tmc_cluster_name" {
  value = module.eks_for_tmc.cluster_name
}

output "shared_svcs_cluster_arn" {
  value = module.eks.cluster_arn
}

output "tmc_cluster_arn" {
  value = module.eks_for_tmc.cluster_arn
}

output "aws_region" {
  value = data.aws_region.current.name
}

output "zone_id" {
  value = resource.aws_route53_zone.zone.id
}

output "external_dns_role_arn" {
  value = module.externaldns_irsa_role.iam_role_arn
}

output "certmanager_role_arn" {
  value = module.certmanager_irsa_role.iam_role_arn
}

output "ebs_csi_controller_role_arn" {
  value = module.ebs_irsa_role.iam_role_arn
}

output "cluster_autoscaler_role_arn" {
  value = module.clusterautoscaler_irsa_role.iam_role_arn
}

output "okta_app_client_id" {
  value = resource.okta_app_oauth.tmc.client_id
}

output "okta_app_client_secret" {
  value     = resource.okta_app_oauth.tmc.client_secret
  sensitive = true
}

output "domain" {
  value = local.dns_tmc_domain
}

output "harbor_password" {
  value = resource.random_string.harbor_password.result
}
output "keycloak_password" {
  value = resource.random_string.keycloak_password.result
}
output "minio_password" {
  value = resource.random_string.minio_password.result
}
output "postgres_password" {
  value = resource.random_string.postgres_password.result
}

output "external_dns_role_arn_tmc" {
  value = module.externaldns_irsa_role_tmc_cluster.iam_role_arn
}

output "certmanager_role_arn_tmc" {
  value = module.certmanager_irsa_role_tmc_cluster.iam_role_arn
}

output "ebs_csi_controller_role_arn_tmc" {
  value = module.ebs_irsa_role_tmc_cluster.iam_role_arn
}

output "cluster_autoscaler_role_arn_tmc" {
  value = module.clusterautoscaler_irsa_role_tmc_cluster.iam_role_arn
}
