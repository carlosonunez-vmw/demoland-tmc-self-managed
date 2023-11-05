#!/usr/bin/env bash
export $(egrep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
source "$(dirname "$0")/scripts/domain.sh"
source "$(dirname "$0")/scripts/terraform_output.sh"
DOCKER_COMPOSE="docker-compose --log-level ERROR"

provision_example_clusters() {
  export DNS_TMC_DOMAIN="$1"
  export TMC_SM_USERNAME="$2"
  export TMC_SM_PASSWORD="$3"
  delete_tf_output_cache_example_clusters &&
    $DOCKER_COMPOSE run --rm terraform-init-example-clusters &&
    $DOCKER_COMPOSE run --rm terraform-apply-example-clusters
}

domain="$(domain)" || exit 1
keycloak_user=$(tf_keycloak_output "keycloak_test_user") || exit 1
keycloak_pass=$(tf_keycloak_output "keycloak_test_password") || exit 1
provision_example_clusters "$domain" "$keycloak_user" "$keycloak_pass"
