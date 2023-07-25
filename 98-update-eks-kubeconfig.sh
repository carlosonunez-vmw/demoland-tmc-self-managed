#!/usr/bin/env bash
source "$(dirname "$0")/scripts/terraform_output.sh"
region=$(tf_output aws_region) || exit 1
for output_var in cluster_name tmc_cluster_name
do
  cluster_name=$(tf_output "$output_var") || exit 1
  aws eks update-kubeconfig --name "$cluster_name" --region "$region"
done
