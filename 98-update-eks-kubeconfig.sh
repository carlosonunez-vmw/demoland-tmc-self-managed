#!/usr/bin/env bash
source "$(dirname "$0")/scripts/terraform_output.sh"
cluster_name=$(tf_output cluster_name) || exit 1
region=$(tf_output aws_region) || exit 1
aws eks update-kubeconfig --name "$cluster_name" --region "$region"
