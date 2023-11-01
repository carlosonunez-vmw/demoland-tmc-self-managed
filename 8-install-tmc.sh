#!/usr/bin/env bash
KEYCLOAK_CONFIG_DIR="$(dirname "$0")/.data/tanzu/keycloak"
TMC_VERSION=1.0.0
export $(egrep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
source "$(dirname "$0")/scripts/domain.sh"

install_tmc() {
  tanzu package install tanzu-mission-control -p tmc.tanzu.vmware.com \
    --version "$TMC_VERSION" \
    --values-file <(echo "$1") \
    --namespace tmc-local \
    --wait \
    --yes
}

get_letsencrypt_ca_chain() {
  curl -sL https://curl.se/ca/cacert.pem
}
domain="$(domain)" || exit 1
tmc_cluster_arn=$(tf_output tmc_cluster_arn)
kubectl config use-context "$tmc_cluster_arn" &&
  client_url="$(tf_keycloak_output tmc_client_oidc_config_url)" &&
  client_id="$(tf_keycloak_output tmc_client_id)"
  client_secret="$(tf_keycloak_output tmc_client_secret)"
  letsencrypt_cas=$(get_letsencrypt_ca_chain) &&
  minio_password="$(tf_output minio_password)" &&
  postgres_password="$(tf_output postgres_password)" &&
  template=$(ytt -v cluster_issuer=letsencrypt-prod \
                 -v domain="$domain" \
                 -v harbor_repo="harbor.$domain" \
                 -v minio_password="$minio_password" \
                 -v keycloak_client_id="$client_id" \
                 -v keycloak_client_secret="$client_secret" \
                 -v keycloak_client_url="$client_url" \
                 -v tmc_postgres_password="$postgres_password" \
                 -v lets_encrypt_chain="$letsencrypt_cas" \
                 -f "$(dirname "$0")/conf/tmc.values.yaml") &&
  >&2 echo "INFO: template: $template"
   install_tmc "$template"
