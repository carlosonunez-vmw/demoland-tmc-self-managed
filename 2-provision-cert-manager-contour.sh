#!/usr/bin/env bash
export $(egrep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
source "$(dirname "$0")/scripts/terraform_output.sh"
source "$(dirname "$0")/scripts/domain.sh"
CERT_MANAGER_VERSION=1.7.2+vmware.1-tkg.1
TANZU_PACKAGES_VERSION=1.6.1
CONTOUR_VERSION=1.20.2+vmware.2-tkg.1

create_pkg_namespace() {
  kubectl --context "$KUBECTX" create ns tanzu-package-repo-global || true
}

add_tanzu_standard_pkg_repo() {
  2>/dev/null kubectl --context "$KUBECTX" get pkgr vmware -n tanzu-package-repo-global ||
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

install_cluster_issuer() {
  kubectl --context "$KUBECTX" apply -f - <<-EOF
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
  kubectl --context "$KUBECTX" wait --for condition=Ready=true --timeout=10m clusterissuer/letsencrypt-prod
}

annotate_cert_manager_with_irsa_ref() {
  kubectl --context "$KUBECTX" annotate sa -n cert-manager cert-manager "eks.amazonaws.com/role-arn=$1"  &&
    kubectl --context "$KUBECTX" rollout restart -n cert-manager deployment cert-manager
}

# Since we don't have a way of adding annotations to the instance of
# cert-manager installed by this Tanzu package, annotations are
# added after cert-manager is installed.
#
# Since this isn't the desired state that kapp knew about during the install,
# kapp undoes these changes. This prevents cert-manager from receiving the
# AWS IAM role to request via EKS IRSA, which prevents DNS challenges
# from succeeding and new Certificates issued by cert-manager to never
# be issued.
#
# This function tells kapp to not reconcile this app so that this doesn't
# happen.
pause_cert_manager_kapp_reconciliation_so_annotations_remain() {
  kubectl -n tanzu-package-repo-global patch pkgi cert-manager \
    --type merge \
    --patch '{"spec":{"paused":true}}'
}

email="${EMAIL_ADDRESS?Please provide EMAIL_ADDRESS}"
domain="$(domain)" || exit 1
region=$(tf_output aws_region) || exit 1
shared_svcs_cluster_arn=$(tf_output shared_svcs_cluster_arn) || return 1
tmc_cluster_arn=$(tf_output tmc_cluster_arn) || return 1
trap 'rc=$?; kubectl config use-context '"$shared_svcs_cluster_arn"'; exit $rc' INT HUP EXIT
for context_data in "$shared_svcs_cluster_arn;arn" "$tmc_cluster_arn;arn_tmc"
do
  output_suffix="$(cut -f2 -d ';' <<< "$context_data")"
  context="$(cut -f1 -d ';' <<< "$context_data")"
  iam_role=$(tf_output "certmanager_role_$output_suffix") || exit 1
  kubectl config use-context "$context"
  create_pkg_namespace  &&
    add_tanzu_standard_pkg_repo  &&
    install_cert_manager  &&
    pause_cert_manager_kapp_reconciliation_so_annotations_remain &&
    annotate_cert_manager_with_irsa_ref "$iam_role" &&
    install_cluster_issuer "$domain" "$email" "$region" &&
    wait_for_cluster_issuer_to_become_ready
done
kubectl config use-context "$shared_svcs_cluster_arn"
KUBECTX="$shared_svcs_cluster_arn" install_contour
