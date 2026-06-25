output "state_bucket_name" {
  description = "S3 bucket name for Terraform remote state"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_region" {
  description = "AWS region for Terraform remote state"
  value       = var.region
}
