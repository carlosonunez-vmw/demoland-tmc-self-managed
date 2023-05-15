#!/usr/bin/env bash
usage() {
  cat <<-EOF
$(basename "$0") [OPTIONS]
Perform jumpbox operations

ARGUMENTS

  --public-ip       Get the jumpbox's public IP
  --private-key     Get the jumpbox's private key in OpenSSH format.

EOF
}
_terraform_output() {
  docker-compose run --rm terraform-output
}

public_ip() {
  _terraform_output | jq -r '.jumpbox_ip.value'
}

private_key() {
  _terraform_output | jq -r '.jumpbox_private_key.value'
}

case "$(tr '[:upper:]' '[:lower:]' <<< "$1")" in
  --public-ip)
    public_ip
    ;;
  --private-key)
    private_key
    ;;
  *)
    usage
    >&2 echo "ERROR: Unsupported jumpbox operation: $1"
    exit 1
    ;;
esac
