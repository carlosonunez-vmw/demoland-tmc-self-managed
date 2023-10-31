#!/usr/bin/env bash
export $(egrep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
source "$(dirname "$0")/scripts/domain.sh"
source "$(dirname "$0")/scripts/terraform_output.sh"
KEYCLOAK_CONFIG_DIR="$(dirname "$0")/.data/tanzu/keycloak"
KEYCLOAK_TMC_REALM=tanzu-products

log_into_keycloak() {
  if test -f "$KEYCLOAK_CONFIG_DIR/kcadm.config"
  then
    now=$(date +%s)
    # thanks, keycloak, fo providing a hyper-specific expiration time
    # for no reason. UNIX epoch times are only ten digits long.
    expiration_time=$(jq -r '.endpoints | to_entries[] | .value.master.expiresAt' \
      "$KEYCLOAK_CONFIG_DIR/kcadm.config" | head -c 10) &&
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

user_id() {
  id=$(docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
    --rm \
    -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
    bitnami/keycloak \
    get users -q email="$1" -F id --format csv -r tanzu-products) || return 1
  if test -z "$id"
  then
    >&2 echo "ERROR: No ID found matching email '$1'"
    return 1
  fi
  tr -d '"' <<< "$id"
}

verify_user_email() {

  _mark_email_verified() {
    docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
          --rm \
          -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
          bitnami/keycloak  \
          update "users/$1" -r tanzu-products -s emailVerified=true
  }

  local id="$1"
  >&2 echo "====> Verifying Keycloak user [$id]"
  _mark_email_verified "$id"
}

add_user_to_admins_group() {
  local id="$1"
  group_id=$(
    docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
          --rm \
          -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
          bitnami/keycloak  \
          get groups -r "$KEYCLOAK_TMC_REALM" |
      jq -r '.[] | select(.name == "tmc:admin") | .id' 
  ) || return 1
  if test -z "$group_id" || test "$group_id" == 'null'
  then
    >&2 echo "===> tmc:admin group not found."
    return 1
  fi
  >&2 echo "====> Adding user [$id] to tmc:admin group [$group_id]"
  docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
        --rm \
        -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
        bitnami/keycloak  \
        update "users/$id/groups/$group_id" \
        -r "$KEYCLOAK_TMC_REALM"
}

domain="$(domain)" || exit 1
keycloak_password="$(tf_output keycloak_password)" || exit 1
log_into_keycloak "$domain" "$keycloak_password" || exit 1
email="${1?Please provide the email address of the user to be verified}"
if ! id="$(user_id "$email")"
then
  >&2 echo "ERROR: User [$email] not found."
  exit 1
fi

verify_user_email "$id" && add_user_to_admins_group "$id"
