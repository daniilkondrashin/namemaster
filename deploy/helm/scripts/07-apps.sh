#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PUBLIC_DOMAIN="${PUBLIC_DOMAIN:-opsbox.org}"
POSTGRESQL_SECRET_NAME="${POSTGRESQL_SECRET_NAME:-postgresql}"
POSTGRESQL_SECRET_KEY="${POSTGRESQL_SECRET_KEY:-password}"

if ! kubectl get secret "${POSTGRESQL_SECRET_NAME}" --namespace namemaster >/dev/null 2>&1; then
  echo "Secret namemaster/${POSTGRESQL_SECRET_NAME} was not found. Run deploy/helm/scripts/05-data.sh before deploying namemaster." >&2
  exit 1
fi

helm upgrade --install namemaster "${ROOT_DIR}/apps/namemaster/chart" \
  --namespace namemaster \
  --create-namespace \
  --atomic \
  --timeout 10m \
  --reuse-values \
  --set-json 'imagePullSecrets=[]' \
  --set-string "postgresql.existingSecret.name=${POSTGRESQL_SECRET_NAME}" \
  --set-string "postgresql.existingSecret.passwordKey=${POSTGRESQL_SECRET_KEY}" \
  --set-string "global.domain=${PUBLIC_DOMAIN}"

helm upgrade --install kubernetes-monitor "${ROOT_DIR}/apps/monitoring/chart" \
  --namespace monitoring \
  --create-namespace \
  --atomic \
  --timeout 10m \
  --reuse-values \
  --set-string "global.domain=${PUBLIC_DOMAIN}"

# Locust can render one-off Jobs; avoid carrying old loadJob values into routine deploys.
helm upgrade --install namemaster-locust "${ROOT_DIR}/apps/locust/chart" \
  --namespace loadtest \
  --create-namespace \
  --atomic \
  --timeout 10m
