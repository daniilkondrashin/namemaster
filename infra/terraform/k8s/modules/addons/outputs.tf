output "ebs_csi_addon_arn" {
  description = "AWS EBS CSI addon ARN"
  value       = aws_eks_addon.ebs_csi_driver.arn
}
