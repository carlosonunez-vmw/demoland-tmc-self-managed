#!/usr/bin/env bash
# shellcheck disable=SC2046
export $(grep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
source "$(dirname "$0")/scripts/domain.sh"
domain="$(domain)" || exit 1
export DOMAIN_NAME="$domain"
IMGPKG_APP_PATH="$(dirname "$(realpath "$0")")/.data/tanzu/cluster-essentials/imgpkg"
export TARGET_REPOSITORY=tap
export INSTALL_REGISTRY_USERNAME="${INSTALL_REGISTRY_USERNAME?Please define INSTALL_REGISTRY_USERNAME in .env}"
export INSTALL_REGISTRY_PASSWORD="${INSTALL_REGISTRY_PASSWORD?Please define INSTALL_REGISTRY_PASSWORD in .env}"
TANZU_CLI_DIRECTORY="$(dirname "$(realpath "$0")")/.data/tanzu"
TMC_VERSION=1.0.0

harbor_password=$(docker-compose run --rm terraform output -raw harbor_password) || exit 1
trap 'ret=$?; popd; exit $?' INT HUP EXIT

pushd "${TANZU_CLI_DIRECTORY}/tmc"
./tmc-sm push-images harbor --project "harbor.${DOMAIN_NAME}/tmc-images-${TMC_VERSION}" \
  --username admin \
  --password "$harbor_password"
