#!/usr/bin/env sh
set -eu

# Usage:
#   export DOCKERHUB_USERNAME="daniil3680"
#   export DOCKERHUB_TOKEN="paste-dockerhub-access-token-here"
#   NAMESPACE=namemaster scripts/create-dockerhub-pull-secret.example.sh
#   NAMESPACE=monitoring scripts/create-dockerhub-pull-secret.example.sh
#
# This script does not store the token in git. It creates/updates the
# imagePullSecret used by the Deployment and Helm chart.

: "${DOCKERHUB_USERNAME:?Set DOCKERHUB_USERNAME}"
: "${DOCKERHUB_TOKEN:?Set DOCKERHUB_TOKEN}"

NAMESPACE="${NAMESPACE:-monitoring}"
SECRET_NAME="${SECRET_NAME:-dockerhub-pull-secret}"
DOCKERHUB_EMAIL="${DOCKERHUB_EMAIL:-dockerhub@example.invalid}"

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret docker-registry "${SECRET_NAME}" \
  --namespace "${NAMESPACE}" \
  --docker-server="https://index.docker.io/v1/" \
  --docker-username="${DOCKERHUB_USERNAME}" \
  --docker-password="${DOCKERHUB_TOKEN}" \
  --docker-email="${DOCKERHUB_EMAIL}" \
  --dry-run=client \
  -o yaml | kubectl apply -f -

kubectl get secret "${SECRET_NAME}" --namespace "${NAMESPACE}"
