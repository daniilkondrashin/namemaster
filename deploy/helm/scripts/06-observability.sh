#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
METRICS_SERVER_VERSION="${METRICS_SERVER_VERSION:-3.13.1}"
KUBE_PROMETHEUS_STACK_VERSION="${KUBE_PROMETHEUS_STACK_VERSION:-87.1.0}"

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update metrics-server prometheus-community

helm upgrade --install metrics-server metrics-server/metrics-server \
  --version "${METRICS_SERVER_VERSION}" \
  --namespace kube-system \
  --atomic \
  --timeout 10m \
  -f "${ROOT_DIR}/deploy/helm/values/metrics-server.yaml"

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --version "${KUBE_PROMETHEUS_STACK_VERSION}" \
  --namespace monitoring \
  --create-namespace \
  --atomic \
  --timeout 10m \
  -f "${ROOT_DIR}/deploy/helm/values/prometheus.yaml"
