variable "region" {
  description = "AWS region for Terraform state resources"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project prefix used for Terraform state resources"
  type        = string
  default     = "namemaster"
}

variable "bucket_name" {
  description = "Optional explicit S3 bucket name for Terraform state"
  type        = string
  default     = null
}

variable "lock_table_name" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "namemaster-terraform-locks"
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for the DynamoDB lock table"
  type        = bool
  default     = true
}
