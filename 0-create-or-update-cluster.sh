#!/usr/bin/env bash
{ docker-compose run --rm terraform-init &&
  docker-compose run --rm terraform-apply; } || exit 1

"$(dirname "$0")/98-update-eks-kubeconfig.sh" || exit 1
ebs_csi_arn=$(docker-compose run --rm terraform output --raw ebs_csi_controller_role_arn)  &&
cluster_autoscaler_arn=$(docker-compose run --rm terraform output --raw cluster_autoscaler_role_arn)  &&
  kubectl annotate sa -n kube-system ebs-csi-controller-sa "eks.amazonaws.com/role-arn=$ebs_csi_arn" &&
  kubectl rollout restart -n kube-system deployment ebs-csi-controller &&
  kubectl apply -f "$(dirname "$0")/conf/cluster-autoscaler.yaml" &&
    kubectl annotate sa -n kube-system cluster-autoscaler "eks.amazonaws.com/role-arn=$cluster_autoscaler_arn" &&
    kubectl rollout restart -n kube-system deployment cluster-autoscaler
