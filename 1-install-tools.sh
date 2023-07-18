#!/usr/bin/env bash
TAP_VERSION=1.5.2
TANZU_CLI_DIRECTORY="$(dirname "$(realpath "$0")")/.data/tanzu"
TANZU_CLI_PIVNET_PACKAGE="tanzu-cli-tap-${TAP_VERSION}"
TANZU_CLI_TAR_FILE="${TANZU_CLI_DIRECTORY}/tanzu-framework-darwin-amd64.tar"

tanzu_cli_tar_present() {
  find "$TANZU_CLI_DIRECTORY" -name 'tanzu-framework-darwin*' &>/dev/null
}

extract_tanzu_cli_tar() {
  test -f "$TANZU_CLI_DIRECTORY/cli-extracted" && return 0

  find "$TANZU_CLI_DIRECTORY" -name 'tanzu-framework-darwin*' \
    -exec tar -xvf {} -C "$TANZU_CLI_DIRECTORY" \; &&
  tar -xvf "$TANZU_CLI_TAR_FILE" -C "$TANZU_CLI_DIRECTORY" &&
    touch "$TANZU_CLI_DIRECTORY/cli-extracted"
}

download_tanzu_cli_with_pivnet() {
  pivnet login --api-token="$1"  || return 1
  pivnet product-files -p tanzu-application-platform -r "$TAP_VERSION" --format=json | \
     jq '.[] | select(.name | contains("framework-bundle-mac")) | .id' | \
     xargs -I {} pivnet download-product-files -p tanzu-application-platform \
       -r "$TAP_VERSION" -i {} -d "$TANZU_CLI_DIRECTORY"
}

install_tanzu_cli() {
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
  trap 'popd &>/dev/null' INT HUP EXIT RETURN
  &>/dev/null pushd "$TANZU_CLI_DIRECTORY" || return 1
  TANZU_CLI_NO_INIT=true tanzu plugin install --local cli all
}

create_tanzu_cli_dir() {
  test -d "$TANZU_CLI_DIRECTORY" || mkdir -p "$TANZU_CLI_DIRECTORY"
}

install_kapp_controller() {
  kapp deploy -a kc --yes -f https://github.com/vmware-tanzu/carvel-kapp-controller/releases/latest/download/release.yml
}

token="${1?Please provide a Pivotal Network token}"
tanzu_cli_tar_present || {
  create_tanzu_cli_dir &&
  download_tanzu_cli_with_pivnet "$token" && exit 1;
}
extract_tanzu_cli_tar &&
  install_tanzu_cli &&
  install_tanzu_plugins &&
  install_kapp_controller
