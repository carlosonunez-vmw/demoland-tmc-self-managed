source "$(dirname "$0")/scripts/terraform_output.sh"
domain() {
  >&2 echo "===> Fetching subzone domain name; stand by"
  tf_output domain || return 1
}

test -z "${DOMAIN_NAME}" && {
  >&2 echo "ERROR: Please define DOMAIN_NAME in your .env. \
(If you already did this, ensure that you 'source' this script after sourcing \
.env.)"
  exit 1
}
