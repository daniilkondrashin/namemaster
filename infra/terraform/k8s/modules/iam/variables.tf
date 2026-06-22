variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_arn" {
  description = "EKS cluster ARN"
  type        = string
}

variable "oidc_provider" {
  description = "EKS OIDC provider URL without the https:// prefix"
  type        = string
}

variable "eks_admin_role_name" {
  description = "IAM role name that receives cluster-admin access through an EKS access entry"
  type        = string
}

variable "eks_admin_trusted_principal_arns" {
  description = "AWS principal ARNs allowed to assume the EKS admin role. Defaults to the current account root principal."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
}
