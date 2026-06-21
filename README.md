# Namemaster

Small Kubernetes playground with two application services and one load-test tool:

- `apps/namemaster` - Flask application that stores submitted names in PostgreSQL.
- `apps/monitoring` - FastAPI dashboard for cluster and `namemaster` pod metrics.
- `apps/locust` - internal Locust load generator for testing `namemaster` HPA.

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
  locust/
    chart/

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
export DOCKERHUB_USERNAME="username"
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
helm template namemaster-locust apps/locust/chart --namespace loadtest
```

## Internal Load Test

Locust is installed into the `loadtest` namespace and targets the internal
Kubernetes Service DNS name by default:

```text
http://namemaster.namemaster.svc.cluster.local
```

That keeps generated traffic inside the cluster instead of sending it through
Cloudflare or the public AWS ingress.

Open the Locust UI locally:

```bash
kubectl port-forward -n loadtest service/namemaster-locust 8089:8089
```

Then open `http://127.0.0.1:8089/` and start a test against the prefilled host.

Watch HPA and pod scaling:

```bash
kubectl get hpa -n namemaster -w
kubectl get pods -n namemaster -w
kubectl top pods -n namemaster
```

For a more predictable CPU-based HPA test, enable the protected load-test
endpoint in `namemaster` and pass the same token to Locust:

```bash
TOKEN="$(openssl rand -hex 24)"

helm upgrade --install namemaster apps/namemaster/chart \
  --namespace namemaster \
  --set loadTest.enabled=true \
  --set loadTest.token="${TOKEN}"

helm upgrade --install namemaster-locust apps/locust/chart \
  --namespace loadtest \
  --set loadTest.mode=cpu \
  --set loadTest.token="${TOKEN}" \
  --set loadTest.cpuDurationMs=50
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
