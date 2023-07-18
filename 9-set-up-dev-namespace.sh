#!/usr/bin/env bash
export $(grep -Ev '^#' "$(dirname "$0")/.env" | xargs -0)
export INSTALL_REGISTRY_USERNAME="${INSTALL_REGISTRY_USERNAME?Please define INSTALL_REGISTRY_USERNAME in .env}"
export INSTALL_REGISTRY_PASSWORD="${INSTALL_REGISTRY_PASSWORD?Please define INSTALL_REGISTRY_PASSWORD in .env}"
export DOMAIN_NAME="${DOMAIN_NAME?Please define DOMAIN_NAME in .env}"
export DEV_NAMESPACE="${DEV_NAMESPACE?Please define DEV_NAMESPACE in .env}"

registry_secret=$(kubectl create secret docker-registry registry-credentials \
    --docker-server="harbor.${DOMAIN_NAME}" \
    --docker-username=admin \
    --docker-password=supersecret \
    -n "$DEV_NAMESPACE" \
    -o yaml \
    --dry-run=client) || return 1
manifest=$(cat <<-MANIFEST
$registry_secret

---

apiVersion: v1
kind: Secret
metadata:
  name: tap-registry
  annotations:
    secretgen.carvel.dev/image-pull-secret: ""
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: e30K

---

apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
secrets:
  - name: registry-credentials
imagePullSecrets:
  - name: registry-credentials
  - name: tap-registry

---

apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default-permit-deliverable
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: deliverable
subjects:
  - kind: ServiceAccount
    name: default

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default-permit-workload
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: workload
subjects:
  - kind: ServiceAccount
    name: default
MANIFEST
)
kapp deploy -a tap-dev-namespace-config \
  -n tap-install \
  --into-ns "${DEV_NAMESPACE}" -f - --yes <<< "$manifest"
