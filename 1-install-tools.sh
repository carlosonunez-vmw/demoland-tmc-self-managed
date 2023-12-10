#!/usr/bin/env bash
source "$(dirname "$0")/scripts/terraform_output.sh"
export $(egrep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
TAP_VERSION=1.5.2
TMC_VERSION=1.1.0
TMC_VERSION_VCC=1.1.0 # NOTE: It's not guaranteed that TMC's version in Customer Connect is semver
TANZU_CLI_DIRECTORY="$(dirname "$(realpath "$0")")/.data/tanzu"
TMC_INSTALLER_TAR_FILE="tmc-self-managed-1.1.tar"
LEGACY_TMC_CLI=https://tmc-cli.s3-us-west-2.amazonaws.com/tmc/0.5.4-a97cb9fb/darwin/x64/tmc
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

download_tmc_sm_installer_from_customer_connect() {
  test -f "${TANZU_CLI_DIRECTORY}/$TMC_INSTALLER_TAR_FILE" && return 0

  local tmc_version="$(cut -f1-2 -d '.' <<< "$TMC_VERSION")"
  >&2 echo "===> Downloading TMC $tmc_version SM installer; this might take a few minutes."
  vcc download -p vmware_tanzu_mission_control_self_managed  \
    -s tmc-sm \
    -v "$TMC_VERSION_VCC" \
    -f "$TMC_INSTALLER_TAR_FILE" \
    -o "${TANZU_CLI_DIRECTORY}" \
    --accepteula
}

extract_tmc_sm_installer() {
  test -f "${TANZU_CLI_DIRECTORY}/tmc/docker/tmc-sm" && return 0

  test -d "${TANZU_CLI_DIRECTORY}/tmc" || mkdir -p "${TANZU_CLI_DIRECTORY}/tmc"
  tar -xf "${TANZU_CLI_DIRECTORY}/$TMC_INSTALLER_TAR_FILE" -C "${TANZU_CLI_DIRECTORY}/tmc"
  mkdir -p "${TANZU_CLI_DIRECTORY}/tmc/docker"
  mv "${TANZU_CLI_DIRECTORY}/tmc/tmc-sm" "${TANZU_CLI_DIRECTORY}/tmc/docker/"
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

install_tmc_cli() {
  if ! docker images | grep "tmc-cli-$TMC_VERSION"
  then \
    # NOTE: Copy the Dockerfile for the TMC CLI into the Tanzu CLI data directory
    # to reduce image context size.
    cp "$(dirname "$0")/tmc-cli.Dockerfile" "$TANZU_CLI_DIRECTORY/tmc/docker/Dockerfile"
    docker build --pull \
      --platform=linux/amd64 \
      -t "tmc-cli-$TMC_VERSION" \
      "$TANZU_CLI_DIRECTORY/tmc/docker"
  fi
}

install_tmc_plugin() {
  tanzu plugin install --group vmware-tmc/default
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
  download_tmc_sm_installer_from_customer_connect &&
  extract_tmc_sm_installer &&
  install_tmc_cli &&
  install_tmc_plugin
