#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update metrics-server prometheus-community

helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  -f "${ROOT_DIR}/deploy/helm/values/metrics-server.yaml"

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f "${ROOT_DIR}/deploy/helm/values/prometheus.yaml"
