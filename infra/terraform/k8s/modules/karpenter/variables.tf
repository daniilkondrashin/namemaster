variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "node_iam_role_name" {
  description = "IAM role name used by Karpenter-launched nodes"
  type        = string
}

variable "irsa_oidc_provider_arn" {
  description = "OIDC provider ARN used by the Karpenter controller service account IRSA trust policy"
  type        = string
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
}
