#!/usr/bin/env bash
#shellcheck disable=SC2046
export $(grep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
source "$(dirname "$0")/scripts/domain.sh"
source "$(dirname "$0")/scripts/terraform_output.sh"
TMC_VERSION=1.0.0
install_harbor() {
  echo "\
apiVersion: v1
kind: Namespace
metadata:
  name: tanzu-system-registry
" | kapp deploy -n tanzu-package-repo-global -a harbor-ns -f - --yes || return 1
  kapp deploy -a harbor -n tanzu-package-repo-global \
    --into-ns tanzu-system-registry \
    --yes \
    -f <(helm template harbor bitnami/harbor -n tanzu-system-registry --version "$2" -f - <<-EOF
adminPassword: "$3"
externalURL: https://harbor.$1
service:
  type: ClusterIP
  tls:
    enabled: true
    existingSecret: harbor-tls
    notaryExistingSecret: notary-tls
exposureType: ingress
persistence:
  persistentVolumeClaim:
    registry:
      size: 50G
ingress:
  core:
    tls: true
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
      ingress.kubernetes.io/force-ssl-redirect: "true"
      kubernetes.io/ingress.class: contour
      kubernetes.io/tls-acme: "true"
      external-dns.alpha.kubernetes.io/hostname: harbor.$1
    hostname: harbor.$1
  notary:
    tls: true
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
      ingress.kubernetes.io/force-ssl-redirect: "true"
      kubernetes.io/ingress.class: contour
      kubernetes.io/tls-acme: "true"
      external-dns.alpha.kubernetes.io/hostname: harbor-notary.$1
    hostname: harbor-notary.$1
EOF
)
}

add_bitnami_helm_repo() {
  helm repo add bitnami https://charts.bitnami.com/bitnami
}

create_tmc_project() {
  curl -u admin:"$2" \
    "https://harbor.$1/api/v2.0/projects" \
     -X POST \
     -H "Content-Type: application/json" \
     -H "Accept: application/json" \
    --data-raw '{"project_name":"tmc-'$TMC_VERSION'","metadata":{"public":"true"},"storage_limit":-1,"registry_id":null}'
  if test "$?" -ne 0
  then
    >&2 echo "WARNING: Unable to create tmc-$TMC_VERSION project in Harbor at harbor.$1; do so manually."
  fi
}

domain="$(domain)" || exit 1
harbor_password="$(tf_output harbor_password)" || exit 1
add_bitnami_helm_repo || exit 1
shared_svcs_cluster_arn=$(tf_output shared_svcs_cluster_arn) || exit 1
kubectl config use-context "$shared_svcs_cluster_arn"
chart_version=$(helm search repo bitnami/harbor --versions --output json |
  jq -r '.[] | select(.app_version == "2.6.1") | .version' |
  sort -r |
  head -1) &&
  install_harbor "$domain" "$chart_version" "$harbor_password" &&
  create_tmc_project "$domain" "$harbor_password"
