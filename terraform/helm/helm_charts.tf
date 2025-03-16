resource "helm_release" "nginx_ingress" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = var.nginx-ingress_namespace

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

  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "local_file" "cluster_issuer_yaml" {
  content  = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: "your-email@example.com"
    server: "https://acme-v02.api.letsencrypt.org/directory"
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: "nginx"
YAML
  filename = "${path.module}/helm_values/cluster_issuer.yaml"
}

resource "null_resource" "apply_cluster_issuer" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local_file.cluster_issuer_yaml.filename}"
  }

  depends_on = [helm_release.cert_manager]
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



