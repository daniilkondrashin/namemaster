variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "nginx-ingress_namespace" {
  type    = string
  default = "nginx-ingress"
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