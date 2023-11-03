#!/usr/bin/env bash
export $(egrep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
source "$(dirname "$0")/scripts/domain.sh"
source "$(dirname "$0")/scripts/terraform_output.sh"
DOCKER_COMPOSE="docker-compose --log-level ERROR"

provision_example_clusters() {
  delete_tf_output_cache_example_clusters &&
    $DOCKER_COMPOSE run --rm terraform-init-example-clusters &&
    $DOCKER_COMPOSE run --rm terraform-apply-example-clusters
}


provision_example_clusters
