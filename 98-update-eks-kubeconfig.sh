#!/usr/bin/env bash
DOCKER_COMPOSE="docker-compose --log-level ERROR"
export $(grep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
source "$(dirname "$0")/scripts/domain.sh"
source "$(dirname "$0")/scripts/terraform_output.sh"

update_kubeconfigs_for_example_clusters() {
  >&2 echo "===> Creating and registering additional example clusters..."
  export DNS_TMC_DOMAIN="$1"
  export TMC_SM_USERNAME="$2"
  export TMC_SM_PASSWORD="$3"
  unset DOCKER_DEFAULT_PLATFORM
  delete_tf_output_cache_example_clusters &&
    $DOCKER_COMPOSE run --rm terraform-init-example-clusters &&
    $DOCKER_COMPOSE run --rm terraform-apply-example-clusters
}

region=$(tf_output aws_region) || exit 1
domain="$(domain)" || exit 1
keycloak_user=$(tf_keycloak_output "keycloak_test_user") || exit 1
keycloak_pass=$(tf_keycloak_output "keycloak_test_password") || exit 1
for output_var in cluster_name tmc_cluster_name
do
  cluster_name=$(tf_output "$output_var") || exit 1
  aws eks update-kubeconfig --name "$cluster_name" --region "$region"
done
# Also refresh the service account tokens for the example clusters.
update_kubeconfigs_for_example_clusters "$domain" "$keycloak_user" "$keycloak_pass"
