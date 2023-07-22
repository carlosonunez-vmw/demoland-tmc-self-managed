#!/usr/bin/env bash
export $(egrep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
source "$(dirname "$0")/scripts/domain.sh"
source "$(dirname "$0")/scripts/terraform_output.sh"
OKTA_ORG_NAME="${OKTA_ORG_NAME?Please define OKTA_ORG_NAME in your .env}"
OKTA_BASE_URL="${OKTA_BASE_URL?Please define OKTA_BASE_URL in your .env}"
KEYCLOAK_CONFIG_DIR="$(dirname "$0")/.data/tanzu/keycloak"
KEYCLOAK_VERSION=21.1.2

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

log_into_keycloak() {
  if test -f "$KEYCLOAK_CONFIG_DIR/kcadm.config"
  then
    now=$(date +%s)
    expiration_time=$(jq -r '.endpoints | to_entries[] | .value.master.expiresAt' \
      "$KEYCLOAK_CONFIG_DIR/kcadm.config") &&
      test "$now" -lt "$expiration_time" && return 0

  fi

  docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
    --rm \
    -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
    bitnami/keycloak \
    config credentials \
    --server "https://keycloak.$1" \
    --realm master \
    --user admin \
    --password "$2"
}

create_keycloak_realm() {
  docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
    --rm \
    -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
    bitnami/keycloak \
    get realms/tanzu-products >/dev/null && return 0

  docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
    --rm \
    -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
    bitnami/keycloak \
    create realms -s realm=tanzu-products -s enabled=true
}

configure_okta_saml_provider() {
  discovery_endpoint="https://${OKTA_ORG_NAME}.${OKTA_BASE_URL}/oauth2/default/.well-known/openid-configuration?client_id=$1"
  docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
    --rm \
    -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
    bitnami/keycloak \
    get realms/tanzu-products/identity-provider/instances/okta-integration >/dev/null && return 0

  config=$(docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
    --rm \
    -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
    bitnami/keycloak \
    create realms/tanzu-products/identity-provider/import-config  \
      -s fromUrl="$discovery_endpoint" \
      -s providerId=oidc \
      -o) || return 1

  payload=$(jq -c \
    --arg id "$1" \
    --arg secret "$2" \
    '{"alias":"okta-integration","displayName":"Okta Integration","providerId":"oidc","config":.} | .config.clientId=$id | .config.clientSecret=$secret' <<< "$config") || return 1

  docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
    --rm \
    -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
    bitnami/keycloak \
    create realms/tanzu-products/identity-provider/instances  \
    -b "$payload"
}

create_tmc_client() {
  docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
    --rm \
    -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
    bitnami/keycloak \
    get clients -q id=tmc-sm -r tanzu-products >/dev/null && return 0

  docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
    --rm \
    -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
    bitnami/keycloak \
    create clients -r tanzu-products -b "$(cat <<-CLIENT
{
  "clientId": "tmc-sm",
  "name": "TMC Self Managed Client",
  "directAccessGrantsEnabled": false,
  "protocol": "openid-connect",
  "redirectUris": [
    "https://pinniped-supervisor.$1/provider/pinniped/callback"
  ],
  "serviceAccountsEnabled": false,
  "standardFlowEnabled": true,
  "publicClient": false
}
CLIENT
)"
}

domain="$(domain)" || exit 1
keycloak_password="$(tf_output keycloak_password)" || exit 1
okta_client_id="$(tf_output okta_app_client_id)" || exit 1
okta_client_secret="$(tf_output okta_app_client_secret)" || exit 1
add_bitnami_helm_repo || exit 1
shared_svcs_cluster_arn=$(tf_output shared_svcs_cluster_arn) || exit 1
kubectl config use-context "$shared_svcs_cluster_arn"
chart_version=$(helm search repo bitnami/keycloak --versions --output json |
  jq -r '.[] | select(.app_version == "'$KEYCLOAK_VERSION'") | .version' |
  sort -r |
  head -1) &&
  install_keycloak "$domain" "$chart_version" "$keycloak_password" &&
  log_into_keycloak "$domain" "$keycloak_password" &&
  create_keycloak_realm "$domain" &&
  configure_okta_saml_provider "$okta_client_id" "$okta_client_secret" &&
  create_tmc_client "$domain"
