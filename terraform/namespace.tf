# Creating namespace with the Kubernetes provider is better than auto-creation in the helm_release.
# You can reuse the namespace and customize it with quotas and labels.
resource "kubernetes_namespace" "nginx-ingress" {
  metadata {
    name = var.nginx-ingress_namespace
  }
}
resource "kubernetes_namespace" "namemaster" {
  metadata {
    name = var.namemaster_namespace
  }
}
resource "kubernetes_namespace" "cert-manager" {
  metadata {
    name = var.cert-manager_namespace
  }
}
resource "kubernetes_namespace" "gitlab-runner" {
  metadata {
    name = var.gitlab-runner_namespace
  }
}
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.monitoring_namespace
  }
}
