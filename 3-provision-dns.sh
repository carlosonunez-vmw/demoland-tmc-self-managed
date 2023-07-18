#!/usr/bin/env bash
EXTERNAL_DNS_VERSION=0.13.4
export $(egrep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
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

domain="${DOMAIN_NAME}"
test -z "$domain" &&
  domain="${1?Please provide the domain to use for fronting external-dns.}"
region=$(docker-compose run --rm terraform output -raw aws_region) || exit 1
zone_id=$(docker-compose run --rm terraform output -raw zone_id) || exit 1
role_arn=$(docker-compose run --rm terraform output -raw external_dns_role_arn) || exit 1
add_bitnami_helm_repo || exit 1
chart_version=$(helm search repo bitnami/external-dns --versions --output json |
  jq -r '.[] | select(.app_version == "'$EXTERNAL_DNS_VERSION'") | .version' |
  sort -r |
  head -1) &&
  install_external_dns "$domain" "$chart_version" "$region" "$zone_id" "$role_arn"
