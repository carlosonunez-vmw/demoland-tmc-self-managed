#!/usr/bin/env bash
export $(egrep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
source "$(dirname "$0")/scripts/domain.sh"
TAP_VERSION=1.5.2
domain="$(domain)" || exit 1
export DOMAIN_NAME="$domain"

create_namespace() {
  echo "\
apiVersion: v1
kind: Namespace
metadata:
  name: tap-install
" | kapp deploy -n tanzu-package-repo-global -a tap-${TAP_VERSION}-config -f - --yes || return 1
}

create_registry_secret() {
  tanzu secret registry add tap-registry \
    --username admin \
    --password supersecret \
    --server harbor.tanzufederal.com \
    --export-to-all-namespaces --yes --namespace tap-install
}

add_package_repository() {
  tanzu package repository add tanzu-tap-repository  \
    --url "harbor.${DOMAIN_NAME}/tap-${TAP_VERSION}/tap-packages" \
    --namespace tap-install
}


create_namespace &&
  create_registry_secret &&
  add_package_repository
