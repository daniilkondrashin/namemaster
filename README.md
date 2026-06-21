# Namemaster

Small Kubernetes playground with two application services:

- `apps/namemaster` - Flask application that stores submitted names in PostgreSQL.
- `apps/monitoring` - FastAPI dashboard for cluster and `namemaster` pod metrics.

![Namemaster screenshot](docs/images/screenshot.png)

## Project Layout

```text
apps/
  namemaster/
    src/
    tests/
    chart/
    Dockerfile
  monitoring/
    src/
    tests/
    chart/
    Dockerfile

deploy/
  helm/
    platform/gateway/
    manifests/
    scripts/
    values/

infra/
  terraform/
    backend/
    k8s/

docs/
  examples/
  images/

scripts/
```

## Local Namemaster

```bash
docker-compose -f docker-compose.yaml up --build
```

Run the namemaster tests:

```bash
docker-compose -f docker-compose.test.yaml up --exit-code-from web
```

## Private Docker Hub Images

Both application charts use `dockerhub-pull-secret` by default. Create it in each
namespace that pulls private images:

```bash
export DOCKERHUB_USERNAME="daniil3680"
export DOCKERHUB_TOKEN="paste-dockerhub-access-token-here"

NAMESPACE=namemaster scripts/create-dockerhub-pull-secret.example.sh
NAMESPACE=monitoring scripts/create-dockerhub-pull-secret.example.sh
```

## Namemaster Secret Key

The `namemaster` chart generates `namemaster-secretkey` on the first install and
keeps the existing value on later upgrades.

To manage it manually instead:

```bash
kubectl create secret generic namemaster-secret \
  --namespace namemaster \
  --from-literal=namemaster-secretkey="$(openssl rand -hex 32)"

helm upgrade --install namemaster apps/namemaster/chart \
  --namespace namemaster \
  --set namemaster.secretKey.existingSecret.name=namemaster-secret
```

## Kubernetes Deploy

Install platform add-ons and application charts with Helm:

```bash
deploy/helm/scripts/00-namespaces.sh
deploy/helm/scripts/01-crds.sh
deploy/helm/scripts/02-platform.sh
deploy/helm/scripts/03-data.sh
deploy/helm/scripts/04-observability.sh
deploy/helm/scripts/05-apps.sh
```

The shared Gateway is owned by `deploy/helm/platform/gateway` and lives in the
`nginx-gateway` namespace. Application charts create only `HTTPRoute` resources.

Render or install individual app charts:

```bash
helm template namemaster apps/namemaster/chart --namespace namemaster
helm template kubernetes-monitor apps/monitoring/chart --namespace monitoring
```

## Terraform

Terraform is limited to cloud infrastructure:

```bash
cd infra/terraform/backend
terraform init
terraform apply

cd ../k8s
terraform init -backend-config=backend.hcl -migrate-state
terraform apply
```

The old Terraform Helm stack was removed. Helm releases are now managed from
`deploy/helm`.
