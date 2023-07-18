#!/usr/bin/env bash
# shellcheck disable=SC2046
export $(grep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
usage() {
  cat <<-EOF
Downloads TAP packages into your registry, as recommended by the docs.
Usage: $(basename "$0")

Environment Variables

  INSTALL_REGISTRY_USERNAME       The username to your Harbor registry.
  INSTALL_REGISTRY_PASSWORD       The password associated with your username.
  DOMAIN_NAME                     The name of the domain you used to provision Harbor into.
EOF
  echo "$1"
  exit "${2:-0}"
}
IMGPKG_APP_PATH="$(dirname "$(realpath "$0")")/.data/tanzu/cluster-essentials/imgpkg"
export TARGET_REPOSITORY=tap
export INSTALL_REGISTRY_USERNAME="${INSTALL_REGISTRY_USERNAME?Please define INSTALL_REGISTRY_USERNAME in .env}"
export INSTALL_REGISTRY_PASSWORD="${INSTALL_REGISTRY_PASSWORD?Please define INSTALL_REGISTRY_PASSWORD in .env}"
export DOMAIN_NAME="${DOMAIN_NAME?Please define DOMAIN_NAME in .env}"
export TAP_VERSION=1.5.2

login_to_local_regsitry() {
  docker login "harbor.${DOMAIN_NAME}" -u admin -p supersecret
}

login_to_tap_registry() {
  docker login registry.tanzu.vmware.com -u "$INSTALL_REGISTRY_USERNAME" \
    -p "$INSTALL_REGISTRY_PASSWORD"
}

# This needs to be set to 'localhost' instead of 'registry' since imgpkg
# runs on your computer instead of within a Kubernetes pod.
slurp_images() {
  "$IMGPKG_APP_PATH" copy \
    -b "registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:${TAP_VERSION}" \
      --to-repo "harbor.${DOMAIN_NAME}/tap-${TAP_VERSION}/tap-packages" \
      --registry-insecure \
      --registry-verify-certs=false
}

login_to_local_regsitry &&
  login_to_tap_registry &&
  slurp_images
