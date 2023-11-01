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

log_into_keycloak() {
  >&2 echo "===> Logging into Keycloak"
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

create_keycloak_realm() {
  >&2 echo "===> Creating Keycloak realm for TMC Self Managed stuff"
  docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
    --rm \
    -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
    bitnami/keycloak \
    get realms/"$KEYCLOAK_TMC_REALM" >/dev/null && return 0

  docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
    --rm \
    -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
    bitnami/keycloak \
    create realms -s realm="$KEYCLOAK_TMC_REALM" -s enabled=true
}

create_additional_oauth_scopes() {
  >&2 echo "===> Creating required OAuth scopes for TMC in realm"
  for scope in groups email tenant_id full_name
  do
    docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
        --rm \
        -v ./.data/tanzu/keycloak:/home/keycloak/.keycloak \
        bitnami/keycloak \
        get client-scopes \
        -r "$KEYCLOAK_TMC_REALM" |
          jq -e '.[] | select(.name == "'"$scope"'") | .id?' >/dev/null && continue
    json="$(cat <<-EOF
{
  "name": "$scope",
  "description": "",
  "attributes": {
    "consent.screen.text": "",
    "display.on.consent.screen": "true",
    "include.in.token.scope": "true",
    "gui.order": ""
  },
  "type": "none",
  "protocol": "openid-connect"
}

EOF
)"
    docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
        --rm \
        -v ./.data/tanzu/keycloak:/home/keycloak/.keycloak \
        bitnami/keycloak \
        create client-scopes \
        -b "$json" \
        -r "$KEYCLOAK_TMC_REALM"
  done
  set +x
}

add_hardcoded_claims_to_email_and_tenant_id_scopes() {
  # used via ${!var} expansion.
  # shellcheck disable=SC2034
  tenant_id_claim_json="$(cat <<-EOF
{
  "protocol": "openid-connect",
  "protocolMapper": "oidc-hardcoded-claim-mapper",
  "name": "tenant_id",
  "config": {
    "claim.name": "tenant_id",
    "claim.value": "tmc-sm-tenant",
    "jsonType.label": "String",
    "id.token.claim": "true",
    "access.token.claim": "true",
    "userinfo.token.claim": false,
    "access.tokenResponse.claim": "true"
  }
}
EOF
)"
  # used via ${!var} expansion.
  # shellcheck disable=SC2034
  full_name_claim_json="$(cat <<-EOF
{
  "name": "full_name",
  "protocol": "openid-connect",
  "protocolMapper": "oidc-full-name-mapper",
  "consentRequired": false,
  "config": {
    "id.token.claim": "true",
    "access.token.claim": "true",
    "userinfo.token.claim": "true"
  }
}
EOF
)"
  # used via ${!var} expansion.
  # shellcheck disable=SC2034
  groups_claim_json="$(cat <<-EOF
{
  "protocol": "openid-connect",
  "protocolMapper": "oidc-group-membership-mapper",
  "name": "groups",
  "config": {
    "claim.name": "groups",
    "full.path": false,
    "id.token.claim": "true",
    "access.token.claim": "true",
    "userinfo.token.claim": false
  }
}
EOF
)"
  scopes=$(docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
      --rm \
      -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
      bitnami/keycloak \
      get client-scopes -r "$KEYCLOAK_TMC_REALM") || return 1
  for scope in tenant_id full_name groups
  do
    id=$(jq -e '.[] | select(.name == "'"$scope"'") | .id' <<< "$scopes" | tr -d '"') || continue
    >&2 echo "====> Adding claim to OAuth scope '$scope'"
    existing_scopes=$(jq -r '.[] | select(.id == "'"$id"'") | .protocolMappers[]? | select(.name == "'"$scope"'") | .name?' <<< "$scopes")
    if test -z "$existing_scopes" || test "$existing_scopes" == 'null'
    then
      json_var="${scope}_claim_json"
      json="${!json_var}" || return 1
      docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
        --rm \
        -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
        bitnami/keycloak \
        create "client-scopes/$id/protocol-mappers/models" \
        -r "$KEYCLOAK_TMC_REALM" \
        -b "$json" || return 1
    else
      >&2 echo "=====> Claim already added."
      continue
    fi
  done
}

create_keycloak_groups() {
  >&2 echo "====> Creating required TMC groups"
  for role in 'admin' 'members'
  do
    docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
      --rm \
      -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
      bitnami/keycloak \
      get groups -r "$KEYCLOAK_TMC_REALM" | jq -e '.[] | select(.name == "tmc:'"$role"'") | .id?' >/dev/null  && continue
    docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
      --rm \
      -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
      bitnami/keycloak \
      create groups -r "$KEYCLOAK_TMC_REALM" -s name="tmc:$role" || return 1
  done

}

configure_okta_oidc_provider() {
  >&2 echo "====> Setting up Keycloak/Okta Integration"
  discovery_endpoint="https://${OKTA_ORG_NAME}.${OKTA_BASE_URL}/oauth2/default/.well-known/openid-configuration?client_id=$1"
  docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
    --rm \
    -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
    bitnami/keycloak \
    get realms/"$KEYCLOAK_TMC_REALM"/identity-provider/instances/okta-integration >/dev/null && return 0

  config=$(docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
    --rm \
    -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
    bitnami/keycloak \
    create realms/"$KEYCLOAK_TMC_REALM"/identity-provider/import-config  \
      -s fromUrl="$discovery_endpoint" \
      -s providerId=oidc \
      -o) || return 1

  payload=$(jq -c \
    --arg id "$1" \
    --arg secret "$2" \
    --arg scopes 'openid email groups profile' \
    '{"alias":"okta-integration","displayName":"Okta Integration","providerId":"oidc","trustEmail":true,"config":.} | .config.clientId=$id | .config.clientSecret=$secret | .config.defaultScope=$scopes' <<< "$config") || return 1

  docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
    --rm \
    -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
    bitnami/keycloak \
    create realms/"$KEYCLOAK_TMC_REALM"/identity-provider/instances  \
    -b "$payload"
}

create_okta_integration_admin_mapper() {
  >&2 echo "====> Setting up mapper to make all Okta users admins of TMC (sorry)"
  docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
      --rm \
      -v ./.data/tanzu/keycloak:/home/keycloak/.keycloak \
      bitnami/keycloak \
      get identity-provider/instances/okta-integration/mappers -r "$KEYCLOAK_TMC_REALM" |
        jq -e '.[] | select(.name == "map-admins-to-admins") | .id?' >/dev/null && return 0

  # used via ${!var} expansion.
  # shellcheck disable=SC2034
  email_mapper="$(cat <<-EOF
{
    "id": "1cd34860-dbe7-4d56-bf8b-5770817710d8",
    "name": "email",
    "identityProviderAlias": "okta-integration",
    "identityProviderMapper": "oidc-user-attribute-idp-mapper",
    "config": {
        "syncMode": "INHERIT",
        "are.claim.values.regex": "false",
        "claim": "email",
        "user.attribute": "email",
        "attribute": "firstName"
    }
}
EOF
)"
  # used via ${!var} expansion.
  # shellcheck disable=SC2034
  email_verified_mapper="$(cat <<-EOF
{
    "id": "4c37d742-ccfe-489d-bfb8-af9003bc87d4",
    "name": "email_verified",
    "identityProviderAlias": "okta-integration",
    "identityProviderMapper": "hardcoded-attribute-idp-mapper",
    "config": {
        "attribute.value": "true",
        "syncMode": "INHERIT",
        "are.claim.values.regex": "false",
        "attribute": "emailVerified"
    }
}
EOF
)"
  # used via ${!var} expansion.
  # shellcheck disable=SC2034
  first_name_hardcoded_mapper="$(cat <<-EOF
{
    "id": "02956ec2-f81b-48d0-8a17-6cb3fe9f7458",
    "name": "firstName",
    "identityProviderAlias": "okta-integration",
    "identityProviderMapper": "hardcoded-attribute-idp-mapper",
    "config": {
        "attribute.value": "TMC",
        "syncMode": "INHERIT",
        "are.claim.values.regex": "false",
        "attribute": "firstName"
    }
}
EOF
)"
  # used via ${!var} expansion.
  # shellcheck disable=SC2034
  last_name_hardcoded_mapper="$(cat <<-EOF
{
    "id": "0f75d533-c81c-4cdd-bd90-22ba6b8e913a",
    "name": "lastName",
    "identityProviderAlias": "okta-integration",
    "identityProviderMapper": "hardcoded-attribute-idp-mapper",
    "config": {
        "attribute.value": "User",
        "syncMode": "INHERIT",
        "are.claim.values.regex": "false",
        "attribute": "lastName"
    }
}
EOF
)"
  # used via ${!var} expansion.
  # shellcheck disable=SC2034
  username_mapper="$(cat <<-EOF
{
    "id": "14f3e853-fad1-4b04-9e2e-0624852ecd91",
    "name": "user-name",
    "identityProviderAlias": "okta-integration",
    "identityProviderMapper": "oidc-user-attribute-idp-mapper",
    "config": {
        "syncMode": "INHERIT",
        "are.claim.values.regex": "false",
        "claim": "email",
        "user.attribute": "username"
    }
}
EOF
)"
  # used via ${!var} expansion.
  # shellcheck disable=SC2034
  admin_mapper="$(cat <<-EOF
{
  "name": "map-admins-to-admins",
  "config": {
    "syncMode": "INHERIT",
    "are.claim.values.regex": "true",
    "group": "/tmc:admin",
    "claims": "[{\"key\":\"groups\",\"value\":\"tmc:admin\"}]"
  },
  "identityProviderMapper": "oidc-advanced-group-idp-mapper",
  "identityProviderAlias": "okta-integration"
}
EOF
)"
  for mapper in admin email email_verified first_name_hardcoded \
    last_name_hardcoded
  do
    var="${mapper}_mapper"
    json="${!var}"
    docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
      --rm \
      -v ./.data/tanzu/keycloak:/home/keycloak/.keycloak \
      bitnami/keycloak create identity-provider/instances/okta-integration/mappers \
      -b "$json" \
      -r "$KEYCLOAK_TMC_REALM" || return 1
  done
}

create_tmc_client() {
  >&2 echo "===> Creating TMC Self Managed OAuth client in Keycloak"
  ids=$(docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
    --rm \
    -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
    bitnami/keycloak \
    get clients -q clientId=tmc-sm -r "$KEYCLOAK_TMC_REALM") >/dev/null || return 1
  test -n "$ids" && test "$ids" != "[ ]" && return 0

  docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
    --rm \
    -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
    bitnami/keycloak \
    create clients -r "$KEYCLOAK_TMC_REALM" -b "$(cat <<-CLIENT
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

add_oauth_scopes_to_tmc_client() {
  >&2 echo "====> Adding Keycloak OAuth scopes to newly-created OAuth client"
  client_id=$(docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
    --rm \
    -v "$KEYCLOAK_CONFIG_DIR:/home/keycloak/.keycloak" \
    bitnami/keycloak \
    get clients -q clientId=tmc-sm -r "$KEYCLOAK_TMC_REALM" -F id --format csv |
      tr -d '"') >/dev/null || return 1
  default_client_scopes="$(docker run \
    --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
    --rm \
    -v ./.data/tanzu/keycloak:/home/keycloak/.keycloak \
    bitnami/keycloak get "clients/$client_id/default-client-scopes" \
    -r "$KEYCLOAK_TMC_REALM")" || return 1
  all_scopes="$(docker run \
    --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
    --rm \
    -v ./.data/tanzu/keycloak:/home/keycloak/.keycloak \
    bitnami/keycloak get client-scopes \
    -r "$KEYCLOAK_TMC_REALM" \
    -F id,name)" || return 1
  for scope in groups email tenant_id full_name
  do
    scope_id=$(jq -r '.[] | select(.name == "'"$scope"'") | .id' <<< "$all_scopes")
    jq -e '.[] | select(.id == "'"$scope_id"'") | .id?' <<< "$default_client_scopes" >/dev/null && continue
    docker run --entrypoint /opt/bitnami/keycloak/bin/kcadm.sh \
      --rm \
      -v ./.data/tanzu/keycloak:/home/keycloak/.keycloak \
      bitnami/keycloak update "clients/$client_id/default-client-scopes/$scope_id" -r "$KEYCLOAK_TMC_REALM" || return 1
  done

}

configure_keycloak() {
  delete_tf_output_cache_keycloak
  KEYCLOAK_USER=admin \
    KEYCLOAK_PASSWORD="$2" \
    DNS_TMC_DOMAIN="$1" \
    $DOCKER_COMPOSE run --rm terraform-init-keycloak || return 1
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
