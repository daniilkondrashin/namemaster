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
KARPENTER_QUEUE_NAME="$(terraform_output karpenter_queue_name)"
KARPENTER_NODE_ROLE_NAME="$(terraform_output karpenter_node_iam_role_name)"

export CLUSTER_NAME
export KARPENTER_AMI_ALIAS
export KARPENTER_NODE_ROLE_NAME

helm registry logout public.ecr.aws >/dev/null 2>&1 || true

helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version "${KARPENTER_VERSION}" \
  --namespace kube-system \
  --create-namespace \
  --set "replicas=1" \
  --set "settings.clusterName=${CLUSTER_NAME}" \
  --set "settings.clusterEndpoint=${CLUSTER_ENDPOINT}" \
  --set "settings.interruptionQueue=${KARPENTER_QUEUE_NAME}" \
  --set-string 'nodeSelector.karpenter\.sh/controller=true' \
  --set "dnsPolicy=Default" \
  --set "controller.resources.requests.cpu=250m" \
  --set "controller.resources.requests.memory=512Mi" \
  --set "controller.resources.limits.cpu=1" \
  --set "controller.resources.limits.memory=1Gi" \
  --wait

envsubst < "${ROOT_DIR}/deploy/helm/platform/karpenter/nodeclass.yaml" | kubectl apply -f -
kubectl apply -f "${ROOT_DIR}/deploy/helm/platform/karpenter/nodepool.yaml"
