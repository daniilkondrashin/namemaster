resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx-ingress-controller"
  namespace  = var.nginx-ingress_namespace  # Замените на ваше пространство имен, если необходимо

  set {
    name  = "controller.scope.enabled"
    value = "true"
  }
}
resource "helm_release" "metrics_server" {
  name      = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart     = "metrics-server"
  namespace = "kube-system"

  set {
    name  = "metrics.enabled"
    value = false
  }
  set_list {
    name  = "args"
    value = ["--kubelet-insecure-tls"]
  }

  # Добавьте другие параметры Helm, если необходимо
}
resource "helm_release" "postgresql" {
  name      = "postgresql"
  chart     = "bitnami/postgresql"
  namespace  = var.namemaster_namespace

  # Добавьте другие параметры Helm, если необходимо
}
resource "helm_release" "cert_manager" {
  name      = "cert-manager"
  chart     = "jetstack/cert-manager"


  namespace = var.cert-manager_namespace
  set {
    name  = "installCRDs"
    value = "true"
  }


  # set {
  #   name  = "global.imageRegistry"
  #   value = "docker.io"
  # }

  # Добавьте другие параметры Helm, если необходимо
}
resource "helm_release" "gitlab-runner" {
  name      = "gitlab-runner"
  repository = "https://charts.gitlab.io"
  chart     = "gitlab-runner"
  namespace = var.gitlab-runner_namespace
  
  values = [
    file("${path.module}/helm_values/gitlab-runner_values.yaml")
  ]

  # Добавьте другие параметры Helm, если необходимо
}


