#!/usr/bin/env bash
export $(egrep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
source "$(dirname "$0")/scripts/domain.sh"
source "$(dirname "$0")/scripts/terraform_output.sh"
DOCKER_COMPOSE="docker-compose --log-level ERROR"
OKTA_ORG_NAME="${OKTA_ORG_NAME?Please define OKTA_ORG_NAME in your .env}"
OKTA_BASE_URL="${OKTA_BASE_URL?Please define OKTA_BASE_URL in your .env}"
KEYCLOAK_CONFIG_DIR="$(dirname "$0")/.data/tanzu/keycloak"
KEYCLOAK_VERSION=21.1.2
KEYCLOAK_TMC_REALM=tanzu-products

install_keycloak() {
  echo "\
apiVersion: v1
kind: Namespace
metadata:
  name: tanzu-system-auth
" | kapp deploy -n tanzu-package-repo-global -a keycloak-ns -f - --yes || return 1
  kapp deploy -a keycloak -n tanzu-package-repo-global \
    --into-ns tanzu-system-auth \
    --yes \
    -f <(helm template keycloak bitnami/keycloak -n tanzu-system-auth --version "$2" -f - <<-EOF
auth:
  adminUser: admin
  adminPassword: "$3"
postgresql:
  auth:
    password: "$4"
    postgresPassword: "$5"
ingress:
  enabled: true
  hostname: keycloak.$1
  tls: true
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
EOF
)
}

add_bitnami_helm_repo() {
  helm repo add bitnami https://charts.bitnami.com/bitnami
}

remove_mapped_keycloak_user_if_in_state() {
  >&2 echo "===> Removing modified Keycloak user if found in state and ignoring errors if not found..."
  $DOCKER_COMPOSE run --rm terraform-keycloak state rm keycloak_user.user_logged_in_via_okta || true
}

configure_keycloak() {
  delete_tf_output_cache_keycloak &&
  KEYCLOAK_USER=admin \
    KEYCLOAK_PASSWORD="$2" \
    DNS_TMC_DOMAIN="$1" \
    $DOCKER_COMPOSE run --rm terraform-init-keycloak &&
    KEYCLOAK_USER=admin \
      KEYCLOAK_PASSWORD="$2" \
      DNS_TMC_DOMAIN="$1" \
      $DOCKER_COMPOSE run --rm terraform-apply-keycloak
}


domain="$(domain)" || exit 1
keycloak_password="$(tf_output keycloak_password)" || exit 1
keycloak_db_password="$(tf_output keycloak_db_password)" || exit 1
keycloak_postgres_user_pw="$(tf_output keycloak_postgres_user_password)" || exit 1
add_bitnami_helm_repo || exit 1
shared_svcs_cluster_arn=$(tf_output shared_svcs_cluster_arn) || exit 1
kubectl config use-context "$shared_svcs_cluster_arn"
chart_version=$(helm search repo bitnami/keycloak --versions --output json |
  jq -r '.[] | select(.app_version == "'$KEYCLOAK_VERSION'") | .version' |
  sort -r |
  head -1) &&
  install_keycloak "$domain" "$chart_version" "$keycloak_password" "$keycloak_db_password" "$keycloak_postgres_user_pw" &&
  configure_keycloak "$domain" "$keycloak_password" && exit "$?"
