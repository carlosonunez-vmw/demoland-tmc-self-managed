#!/usr/bin/env bash
export $(egrep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
source "$(dirname "$0")/scripts/domain.sh"
source "$(dirname "$0")/scripts/terraform_output.sh"
TMC_VERSION=1.1.0
domain="$(domain)" || exit 1
export DOMAIN_NAME="$domain"

create_namespace() {
  echo "\
apiVersion: v1
kind: Namespace
metadata:
  name: tmc-local
" | kapp deploy -n tanzu-package-repo-global -a tmc-${TMC_VERSION}-config -f - --yes || return 1
}

add_package_repository() {
  tanzu package repository add tanzu-tmc-repository  \
    --url "harbor.${DOMAIN_NAME}/tmc-${TMC_VERSION}/package-repository:${TMC_VERSION}" \
    --namespace tmc-local
}

tmc_cluster_arn=$(tf_output tmc_cluster_arn)
shared_svcs_cluster_arn=$(tf_output shared_svcs_cluster_arn)
kubectl config use-context "$tmc_cluster_arn"
trap 'rc=$?; kubectl config use-context '"$shared_svcs_cluster_arn"'; exit $rc' INT HUP EXIT
create_namespace &&
  add_package_repository
