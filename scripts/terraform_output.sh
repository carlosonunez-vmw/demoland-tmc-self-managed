#!/usr/bin/env bash
_output_cache() {
  local service="$1"
  echo "$(dirname "$0")/.data/tanzu/tf-output-${service}"
}

_tf_output() {
  local service="$1"
  local key="$2"
  if test -z "$REBUILD_OUTPUT" && test -f "$(_output_cache "$service")"
  then
    val=$(jq --arg key "$key" \
      -r '.|to_entries[]|select(.key == $key)|.value.value' "$(_output_cache "$service")")
    if test "$val" == "null"
    then val=""
    fi
    if test -z "$val"
    then
      >&2 echo "ERROR: key not defined in cached Terraform output: $key.

To regenerate it, add REBUILD_OUTPUT=1 with your script.

If you just created this output in your Terraform configuration, run \
$(dirname "$0")/0-create-or-update-cluster.sh to add it to your Terraform state."
      return 1
    fi
    echo "$val"
    return 0
  fi
  >&2 echo "===> Caching Terraform output; stand by. (Add REBUILD_OUTPUT=1 to refresh the output)"
  docker-compose run --rm "$service" output -json > "$(_output_cache "$service")" || return 1
  export REBUILD_OUTPUT=""
  _tf_output "$service" "$key"
}

_delete_tf_output_cache() {
  cf="$(_output_cache "$1")"
  test -f "$cf" || return 0
  rm "$cf"
}

tf_output() {
  _tf_output "terraform" "$1"
}

tf_keycloak_output() {
  _tf_output "terraform-keycloak" "$1"
}

delete_tf_output_cache() {
  _delete_tf_output_cache "terraform"
}

delete_tf_output_cache_keycloak() {
  _delete_tf_output_cache "terraform-keycloak"
}
