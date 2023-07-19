#!/usr/bin/env bash
export $(egrep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
source "$(dirname "$0")/scripts/domain.sh"
source "$(dirname "$0")/scripts/terraform_output.sh"
TMC_VERSION=1.0.0
domain="$(domain)" || exit 1
export DOMAIN_NAME="$domain"

create_namespace() {
  echo "\
apiVersion: v1
kind: Namespace
metadata:
  name: tmc-install
" | kapp deploy -n tanzu-package-repo-global -a tmc-${TMC_VERSION}-config -f - --yes || return 1
}

create_registry_secret() {
  tanzu secret registry add tmc-registry \
    --username admin \
    --password "$1" \
    --server "harbor.$DOMAIN_NAME" \
    --export-to-all-namespaces --yes --namespace tmc-install
}

add_package_repository() {
  tanzu package repository add tanzu-tmc-repository  \
    --url "harbor.${DOMAIN_NAME}/tmc-${TMC_VERSION}/package-repository" \
    --namespace tmc-install
}

harbor_password="$(tf_output harbor_password)" || exit 1

create_namespace &&
  create_registry_secret "$harbor_password" &&
  add_package_repository
