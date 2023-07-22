OUTPUT_CACHE="$(dirname "$0")/.data/tanzu/tf-output"
tf_output() {
  if test -z "$REBUILD_OUTPUT" && test -f "$OUTPUT_CACHE"
  then
    val=$(jq --arg key "$1" \
      -r '.|to_entries[]|select(.key == $key)|.value.value' "$OUTPUT_CACHE")
    if test "$val" == "null"
    then val=""
    fi
    if test -z "$val"
    then
      >&2 echo "ERROR: key not defined in cached Terraform output: $1.

To regenerate it, add REBUILD_OUTPUT=1 with your script.

If you just created this output in your Terraform configuration, run \
$(dirname "$0")/0-create-or-update-cluster.sh to add it to your Terraform state."
      return 1
    fi
    echo "$val"
    return 0
  fi
  >&2 echo "===> Caching Terraform output; stand by. (Add REBUILD_OUTPUT=1 to refresh the output)"
  docker-compose run --rm terraform output -json > "$OUTPUT_CACHE" || return 1
  tf_output "$1"
}

delete_tf_output_cache() {
  test -f "$OUTPUT_CACHE" || return 0
  rm "$OUTPUT_CACHE"
}
