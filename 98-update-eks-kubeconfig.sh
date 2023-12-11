#!/usr/bin/env bash
DOCKER_COMPOSE="docker-compose --log-level ERROR"
export $(grep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
source "$(dirname "$0")/scripts/domain.sh"
source "$(dirname "$0")/scripts/terraform_output.sh"

update_tmc_clusters_kubeconfig() {
  local region="$1"
  for output_var in cluster_name tmc_cluster_name
  do
    cluster_name=$(tf_output "$output_var") || exit 1
    aws eks update-kubeconfig --name "$cluster_name" --region "$region"
  done
}

region=$(tf_output aws_region) || exit 1
update_tmc_clusters_kubeconfig "$region"
