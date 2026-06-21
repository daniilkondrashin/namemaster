#!/usr/bin/env bash
set -euo pipefail

NGINX_GATEWAY_FABRIC_REF="${NGINX_GATEWAY_FABRIC_REF:-v2.6.5}"

kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=${NGINX_GATEWAY_FABRIC_REF}" | kubectl apply -f -
