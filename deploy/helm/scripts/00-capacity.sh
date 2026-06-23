#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TERRAFORM_DIR="${ROOT_DIR}/infra/terraform/k8s"

KARPENTER_VERSION="${KARPENTER_VERSION:-1.13.0}"
KARPENTER_AMI_ALIAS="${KARPENTER_AMI_ALIAS:-al2023@latest}"

terraform_output() {
  terraform -chdir="${TERRAFORM_DIR}" output -raw "$1"
}

CLUSTER_NAME="$(terraform_output cluster_name)"
CLUSTER_ENDPOINT="$(terraform_output cluster_endpoint)"
KARPENTER_CONTROLLER_IAM_ROLE_ARN="$(terraform_output karpenter_controller_iam_role_arn)"
KARPENTER_QUEUE_NAME="$(terraform_output karpenter_queue_name)"
KARPENTER_NODE_ROLE_NAME="$(terraform_output karpenter_node_iam_role_name)"
PRIVATE_SUBNET_AZS="$(terraform_output private_subnet_azs_csv)"

if [[ -z "${PRIVATE_SUBNET_AZS}" ]]; then
  echo "Terraform output private_subnet_azs_csv is empty. Run terraform apply in ${TERRAFORM_DIR} first." >&2
  exit 1
fi

IFS=',' read -r -a NODEPOOL_ZONES <<< "${PRIVATE_SUBNET_AZS}"
KARPENTER_NODEPOOL_ZONES="["
for zone in "${NODEPOOL_ZONES[@]}"; do
  if [[ "${KARPENTER_NODEPOOL_ZONES}" != "[" ]]; then
    KARPENTER_NODEPOOL_ZONES+=", "
  fi
  KARPENTER_NODEPOOL_ZONES+="\"${zone}\""
done
KARPENTER_NODEPOOL_ZONES+="]"

export CLUSTER_NAME
export KARPENTER_AMI_ALIAS
export KARPENTER_CONTROLLER_IAM_ROLE_ARN
export KARPENTER_NODE_ROLE_NAME
export KARPENTER_NODEPOOL_ZONES

KARPENTER_VALUES_FILE="$(mktemp)"
trap 'rm -f "${KARPENTER_VALUES_FILE}"' EXIT

envsubst < "${ROOT_DIR}/deploy/helm/platform/karpenter/values.yaml" > "${KARPENTER_VALUES_FILE}"

helm registry logout public.ecr.aws >/dev/null 2>&1 || true

helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version "${KARPENTER_VERSION}" \
  --namespace kube-system \
  --create-namespace \
  --timeout 15m \
  --atomic \
  --cleanup-on-fail \
  -f "${KARPENTER_VALUES_FILE}" \
  --wait

envsubst < "${ROOT_DIR}/deploy/helm/platform/karpenter/nodeclass.yaml" | kubectl apply -f -
envsubst < "${ROOT_DIR}/deploy/helm/platform/karpenter/nodepool.yaml" | kubectl apply -f -
