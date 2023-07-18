#!/usr/bin/env bash
cluster_name=$(docker-compose --log-level ERROR run --rm terraform output -raw cluster_name) || exit 1
region=$(docker-compose --log-level ERROR run --rm terraform output -raw aws_region) || exit 1
aws eks update-kubeconfig --name "$cluster_name" --region "$region"
