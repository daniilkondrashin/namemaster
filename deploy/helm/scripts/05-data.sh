#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
POSTGRESQL_VERSION="${POSTGRESQL_VERSION:-18.7.8}"

helm upgrade --install postgresql oci://registry-1.docker.io/bitnamicharts/postgresql \
  --version "${POSTGRESQL_VERSION}" \
  --namespace namemaster \
  --create-namespace \
  --atomic \
  --timeout 10m \
  --cleanup-on-fail \
  -f "${ROOT_DIR}/deploy/helm/values/postgresql.yaml"
