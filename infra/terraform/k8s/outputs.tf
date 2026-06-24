# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks_cluster.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group id attached to EKS worker nodes and selected by Karpenter"
  value       = module.eks_cluster.node_security_group_id
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks_cluster.cluster_name
}

output "public_subnet_ids_csv" {
  description = "Comma-separated public subnet IDs used by public Kubernetes load balancers"
  value       = join(",", module.network.public_subnets)
}

output "private_subnet_ids_csv" {
  description = "Comma-separated private subnet IDs used by EKS and Karpenter worker nodes"
  value       = join(",", module.network.private_subnets)
}

output "private_subnet_azs_csv" {
  description = "Comma-separated availability zones used by private Karpenter subnets"
  value       = join(",", module.network.azs)
}

output "vpc_id" {
  description = "VPC ID used by the EKS cluster"
  value       = module.network.vpc_id
}

output "eks_admin_role_arn" {
  description = "IAM role ARN with EKS cluster-admin access"
  value       = module.iam.eks_admin_role_arn
}

output "ebs_csi_iam_role_arn" {
  description = "IAM role ARN used by the AWS EBS CSI driver service account"
  value       = module.iam.ebs_csi_iam_role_arn
}

output "karpenter_controller_iam_role_arn" {
  description = "IAM role ARN used by the Karpenter controller through IRSA"
  value       = module.autoscaler.controller_iam_role_arn
}

output "karpenter_node_iam_role_name" {
  description = "IAM role name used by EC2 nodes launched by Karpenter"
  value       = module.autoscaler.node_iam_role_name
}

output "karpenter_queue_name" {
  description = "SQS interruption queue name consumed by Karpenter"
  value       = module.autoscaler.queue_name
}
