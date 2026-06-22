variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "ebs_csi_service_account_role_arn" {
  description = "IAM role ARN used by the AWS EBS CSI driver service account"
  type        = string
}
