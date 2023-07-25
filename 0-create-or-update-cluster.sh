#!/usr/bin/env bash
source "$(dirname "$0")/scripts/terraform_output.sh"
DOCKER_COMPOSE="docker-compose --log-level ERROR"
{ delete_tf_output_cache &&
  $DOCKER_COMPOSE run --rm terraform-init &&
  $DOCKER_COMPOSE run --rm terraform-apply; } || exit 1

"$(dirname "$0")/98-update-eks-kubeconfig.sh" || exit 1

# Since TMC cannot be installed on a cluster that already has Contour installed,
# we'll need to deploy two EKS clusters and annotate the addons appropriately for
# each one.
#
# We make sure that the "Shared Services" cluster (the one with Harbor and Keycloak)
# is the last context set so that the scripts after this one aren't affected by this change.
#
# (I tried to override the Secret that the TMC installer installs for the
# Contour package so that it disables provisioning Contour, but kapp just wasn't having it.)
ebs_csi_arn=$(tf_output ebs_csi_controller_role_arn)  &&
  cluster_autoscaler_arn=$(tf_output cluster_autoscaler_role_arn)  &&
  shared_svcs_cluster_arn=$(tf_output shared_svcs_cluster_arn) &&
  tmc_cluster_arn=$(tf_output tmc_cluster_arn) &&
  for context_data in "$shared_svcs_cluster_arn;arn" "$tmc_cluster_arn;arn_tmc"
  do
    output_suffix="$(cut -f2 -d ';' <<< "$context_data")"
    context="$(cut -f1 -d ';' <<< "$context_data")"
    # Doing this with a ytt overlay was way too difficult for me.
    cluster_name=$(awk -F '/' '{print $NF}' <<< "$context")
    ebs_csi_arn=$(tf_output "ebs_csi_controller_role_$output_suffix") || exit 1
    cluster_autoscaler_arn=$(tf_output "cluster_autoscaler_role_$output_suffix") || exit 1
    kubectl config use-context "$context"
    kubectl annotate sa -n kube-system ebs-csi-controller-sa "eks.amazonaws.com/role-arn=$ebs_csi_arn" --overwrite &&
    kubectl rollout restart -n kube-system deployment ebs-csi-controller &&
    kubectl apply -f <(sed "s/%CLUSTER_NAME%/$cluster_name/g" "$(dirname "$0")/conf/cluster-autoscaler.yaml") &&
      kubectl annotate sa -n kube-system cluster-autoscaler "eks.amazonaws.com/role-arn=$cluster_autoscaler_arn" --overwrite &&
      kubectl rollout restart -n kube-system deployment cluster-autoscaler
  done &&
  kubectl config use-context "$shared_svcs_cluster_arn"
