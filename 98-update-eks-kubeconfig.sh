#!/usr/bin/env bash
export $(egrep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
DEV_NAMESPACE="${DEV_NAMESPACE?Please define DEV_NAMESPACE in your .env}"
create_live_update_compatible_kubeconfig() {
  token=$(aws --region us-east-2 eks get-token --cluster-name tmc-cluster \
    --output text \
    --query 'status.token') || return 1
  arn=$(aws --region us-east-2 eks describe-cluster --name tmc-cluster \
      --output text \
      --query 'cluster.arn') || return 1
  kubectl config set-credentials tap-user --token "$token" &&
    kubectl config set-context tap-live-update-context --cluster="$arn" --user=tap-user --namespace "$DEV_NAMESPACE"
}
region=$(docker-compose run --rm terraform output -raw aws_region) || exit 1
aws eks update-kubeconfig --name tmc-cluster --region "$region"
create_live_update_compatible_kubeconfig
