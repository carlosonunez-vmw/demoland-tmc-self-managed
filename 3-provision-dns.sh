#!/usr/bin/env bash
EXTERNAL_DNS_VERSION=0.13.4
export $(egrep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
source "$(dirname "$0")/scripts/terraform_output.sh"
source "$(dirname "$0")/scripts/domain.sh"
install_external_dns() {
  kapp deploy -a external-dns -n tanzu-package-repo-global \
    --yes \
    -f <(helm template external-dns bitnami/external-dns --version "$2" -f - <<-EOF
provider: aws
policy: upsert-only
txtOwnerId: $4
aws:
  region: $3
  zoneType: public
sources:
  - service
  - ingress
  - contour-httpproxy
domainFilters:
  - $1
serviceAccount:
  create: true
  name: external-dns-sa
  annotations:
    eks.amazonaws.com/role-arn: "$5"
EOF
)
}

add_bitnami_helm_repo() {
  helm repo add bitnami https://charts.bitnami.com/bitnami
}

domain="$(domain)"
region=$(tf_output aws_region) || exit 1
zone_id=$(tf_output zone_id) || exit 1
add_bitnami_helm_repo || exit 1
chart_version=$(helm search repo bitnami/external-dns --versions --output json |
  jq -r '.[] | select(.app_version == "'$EXTERNAL_DNS_VERSION'") | .version' |
  sort -r |
  head -1) || exit 1
shared_svcs_cluster_arn=$(tf_output shared_svcs_cluster_arn) &&
tmc_cluster_arn=$(tf_output tmc_cluster_arn) &&
trap 'rc=$?; kubectl config use-context '"$shared_svcs_cluster_arn"'; exit $rc' INT HUP EXIT
for context_data in "$shared_svcs_cluster_arn;arn" "$tmc_cluster_arn;arn_tmc"
do
  output_suffix="$(cut -f2 -d ';' <<< "$context_data")"
  context="$(cut -f1 -d ';' <<< "$context_data")"
  role_arn=$(tf_output "external_dns_role_$output_suffix") || exit 1
  output_suffix="$(cut -f2 -d ';' <<< "$context_data")"
  context="$(cut -f1 -d ';' <<< "$context_data")"
  kubectl config use-context "$context"
  install_external_dns "$domain" "$chart_version" "$region" "$zone_id" "$role_arn"
done
