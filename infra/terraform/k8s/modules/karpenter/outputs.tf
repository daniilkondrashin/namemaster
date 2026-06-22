output "controller_iam_role_arn" {
  description = "IAM role ARN used by the Karpenter controller through EKS Pod Identity"
  value       = module.karpenter.iam_role_arn
}

output "node_iam_role_name" {
  description = "IAM role name used by EC2 nodes launched by Karpenter"
  value       = module.karpenter.node_iam_role_name
}

output "queue_name" {
  description = "SQS interruption queue name consumed by Karpenter"
  value       = module.karpenter.queue_name
}
