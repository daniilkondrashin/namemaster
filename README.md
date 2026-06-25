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
    platform/karpenter/
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

## Docker Hub Images

The default `namemaster` image is public and does not need an image pull secret.
Create `dockerhub-pull-secret` only in namespaces that pull private images or
need authenticated Docker Hub pulls:

```bash
export DOCKERHUB_USERNAME="username"
export DOCKERHUB_TOKEN="paste-dockerhub-access-token-here"

NAMESPACE=monitoring scripts/create-dockerhub-pull-secret.example.sh
```

For a private `namemaster` image, create the secret in `namemaster` and set
`imagePullSecrets[0].name=dockerhub-pull-secret` when installing the chart.

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
deploy/helm/scripts/00-capacity.sh
deploy/helm/scripts/01-namespaces.sh
deploy/helm/scripts/02-crds.sh
deploy/helm/scripts/03-platform.sh
deploy/helm/scripts/04-storage.sh
deploy/helm/scripts/05-data.sh
deploy/helm/scripts/06-observability.sh
deploy/helm/scripts/07-apps.sh
```

The shared Gateway is owned by `deploy/helm/platform/gateway` and lives in the
`nginx-gateway` namespace. Application charts create only `HTTPRoute` resources.

`00-capacity.sh` installs Karpenter and applies the default `NodePool` and
`EC2NodeClass`. Run `terraform apply` in `infra/terraform/k8s` first because
the script reads the cluster name, endpoint, Karpenter controller IAM role,
Karpenter interruption queue, node IAM role, and private subnet AZs from
Terraform outputs.

`04-storage.sh` installs the AWS EBS CSI EKS addon after Karpenter can launch
EC2 nodes, then applies the `gp3` StorageClass used by PostgreSQL and
Prometheus PVCs.

The default `NodePool` creates on-demand Linux `amd64` nodes from non-burstable
`c`, `m`, and `r` instance families. It avoids `t*` instances so HPA/load-test
CPU metrics are not skewed by burst credits, limits total Karpenter capacity,
and consolidates empty or underutilized nodes after 5 minutes.

Production Terraform does not keep an EKS managed node group; EC2 worker nodes
are expected to be Karpenter-owned and labelled with `karpenter.sh/nodepool`.
For a brand-new empty cluster, Terraform creates a Fargate profile for the
Karpenter controller pods. `00-capacity.sh` installs Karpenter with IRSA on that
Fargate runtime, and the `NodePool` then creates the EC2 worker nodes.

Check node autoscaling:

```bash
kubectl get pods -n kube-system -l workload=karpenter,runtime=fargate \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.metadata.labels.eks\.amazonaws\.com/fargate-profile}{"\n"}{end}'
kubectl get nodepool,ec2nodeclass,nodeclaim
kubectl logs -n kube-system deploy/karpenter -f
kubectl get nodes -w
```

Render or install individual app charts:

```bash
helm template namemaster apps/namemaster/chart --namespace namemaster
helm template kubernetes-monitor apps/monitoring/chart --namespace monitoring
helm template namemaster-locust apps/locust/chart --namespace loadtest
```

## Delete Kubernetes Resources and Cluster

See [deploy/helm/README.md#delete-resources](deploy/helm/README.md#delete-resources)
for the in-cluster teardown order, then run `terraform destroy` in
`infra/terraform/k8s`.

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

The public EKS API endpoint is restricted by CIDR. Do not commit your personal
IP address to the repository; pass it directly when applying Terraform:

```bash
terraform apply \
  -var='cluster_endpoint_public_access_cidrs=["203.0.113.10/32"]'
```

Or derive the current public IP for a single shell session:

```bash
MY_IP="$(curl -fsS https://checkip.amazonaws.com | tr -d '\n')"
TF_VAR_cluster_endpoint_public_access_cidrs="[\"${MY_IP}/32\"]" terraform apply
```

The EKS cluster does not grant implicit cluster-admin access to the Terraform
creator. Terraform creates a dedicated admin role instead:

```bash
aws eks update-kubeconfig \
  --region "$(terraform output -raw region)" \
  --name "$(terraform output -raw cluster_name)" \
  --role-arn "$(terraform output -raw eks_admin_role_arn)"
```

The VPC intentionally uses a single NAT Gateway as a non-prod cost trade-off:
roughly $32/month instead of about $96/month for one NAT per AZ. This accepts
AZ-outage exposure for internet egress from private subnets. For production,
set `single_nat_gateway = false` and `one_nat_gateway_per_az = true` in
`infra/terraform/k8s/modules/network/main.tf`.

The old Terraform Helm stack was removed. Helm releases are now managed from
`deploy/helm`.
