#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

helm upgrade --install namemaster "${ROOT_DIR}/apps/namemaster/chart" \
  --namespace namemaster \
  --create-namespace

helm upgrade --install kubernetes-monitor "${ROOT_DIR}/apps/monitoring/chart" \
  --namespace monitoring \
  --create-namespace

helm upgrade --install namemaster-locust "${ROOT_DIR}/apps/locust/chart" \
  --namespace loadtest \
  --create-namespace
