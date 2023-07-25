#!/usr/bin/env bash
KEYCLOAK_CONFIG_DIR="$(dirname "$0")/.data/tanzu/keycloak"
TMC_VERSION=1.0.0
export $(egrep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
source "$(dirname "$0")/scripts/domain.sh"

get_issuer_url_from_keycloak() {
  curl -sS "https://keycloak.$1/realms/tanzu-products/.well-known/openid-configuration" |
    jq -r .issuer
}

get_client_secret_from_keycloak() {
  docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
    --rm \
    -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
    bitnami/keycloak \
    get realms/tanzu-products/identity-provider/instances/okta-integration >/dev/null
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

get_client_id_from_keycloak() {
  json=$(docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
    --rm \
    -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
    bitnami/keycloak \
    get clients -q clientId=tmc-sm -r tanzu-products) || return 1
  jq -r '.[0].clientId' <<< "$json"
}

get_actual_id_from_keycloak() {
  json=$(docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
    --rm \
    -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
    bitnami/keycloak \
    get clients -q clientId=tmc-sm -r tanzu-products) || return 1
  jq -r '.[0].id' <<< "$json"
}

get_client_secret_from_keycloak() {
  value=$(docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
    --rm \
    -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
    bitnami/keycloak \
    get "clients/$1/client-secret" -q id=tmc-sm -r tanzu-products | jq -r '.value') || return 1
  if test "$value" == "null"
  then
    >&2 echo "ERROR: Unable to get client secret for tmc-sm $1"
    return 1
  fi
  echo "$value"
}

install_tmc() {
  tanzu package install tanzu-mission-control -p tmc.tanzu.vmware.com \
    --version "$TMC_VERSION" \
    --values-file <(echo "$1") \
    --namespace tmc-local \
    --wait \
    --yes
}

get_letsencrypt_ca_chain() {
  curl -sL https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem
}

tmc_cluster_arn=$(tf_output tmc_cluster_arn)
kubectl config use-context "$tmc_cluster_arn"
domain="$(domain)" &&
  keycloak_password="$(tf_output keycloak_password)" &&
  letsencrypt_cas=$(get_letsencrypt_ca_chain) &&
  log_into_keycloak "$domain" "$keycloak_password" &&
  minio_password="$(tf_output minio_password)" &&
  postgres_password="$(tf_output postgres_password)" &&
  client_url=$(get_issuer_url_from_keycloak "$domain") &&
  client_id=$(get_client_id_from_keycloak "$domain") &&
  actual_id=$(get_actual_id_from_keycloak "$domain") &&
  client_secret=$(get_client_secret_from_keycloak "$actual_id") &&
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
