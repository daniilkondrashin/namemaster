#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
NGINX_GATEWAY_FABRIC_VERSION="${NGINX_GATEWAY_FABRIC_VERSION:-2.6.5}"

helm repo add jetstack https://charts.jetstack.io
helm repo update jetstack

helm upgrade --install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --version "${NGINX_GATEWAY_FABRIC_VERSION}" \
  --namespace nginx-gateway \
  --create-namespace \
  -f "${ROOT_DIR}/deploy/helm/values/nginx-gateway-fabric.yaml"

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  -f "${ROOT_DIR}/deploy/helm/values/cert-manager.yaml"

kubectl apply -f "${ROOT_DIR}/deploy/helm/manifests/cluster-issuer.yaml"

helm upgrade --install shared-gateway "${ROOT_DIR}/deploy/helm/platform/gateway" \
  --namespace nginx-gateway \
  --create-namespace
