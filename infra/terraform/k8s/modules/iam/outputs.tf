output "eks_admin_role_arn" {
  description = "IAM role ARN with EKS cluster-admin access"
  value       = aws_iam_role.eks_admin.arn
}

output "ebs_csi_iam_role_arn" {
  description = "IAM role ARN used by the AWS EBS CSI driver"
  value       = module.ebs_csi_irsa.iam_role_arn
}
