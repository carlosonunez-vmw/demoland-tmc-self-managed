#!/usr/bin/env bash
#shellcheck disable=SC2046
export $(grep -Ev '^#' "$(dirname "$0")/../.env" | xargs -0)

TMC_INSTALLER_URL="${TMC_INSTALLER_URL?Please provide the URL for the TMC installer}"
TMC_INSTALLER_PATH="${TMPDIR:-/tmp}/tmc-installer"

if test -n "$SOCKS_PROXY" && { test -n "$HTTPS_PROXY" || test -n "$HTTP_PROXY"; }
then
  >&2 echo "ERROR: Please define either SOCKS_PROXY or HTTP(S)_PROXY"
  exit 1
fi

test -f "$TMC_INSTALLER_PATH" && test "$REFETCH" != 'true' &&  exit 0
curl_cmd="curl -Lo $TMC_INSTALLER_PATH"
test -n "$SOCKS_PROXY" && curl_cmd="$curl_cmd -x socks5h://$SOCKS_PROXY"
$curl_cmd "$TMC_INSTALLER_URL" &&
  chmod +x "$TMC_INSTALLER_PATH" &&
  >&2 echo "===> TMC installer downloaded! Find it at $TMC_INSTALLER_PATH \
and \`scp\` it to the TKG bastion host!" &&
  exit 0

>&2 echo "ERROR: Failed to download TMC installer."
exit 1
