#!/usr/bin/env bash
for service in example-clusters keycloak
do docker-compose run --rm "terraform-${service}" destroy --auto-approve
done || return 1
docker-compose run --rm terraform destroy --auto-approve
