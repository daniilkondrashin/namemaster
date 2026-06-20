resource "null_resource" "apply_gateway_api_crds" {
  triggers = {
    ref = var.nginx_gateway_fabric_crd_ref
  }

  provisioner "local-exec" {
    command = "kubectl kustomize \"https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=${var.nginx_gateway_fabric_crd_ref}\" | kubectl apply -f -"
  }
}

resource "helm_release" "nginx_gateway_fabric" {
  name       = "ngf"
  repository = "oci://ghcr.io/nginx/charts"
  chart      = "nginx-gateway-fabric"
  version    = var.nginx_gateway_fabric_version
  namespace  = var.nginx_gateway_namespace

  depends_on = [
    kubernetes_namespace.nginx_gateway,
    null_resource.apply_gateway_api_crds
  ]
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"

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
  name            = "postgresql"
  repository      = "oci://registry-1.docker.io/bitnamicharts"
  chart           = "postgresql"
  namespace       = var.namemaster_namespace
  timeout         = 900
  atomic          = true
  cleanup_on_fail = true

  set {
    name  = "auth.username"
    value = var.postgresql_app_username
  }

  set {
    name  = "auth.database"
    value = var.postgresql_database
  }

  set {
    name  = "primary.persistence.storageClass"
    value = var.default_storage_class_name
  }

  depends_on = [
    kubernetes_namespace.namemaster
  ]
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = var.cert-manager_namespace

  set {
    name  = "crds.enabled"
    value = "true"
  }

  set {
    name  = "config.apiVersion"
    value = "controller.config.cert-manager.io/v1alpha1"
  }

  set {
    name  = "config.kind"
    value = "ControllerConfiguration"
  }

  set {
    name  = "config.enableGatewayAPI"
    value = "true"
  }

  depends_on = [
    kubernetes_namespace.cert-manager,
    null_resource.apply_gateway_api_crds
  ]
}

resource "local_file" "cluster_issuer_yaml" {
  content  = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: "${var.cert_manager_acme_email}"
    server: "https://acme-v02.api.letsencrypt.org/directory"
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        gatewayHTTPRoute:
          parentRefs:
          - name: "${var.cert_manager_gateway_solver_name}"
            namespace: "${var.namemaster_namespace}"
            kind: Gateway
YAML
  filename = "${path.module}/helm_values/cluster_issuer.yaml"
}

resource "null_resource" "apply_cluster_issuer" {
  triggers = {
    acme_email        = var.cert_manager_acme_email
    gateway_name      = var.cert_manager_gateway_solver_name
    gateway_namespace = var.namemaster_namespace
  }

  provisioner "local-exec" {
    command = "kubectl apply -f ${local_file.cluster_issuer_yaml.filename}"
  }

  depends_on = [helm_release.cert_manager]
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = var.monitoring_namespace

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = var.default_storage_class_name
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = var.prometheus_storage_size
  }

  set_list {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes"
    value = ["ReadWriteOnce"]
  }

  depends_on = [
    kubernetes_namespace.monitoring
  ]
}
