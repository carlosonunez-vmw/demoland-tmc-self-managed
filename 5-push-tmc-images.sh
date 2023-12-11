#!/usr/bin/env bash
# shellcheck disable=SC2046
export $(grep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
source "$(dirname "$0")/scripts/domain.sh"
source "$(dirname "$0")/scripts/terraform_output.sh"
domain="$(domain)" || exit 1
export DOMAIN_NAME="$domain"
export TARGET_REPOSITORY=tap
export INSTALL_REGISTRY_USERNAME="${INSTALL_REGISTRY_USERNAME?Please define INSTALL_REGISTRY_USERNAME in .env}"
export INSTALL_REGISTRY_PASSWORD="${INSTALL_REGISTRY_PASSWORD?Please define INSTALL_REGISTRY_PASSWORD in .env}"
TANZU_CLI_DIRECTORY="$(dirname "$(realpath "$0")")/.data/tanzu"
TMC_VERSION=1.1.0
BASE_IMAGE="tmc-cli-$TMC_VERSION"

ensure_qemu_interpreter_for_amd64_cpu_exists_on_arm_systems() {
  grep -Eiq 'arm|aarch64' <<< "$(uname -p)" || return 0

  test "$(DOCKER_DEFAULT_PLATFORM=linux/amd64 \
    docker run --rm --platform linux/amd64 --entrypoint sh "busybox:1.35.0" \
    -c 'uname -m')" == "x86_64" && return 0

  >&2 echo "===> arm64 system detected; configuring your Docker host to use qemu for the TMC installer"

  docker run --rm --privileged aptman/qus -s -- -p x86_64
}

ensure_qemu_interpreter_for_amd64_cpu_exists_on_arm_systems || exit 1
harbor_password=$(tf_output harbor_password) || exit 1

trap 'ret=$?; popd; exit $?' INT HUP EXIT
pushd "${TANZU_CLI_DIRECTORY}/tmc"

# Unfortunately, the TMC installer is only compiled for x86-64 Linux targets.
# Instead of standing up an entire jumpbox just to run this installer,
# run it in Docker, and ensure that it uses an x86-64 image.
export DOCKER_DEFAULT_PLATFORM=linux/amd64
if test -n "$ENABLE_IMGPKG_DEBUG_LOGS"
then
  docker run --rm \
    --platform linux/amd64 \
    -v "$PWD/agent-images:/agent-images" \
    -v "$PWD/dependencies:/dependencies" \
    -v "$PWD/packages:/packages" \
    "$BASE_IMAGE" \
    push-images harbor --project "harbor.${DOMAIN_NAME}/tmc-${TMC_VERSION}" \
      --username admin \
      --password "$harbor_password" \
      --enable-imgpkg-debug-logs
else
  docker run --rm \
    --platform linux/amd64 \
    -v "$PWD/agent-images:/agent-images" \
    -v "$PWD/dependencies:/dependencies" \
    -v "$PWD/packages:/packages" \
    "$BASE_IMAGE" \
    push-images harbor --project "harbor.${DOMAIN_NAME}/tmc-${TMC_VERSION}" \
      --username admin \
      --password "$harbor_password"
fi
