#!/usr/bin/env bash
CERT_MANAGER_VERSION=1.7.2+vmware.1-tkg.1
HARBOR_VERSION=2.6.1+vmware.1-tkg.1
TANZU_PACKAGES_VERSION=1.6.1
CONTOUR_VERSION=1.20.2+vmware.2-tkg.1

create_pkg_namespace() {
  kubectl create ns tanzu-package-repo-global || true
}

add_tanzu_standard_pkg_repo() {
  2>/dev/null kubectl get pkgr vmware -n tanzu-package-repo-global ||
  tanzu package repository add vmware -n tanzu-package-repo-global \
    --url "projects.registry.vmware.com/tkg/packages/standard/repo:v$TANZU_PACKAGES_VERSION"
}

install_cert_manager() {
  tanzu package install \
      -n tanzu-package-repo-global \
      cert-manager \
      -p cert-manager.tanzu.vmware.com \
      -v "$CERT_MANAGER_VERSION"
}

install_contour() {
  tanzu package install \
      -n tanzu-package-repo-global \
      contour \
      -p contour.tanzu.vmware.com \
      -v "$CONTOUR_VERSION" \
      --values-file "$(dirname "$0")/conf/contour.values"
}

install_harbor() {
  tanzu package install -n tanzu-package-repo-global harbor \
    -p harbor.tanzu.vmware.com \
    -v "$HARBOR_VERSION" \
    --values-file <(cat <<-EOF
hostname: harbor.$1
harborAdminPassword: supersecret
secretKey: abcdef012345678a
core:
  secret: supersecret
  xsrfKey: abcdef012345678aabcdef012345678a
jobservice:
  secret: supersecret
registry:
  secret: supersecret
database:
  password: supersecret
EOF
)
}

install_cluster_issuer() {
  kubectl apply -f - <<-EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: $2
    privateKeySecretRef:
      name: letsencrypt-sk
    server: https://acme-v02.api.letsencrypt.org/directory
    solvers:
    - selector:
        dnsZones:
          - "$1"
      dns01:
        route53:
          region: "$3"
EOF
}

wait_for_cluster_issuer_to_become_ready() {
  >&2 echo "INFO: Waiting for the Let's Encrypt ClusterIssuer to be validated"
  kubectl wait --for condition=Ready=true --timeout=10m clusterissuer/letsencrypt-prod
}

annotate_cert_manager_with_irsa_ref() {
  kubectl annotate sa -n cert-manager cert-manager "eks.amazonaws.com/role-arn=$1"  &&
    kubectl rollout restart -n cert-manager deployment cert-manager
}

export $(egrep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
email="${EMAIL_ADDRESS?Please provide EMAIL_ADDRESS}"
domain="${DOMAIN_NAME}"
test -z "$domain" &&
  domain="${1?Please provide the domain to use for fronting Harbor.}"
region=$(docker-compose run --rm terraform output -raw aws_region) || exit 1
iam_role=$(docker-compose run --rm terraform output -raw certmanager_role_arn) || exit 1
create_pkg_namespace  &&
  add_tanzu_standard_pkg_repo  &&
  install_cert_manager  &&
  annotate_cert_manager_with_irsa_ref "$iam_role" &&
  install_contour &&
  install_cluster_issuer "$domain" "$email" "$region" &&
  wait_for_cluster_issuer_to_become_ready
