variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public EKS Kubernetes API endpoint"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID for the EKS cluster"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs used by the EKS cluster and Karpenter-launched nodes"
  type        = list(string)
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
}
