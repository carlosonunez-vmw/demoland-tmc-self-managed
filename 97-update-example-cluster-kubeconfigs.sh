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
  $DOCKER_COMPOSE run --rm terraform-example-clusters apply -auto-approve \
    -target module.eks_unmanaged-kubeconfig \
    -target module.eks-kubeconfig
}

domain="$(domain)" || exit 1
keycloak_user=$(tf_keycloak_output "keycloak_test_user") || exit 1
keycloak_pass=$(tf_keycloak_output "keycloak_test_password") || exit 1
update_kubeconfigs_for_example_clusters "$domain" "$keycloak_user" "$keycloak_pass"
