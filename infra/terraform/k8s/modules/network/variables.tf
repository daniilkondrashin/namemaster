variable "name" {
  description = "VPC name"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name used for Kubernetes and Karpenter discovery tags"
  type        = string
}

variable "azs" {
  description = "Availability zones for the VPC subnets"
  type        = list(string)
}

variable "cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "private_subnets" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
}

variable "public_subnets" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
}
