#!/usr/bin/env bash
# shellcheck disable=SC2046
export $(grep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
source "$(dirname "$0")/scripts/domain.sh"
source "$(dirname "$0")/scripts/terraform_output.sh"
DOCKER_COMPOSE="docker-compose --log-level ERROR"
TMC_MGMT_CLUSTER_NAME='test-management-cluster'
TMC_CLI_DATA_DIR="$(dirname "$0")/.data/tanzu/tmc-cli"
KUBECONFIG_DIR="$(dirname "$0")/.data/tanzu/kubeconfigs"
TMC_MGMT_CLUSTER_REG_FILE="${TMC_CLI_DATA_DIR}/regfile.yaml"
TMC_NAMESPACE_IN_SVC_CLUSTER='svc-tmc-c8' # TODO: Get this from the SV cluster, as this could change

usage() {
  cat <<-EOF
[ENV_VARS] $(basename "$0")
Registers a vSphere with Tanzu Supervisor (SV) Cluster in TMC and provisions additional clusters for TMC
to manage.

ENVIRONMENT VARIABLES

  REINIT                               Rebuild the tmc-cli Docker Compose service. (default: false)
  RECREATE_MGMT_CLUSTER                Delete any registered Supervisor clusters in TMC. (default: false)
  VSPHERE_WCP_SUPERVISOR_USERNAME      vSphere username.
  VSPHERE_WCP_SUPERVISOR_PASSWORD      vSphere password.
  VSPHERE_WCP_SUPERVISOR_SERVER        vCenter hostname.
  VSPHERE_WCP_SUPERVISOR_CONTEXT       kubectl context through which the SV cluster is accessed.

NOTES

- Workload Management must be enabled in the Supervisor cluster, and you must have the
  "kubectl-vsphere" plugin installed before using this script.
- This script assumes that you ran the other numbered scripts before this one.
EOF
}

_ensure_supervisor_creds_present() {
  for key in USERNAME PASSWORD SERVER CONTEXT
  do
    env_var="VSPHERE_WCP_SUPERVISOR_${key}"
    test -n "${!env_var}" && continue
    >&2 echo "===> ERROR: vSphere with Tanzu environment variable not present; \
vSphere with Tanzu functions will not work: $env_var"
  done
}

_ensure_kubectl_vsphere_plugin_installed() {
  &>/dev/null which kubectl-vsphere && return 0

  >&2 echo "===> ERROR: You'll need to install the vSphere plugin for \
kubectl. Log into the Supervisor cluster to do that."
  return 1
}

tmc_cli() {
  export DOCKER_DEFAULT_PLATFORM=linux/amd64
  _tmc_cli_init() {
    test -n "$REINIT" && rm -f "$TMC_CLI_DATA_DIR/.initialized"
    test -f "$TMC_CLI_DATA_DIR/.initialized" && return 0

    test -d "$TMC_CLI_DATA_DIR" && mkdir -p "$TMC_CLI_DATA_DIR"
    test -f "$TMC_MGMT_CLUSTER_REG_FILE" || touch "$TMC_MGMT_CLUSTER_REG_FILE"
    chmod 644 "$TMC_MGMT_CLUSTER_REG_FILE"
    $DOCKER_COMPOSE build tmc-cli || return 1

    touch "$TMC_CLI_DATA_DIR/.initialized"
  }

  _tmc_cli_init || return 1
  $DOCKER_COMPOSE run --rm tmc-cli "$@"
}

provision_example_clusters() {
  >&2 echo "===> Creating and registering additional example clusters..."
  export DNS_TMC_DOMAIN="$1"
  export TMC_SM_USERNAME="$2"
  export TMC_SM_PASSWORD="$3"
  unset DOCKER_DEFAULT_PLATFORM
  delete_tf_output_cache_example_clusters &&
    $DOCKER_COMPOSE run --rm terraform-init-example-clusters &&
    $DOCKER_COMPOSE run --rm terraform-apply-example-clusters
}


log_into_tmc_cli() {
  >&2 echo "===> Logging into TMC"
  local domain="$1"
  export TMC_SELF_MANAGED_USERNAME="$2"
  export TMC_SELF_MANAGED_PASSWORD="$3"
  tmc_cli login \
      --self-managed --basic-auth --endpoint "$domain:443" --no-configure \
      --name test || return 1
}

log_into_management_cluster() {
  >&2 echo "===> Logging into management cluster"
  KUBECTL_VSPHERE_PASSWORD="$VSPHERE_WCP_SUPERVISOR_PASSWORD" \
    kubectl vsphere login --vsphere-username="$VSPHERE_WCP_SUPERVISOR_USERNAME" \
      --server "$VSPHERE_WCP_SUPERVISOR_SERVER" \
      --insecure-skip-tls-verify
}

register_management_cluster_with_tmc() {
  >&2 echo '===> Checking if this management cluster was already registered'
  existing_mgmt_clusters=$(tmc_cli managementcluster list)
  if grep -q "$TMC_MGMT_CLUSTER_NAME" <<< "$existing_mgmt_clusters"
  then
    test -z "$RECREATE_MGMT_CLUSTER" && return 0
    >&2 echo "===> Deleting existing management cluster in TMC, as requested"
    tmc_cli managementcluster delete -f "$TMC_MGMT_CLUSTER_NAME"
    attempts=1
    max_attempts=30
    while test "$attempts" -le "$max_attempts"
    do
      >&2 echo "===> Waiting for management cluster to be actually deleted (attempt $attempts/$max_attempts)"
      tmc_cli managementcluster list 2>/dev/null | grep -q "$TMC_MGMT_CLUSTER_NAME" || break
      attempts=$((attempts+1))
      sleep 2
    done
    if test "$attempts" -eq "$max_attempts"
    then
      >&2 echo "===> ERROR: Timed out while waiting for management cluster to be deleted."
      return 1
    fi
  fi
  >&2 echo "===> Registering management cluster within TMC: $TMC_MGMT_CLUSTER_NAME"
  tmc_cli managementcluster register "$TMC_MGMT_CLUSTER_NAME" \
    --kubernetes-provider-type TKGS \
    -c private-clusters \
    -o /root/.vmware-cna-saas/regfile.yaml
}

insert_tmc_namespace_in_sv_cluster_into_reg_file() {
  # Do this in a cross-platform way.
  trap 'rc=$?; rm /tmp/foo.yaml; return $rc' INT HUP
  cp "$TMC_MGMT_CLUSTER_REG_FILE" /tmp/foo.yaml
  sed -E "s/namespace: .*/namespace: $TMC_NAMESPACE_IN_SVC_CLUSTER/g" /tmp/foo.yaml > "$TMC_MGMT_CLUSTER_REG_FILE"

}

register_tmc_with_management_cluster() {
  test -n "$RECREATE_MGMT_CLUSTER" && \
    kubectl --context="$VSPHERE_NAMESPACE_NAME" delete agentinstall --all -n "$TMC_NAMESPACE_IN_SVC_CLUSTER"
  &>/dev/null kubectl --context="$VSPHERE_NAMESPACE_NAME" get agentinstall \
      tmc-agent-installer-config -o name && return 0
  >&2 echo "===> Registering TMC control plane with management cluster..."
  kubectl --context="$VSPHERE_NAMESPACE_NAME" apply -f "$TMC_MGMT_CLUSTER_REG_FILE"
}

ensure_vsphere_ns_present_in_sv_cluster() {
  &>/dev/null kubectl --context="$VSPHERE_WCP_SUPERVISOR_CONTEXT" \
    get ns "$VSPHERE_NAMESPACE_NAME" -o name && return 0

  >&2 echo "===> ERROR: vSphere namespace not found: $VSPHERE_NAMESPACE_NAME. \
Create it in vCenter then run this script again."
  return 1
}

write_kubeconfigs() {
  test -d "$KUBECONFIG_DIR" || mkdir -p "$KUBECONFIG_DIR"
  for kubeconfig in azure_kubeconfig \
    eks_kubeconfig \
    eks_unmanaged_kubeconfig
  do
    >&2 echo "===> Writing Kubeconfig $kubeconfig"
    tf_example_clusters_output "$kubeconfig" > "$KUBECONFIG_DIR/${kubeconfig}.yaml"
  done
}

patch_ebs_csi_serviceaccount_in_unmanaged_cluster() {
  ebs_csi_arn="$(tf_example_clusters_output ebs_csi_controller_role_arn_eks_unmanaged)" || return 1
  tf_example_clusters_output eks_unmanaged_kubeconfig > /tmp/kubeconfig.yaml || return 1
  kubectl -n /tmp/kubeconfig.yaml annotate sa -n kube-system ebs-csi-controller-sa \
    "eks.amazonaws.com/role-arn=$ebs_csi_arn" \
    --overwrite &&
  kubectl -n /tmp/kubeconfig.yaml rollout restart -n kube-system deployment ebs-csi-controller &&
  rm -rf /tmp/kubeconfig.yaml
}

create_velero_snapshot_class_for_unmanaged_cluster() {
  kubectl apply -f - <<-EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: gp2-snapshot-class
  labels:
    velero.io/csi-volumesnapshot-class: "true"
driver: gp2
EOF
}

_ensure_supervisor_creds_present || exit 1
_ensure_kubectl_vsphere_plugin_installed || exit 1

domain="$(domain)" || exit 1
keycloak_user=$(tf_keycloak_output "keycloak_test_user") || exit 1
keycloak_pass=$(tf_keycloak_output "keycloak_test_password") || exit 1
log_into_tmc_cli "$domain" "$keycloak_user" "$keycloak_pass" &&
  log_into_management_cluster &&
  ensure_vsphere_ns_present_in_sv_cluster &&
  register_management_cluster_with_tmc &&
  insert_tmc_namespace_in_sv_cluster_into_reg_file &&
  register_tmc_with_management_cluster &&
  provision_example_clusters "$domain" "$keycloak_user" "$keycloak_pass" &&
  patch_ebs_csi_serviceaccount_in_unmanaged_cluster &&
  create_velero_snapshot_class_for_unmanaged_cluster &&
  write_kubeconfigs
