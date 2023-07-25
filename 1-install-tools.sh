#!/usr/bin/env bash
source "$(dirname "$0")/scripts/terraform_output.sh"
export $(egrep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
TAP_VERSION=1.5.2
TMC_VERSION=1.0.0
TANZU_CLI_DIRECTORY="$(dirname "$(realpath "$0")")/.data/tanzu"
TMC_INSTALLER_TAR_FILE="tmc-self-managed-${TMC_VERSION}.tar"
export VCC_USER="${VMWARE_CUSTOMER_CONNECT_EMAIL?Please provide VMWARE_EMAIL in your .env}"
export VCC_PASS="${VMWARE_CUSTOMER_CONNECT_PASSWORD?Please provide VMWARE_PASSWORD in your .env}"

tanzu_cli_tar_present() {
  find "$TANZU_CLI_DIRECTORY" -name 'tanzu-framework-darwin*' &>/dev/null
}

extract_tanzu_cli_tar() {
  test -f "$TANZU_CLI_DIRECTORY/cli-extracted" && return 0

  find "$TANZU_CLI_DIRECTORY" -name 'tanzu-framework-darwin*' \
    -exec tar -xvf {} -C "$TANZU_CLI_DIRECTORY" \; &&
    touch "$TANZU_CLI_DIRECTORY/cli-extracted"
}

download_tanzu_cli_with_pivnet() {
  set -x
  pivnet login --api-token="$1"  || return 1
  pivnet product-files -p tanzu-application-platform -r "$TAP_VERSION" --format=json | \
     jq '.[] | select(.name | contains("framework-bundle-mac")) | .id' | \
     xargs -I {} pivnet download-product-files -p tanzu-application-platform \
       -r "$TAP_VERSION" -i {} -d "$TANZU_CLI_DIRECTORY"
}

install_tanzu_cli() {
  &>/dev/null which tanzu && return 0

  trap 'popd &>/dev/null' INT HUP EXIT RETURN
  &>/dev/null pushd "$TANZU_CLI_DIRECTORY" || return 1
  cli_bin=$(find cli -type f -name tanzu-core-darwin_amd64 | head -1)
  if ! test -f "$cli_bin"
  then
    >&2 echo "ERROR: CLI binary not found."
    return 1
  fi
  chmod +x "$cli_bin"
  >&2 echo "===> Installing the Tanzu CLI into your computer; enter password when/if prompted."
  TANZU_CLI_NO_INIT=true sudo install "$cli_bin" /usr/local/bin/tanzu
}

install_tanzu_plugins() {
  test -f "${TANZU_CLI_DIRECTORY}/.plugins-synced" && return 0

  trap 'popd &>/dev/null' INT HUP EXIT RETURN
  &>/dev/null pushd "$TANZU_CLI_DIRECTORY" || return 1
  TANZU_CLI_NO_INIT=true tanzu plugin install --local cli all
  touch "${TANZU_CLI_DIRECTORY}/.plugins-synced"
}

create_tanzu_cli_dir() {
  test -d "$TANZU_CLI_DIRECTORY" || mkdir -p "$TANZU_CLI_DIRECTORY"
}

install_vcc() {
  &>/dev/null which vcc && return 0

  >&2 echo "===> Installing the VMware Customer Connect download tool into your computer; enter password when/if prompted."
   sudo curl -Lo /usr/local/bin/vcc \
       https://github.com/vmware-labs/vmware-customer-connect-cli/releases/download/v1.1.5/vcc-darwin-v1.1.5 &&
       sudo chmod +x /usr/local/bin/vcc
}

download_tmc_from_customer_connect() {
  test -f "${TANZU_CLI_DIRECTORY}/$TMC_INSTALLER_TAR_FILE" && return 0

  >&2 echo "===> Downloading TMC SM; this might take a few minutes."
  vcc download -p vmware_tanzu_mission_control_self_managed  \
    -s tmc-sm \
    -v "1.0" \
    -f "$TMC_INSTALLER_TAR_FILE" \
    -o "${TANZU_CLI_DIRECTORY}" \
    --accepteula
}

extract_tmc() {
  test -f "${TANZU_CLI_DIRECTORY}/tmc/tmc-sm" && return 0

  test -d "${TANZU_CLI_DIRECTORY}/tmc" || mkdir -p "${TANZU_CLI_DIRECTORY}/tmc"
  tar -xf "${TANZU_CLI_DIRECTORY}/$TMC_INSTALLER_TAR_FILE" -C "${TANZU_CLI_DIRECTORY}/tmc"
}

install_kapp_controller() {
  shared_svcs_cluster_arn=$(tf_output shared_svcs_cluster_arn) || return 1
  tmc_cluster_arn=$(tf_output tmc_cluster_arn) || return 1
  for context in "$shared_svcs_cluster_arn" "$tmc_cluster_arn"
  do
    &>/dev/null kubectl --context "$context" get deployment kapp-controller -n kapp-controller ||
      kapp deploy --kubeconfig-context "$context" \
        -a kc --yes -f https://github.com/vmware-tanzu/carvel-kapp-controller/releases/latest/download/release.yml
  done
}

token="${1?Please provide a Pivotal Network token}"
tanzu_cli_tar_present || {
  create_tanzu_cli_dir &&
  download_tanzu_cli_with_pivnet "$token" && exit 1;
}
install_kapp_controller &&
extract_tanzu_cli_tar &&
  install_tanzu_cli &&
  install_tanzu_plugins &&
  install_vcc &&
  download_tmc_from_customer_connect &&
  extract_tmc
