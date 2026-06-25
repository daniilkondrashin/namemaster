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
