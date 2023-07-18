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

ensure_qemu_interpreter_for_amd64_cpu_exists_on_arm_systems() {
  grep -Eiq 'arm|aarch64' <<< "$(uname -p)" || return 0

  test "$(docker run --rm --platform linux/amd64 --entrypoint sh docker -c 'uname -m')" == "x86_64" && return 0

  >&2 echo "===> arm64 system detected; configuring your Docker host to use qemu for the TMC installer"
  docker run --rm --privileged aptman/qus -s -- -p x86_64
}

harbor_password=$(docker-compose --log-level ERROR run --rm terraform output -raw harbor_password) || exit 1
trap 'ret=$?; popd; exit $?' INT HUP EXIT

pushd "${TANZU_CLI_DIRECTORY}/tmc"


# Unfortunately, the TMC installer is only compiled for x86-64 Linux targets.
# Instead of standing up an entire jumpbox just to run this installer,
# run it in Docker, and ensure that it uses an x86-64 image.
ensure_qemu_interpreter_for_amd64_cpu_exists_on_arm_systems || exit 1
docker run --rm \
  --platform linux/amd64 \
  -v "$PWD:/work" \
  -w /work \
  --entrypoint /work/tmc-sm \
  docker \
  push-images harbor --project "harbor.${DOMAIN_NAME}/tmc-${TMC_VERSION}" \
    --username admin \
    --password "$harbor_password"
