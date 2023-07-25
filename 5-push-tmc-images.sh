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
export DOCKER_DEFAULT_PLATFORM=linux/amd64
TANZU_CLI_DIRECTORY="$(dirname "$(realpath "$0")")/.data/tanzu"
TMC_VERSION=1.0.0
BASE_IMAGE=tmc-sm

ensure_qemu_interpreter_for_amd64_cpu_exists_on_arm_systems() {
  grep -Eiq 'arm|aarch64' <<< "$(uname -p)" || return 0

  test "$(docker run --rm --platform linux/amd64 --entrypoint sh "$BASE_IMAGE" \
    -c 'uname -m')" == "x86_64" && return 0

  >&2 echo "===> arm64 system detected; configuring your Docker host to use qemu for the TMC installer"
  docker run --rm --privileged aptman/qus -s -- -p x86_64
}

harbor_password=$(tf_output harbor_password) || exit 1

if ! docker images | grep -q "$BASE_IMAGE"
then
  docker image build --pull \
    --platform=linux/amd64 -t "$BASE_IMAGE" - < "$(dirname "$0")/tmc-sm.Dockerfile" || exit 1
fi

trap 'ret=$?; popd; exit $?' INT HUP EXIT
pushd "${TANZU_CLI_DIRECTORY}/tmc"

# Unfortunately, the TMC installer is only compiled for x86-64 Linux targets.
# Instead of standing up an entire jumpbox just to run this installer,
# run it in Docker, and ensure that it uses an x86-64 image.
ensure_qemu_interpreter_for_amd64_cpu_exists_on_arm_systems || exit 1
entrypoint=tmc-sm
if test -n "$USE_CUSTOM_TMC_LOCAL_INSTALLER"
then
  if ! test -f "$PWD/tmc-sm-custom"
  then
    >&2 echo "ERROR: Couldn't find custom tmc-sm CLI at $PWD/tmc-sm-custom; \
clone the project from gitlab.eng.vmware.com/cnabu-sre/local-installer and run \
'GOOS=linux GOARCH=amd64 go build cli/... && mv cli/cli $PWD/tmc-sm-custom' to create it"
    exit 1
  fi
  entrypoint=tmc-sm-custom
fi

if test -n "$ENABLE_IMGPKG_DEBUG_LOGS"
then
  docker run --rm \
    --platform linux/amd64 \
    -v "$PWD:/work" \
    -w /work \
    --entrypoint "/work/$entrypoint" \
    "$BASE_IMAGE" \
    push-images harbor --project "harbor.${DOMAIN_NAME}/tmc-${TMC_VERSION}" \
      --username admin \
      --password "$harbor_password" \
      --enable-imgpkg-debug-logs
else
  docker run --rm \
    --platform linux/amd64 \
    -v "$PWD:/work" \
    -w /work \
    --entrypoint "/work/$entrypoint" \
    "$BASE_IMAGE" \
    push-images harbor --project "harbor.${DOMAIN_NAME}/tmc-${TMC_VERSION}" \
      --username admin \
      --password "$harbor_password"
fi
