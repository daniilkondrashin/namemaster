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
}

resource "helm_release" "postgresql" {
  name      = "postgresql"
  chart     = "bitnami/postgresql"
  namespace  = var.namemaster_namespace
}

resource "helm_release" "cert_manager" {
  name      = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart     = "cert-manager"
  namespace = var.cert-manager_namespace
}

resource "null_resource" "certissuer" {
  depends_on = [
    helm_release.cert_manager // запустить ресурс после инициализации cert-manager
  ]
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOD
kubectl delete ClusterIssuer certissuer
EOD
  }

  provisioner "local-exec" {
    command = <<EOT
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: certissuer
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: "dankon368024@gmail.com"
    privateKeySecretRef:
      name: cert-manager // ссылка на Secret куда сохранить сертификат
    solvers:
        - http01:
            ingress:
              class: nginx
EOF
EOT
  }
}

resource "helm_release" "gitlab-runner" {
  name      = "gitlab-runner"
  repository = "https://charts.gitlab.io"
  chart     = "gitlab-runner"
  namespace = var.gitlab-runner_namespace
  
  values = [
    file("${path.module}/helm_values/gitlab-runner_values.yaml")
  ]
}

resource "helm_release" "prometheus" {
  name      = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart     = "kube-prometheus-stack"
  namespace = var.monitoring_namespace
  
  values = [
    file("${path.module}/helm_values/prometheus-values.yaml")
  ]
}



