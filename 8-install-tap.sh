#!/usr/bin/env bash
export $(egrep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
source "$(dirname "$0")/include/profiles.sh"
TAP_VERSION=1.5.2


install_tap() {
  template=$(ytt -v domain_name="$DOMAIN_NAME" \
    -v tap_version="$TAP_VERSION" \
    -v catalog_url="$GIT_CATALOGS_URL" \
    -v app_namespace="$DEV_NAMESPACE" \
    -f "$(dirname "$0")/conf/values.yaml") || return 1
  tanzu package install tap \
    -p tap.tanzu.vmware.com \
    -v "$TAP_VERSION" \
    --values-file <(echo "$template") \
    -n tap-install
}

install_tap
