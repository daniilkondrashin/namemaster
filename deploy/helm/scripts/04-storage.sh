#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TERRAFORM_DIR="${ROOT_DIR}/infra/terraform/k8s"

terraform_output() {
  terraform -chdir="${TERRAFORM_DIR}" output -raw "$1"
}

CLUSTER_NAME="$(terraform_output cluster_name)"
EBS_CSI_IAM_ROLE_ARN="$(terraform_output ebs_csi_iam_role_arn)"

if aws eks describe-addon \
  --cluster-name "${CLUSTER_NAME}" \
  --addon-name aws-ebs-csi-driver >/dev/null 2>&1; then
  aws eks update-addon \
    --cluster-name "${CLUSTER_NAME}" \
    --addon-name aws-ebs-csi-driver \
    --service-account-role-arn "${EBS_CSI_IAM_ROLE_ARN}" \
    --resolve-conflicts OVERWRITE >/dev/null
else
  aws eks create-addon \
    --cluster-name "${CLUSTER_NAME}" \
    --addon-name aws-ebs-csi-driver \
    --service-account-role-arn "${EBS_CSI_IAM_ROLE_ARN}" \
    --resolve-conflicts OVERWRITE >/dev/null
fi

aws eks wait addon-active \
  --cluster-name "${CLUSTER_NAME}" \
  --addon-name aws-ebs-csi-driver

kubectl apply -f "${ROOT_DIR}/deploy/helm/manifests/storageclass-gp3.yaml"
