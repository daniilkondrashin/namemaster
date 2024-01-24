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
  set {
    name  = "postgresqlPassword"
    value = "6ETSt%WE6x7jSuQG*47poB"  # Установите ваш пароль
  }

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

