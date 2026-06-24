#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PUBLIC_DOMAIN="${PUBLIC_DOMAIN:-opsbox.org}"

helm upgrade --install namemaster "${ROOT_DIR}/apps/namemaster/chart" \
  --namespace namemaster \
  --create-namespace \
  --reuse-values \
  --set-string "global.domain=${PUBLIC_DOMAIN}"

helm upgrade --install kubernetes-monitor "${ROOT_DIR}/apps/monitoring/chart" \
  --namespace monitoring \
  --create-namespace \
  --reuse-values \
  --set-string "global.domain=${PUBLIC_DOMAIN}"

# Locust can render one-off Jobs; avoid carrying old loadJob values into routine deploys.
helm upgrade --install namemaster-locust "${ROOT_DIR}/apps/locust/chart" \
  --namespace loadtest \
  --create-namespace
