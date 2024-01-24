variable "kube_config" {
  type    = string
  default = "~/.kube/config"
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