#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TERRAFORM_DIR="${ROOT_DIR}/infra/terraform/k8s"
NGINX_GATEWAY_FABRIC_VERSION="${NGINX_GATEWAY_FABRIC_VERSION:-2.6.5}"
PUBLIC_DOMAIN="${PUBLIC_DOMAIN:-opsbox.org}"

terraform_output() {
  terraform -chdir="${TERRAFORM_DIR}" output -raw "$1"
}

PUBLIC_SUBNET_IDS="$(terraform_output public_subnet_ids_csv)"
if [[ -z "${PUBLIC_SUBNET_IDS}" ]]; then
  echo "Terraform output public_subnet_ids_csv is empty. Run terraform apply in ${TERRAFORM_DIR} first." >&2
  exit 1
fi
HELM_PUBLIC_SUBNET_IDS="${PUBLIC_SUBNET_IDS//,/\\,}"

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
  --create-namespace \
  --set-string "global.domain=${PUBLIC_DOMAIN}" \
  --set-string "gateway.infrastructure.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-subnets=${HELM_PUBLIC_SUBNET_IDS}"
