variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "terraform_state_bucket" {
  description = "S3 bucket that stores Terraform remote state"
  type        = string
}

variable "terraform_state_region" {
  description = "AWS region for the Terraform remote state bucket"
  type        = string
  default     = "us-east-1"
}

variable "k8s_state_key" {
  description = "S3 object key for the k8s Terraform state"
  type        = string
  default     = "k8s/terraform.tfstate"
}

variable "nginx_gateway_namespace" {
  type    = string
  default = "nginx-gateway"
}

variable "namemaster_namespace" {
  type    = string
  default = "namemaster"
}
variable "cert-manager_namespace" {
  type    = string
  default = "cert-manager"
}
variable "gitlab-runner_namespace" {
  type    = string
  default = "gitlab-runner"
}
variable "monitoring_namespace" {
  type    = string
  default = "monitoring"
}

variable "default_storage_class_name" {
  description = "Existing Kubernetes StorageClass used by PostgreSQL and Prometheus PVCs."
  type        = string
  default     = "gp2"
}

variable "prometheus_storage_size" {
  description = "Persistent volume size requested by the Prometheus server."
  type        = string
  default     = "50Gi"
}

variable "postgresql_app_username" {
  description = "PostgreSQL application user created by the Bitnami PostgreSQL chart."
  type        = string
  default     = "namemaster"
}

variable "postgresql_database" {
  description = "PostgreSQL database used by the namemaster app."
  type        = string
  default     = "namemaster"
}

variable "nginx_gateway_fabric_version" {
  description = "NGINX Gateway Fabric Helm chart version."
  type        = string
  default     = "2.6.5"
}

variable "nginx_gateway_fabric_crd_ref" {
  description = "Git ref used to install the Gateway API CRDs supported by NGINX Gateway Fabric."
  type        = string
  default     = "v2.6.5"
}

variable "cert_manager_acme_email" {
  description = "Email address used by Let's Encrypt for ACME account notifications."
  type        = string
  default     = "example@gmail.com"
}

variable "cert_manager_gateway_solver_name" {
  description = "Gateway name used by cert-manager HTTP01 Gateway API solver."
  type        = string
  default     = "namemaster"
}
