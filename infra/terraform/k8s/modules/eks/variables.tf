variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the EKS cluster"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs used by the EKS cluster and managed node groups"
  type        = list(string)
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
}
