domain() {
  docker-compose --log-level ERROR run --rm terraform output -raw domain
}

test -z "${DOMAIN_NAME}" && {
  >&2 echo "ERROR: Please define DOMAIN_NAME in your .env. \
(If you already did this, ensure that you 'source' this script after sourcing \
.env.)"
  exit 1
}
