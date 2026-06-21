#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

helm upgrade --install postgresql oci://registry-1.docker.io/bitnamicharts/postgresql \
  --namespace namemaster \
  --create-namespace \
  --timeout 15m \
  --atomic \
  --cleanup-on-fail \
  -f "${ROOT_DIR}/deploy/helm/values/postgresql.yaml"
