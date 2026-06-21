# Helm Deployment

Kubernetes add-ons are installed directly with Helm. Terraform should only keep
the cloud infrastructure/EKS layer.

## Order

```bash
deploy/helm/scripts/00-namespaces.sh
deploy/helm/scripts/01-crds.sh
deploy/helm/scripts/02-platform.sh
deploy/helm/scripts/03-capacity.sh
deploy/helm/scripts/04-data.sh
deploy/helm/scripts/05-observability.sh
deploy/helm/scripts/06-apps.sh
```

`03-capacity.sh` installs Karpenter into `kube-system` and applies the default
`NodePool` and `EC2NodeClass` from `deploy/helm/platform/karpenter`. Terraform
must be applied first because this script reads Karpenter IAM and queue outputs
from `infra/terraform/k8s`.

`06-apps.sh` installs `namemaster`, the Kubernetes monitoring dashboard, and
the internal Locust load generator.

## Node Autoscaling

Terraform owns the AWS resources Karpenter needs: Pod Identity, controller IAM,
node IAM role, EKS access entry, interruption queue, and discovery tags on the
private subnets and node security group.

Helm owns the Kubernetes side:

- Karpenter controller chart in `kube-system`
- `EC2NodeClass/default`
- `NodePool/default`

The default NodePool starts with on-demand Linux `amd64` capacity and a small
cluster-wide limit. Use Locust to create pending pods and watch Karpenter add
nodes:

```bash
kubectl get nodepool,ec2nodeclass,nodeclaim
kubectl logs -n kube-system deploy/karpenter -f
kubectl get nodes -w
```

## Gateway

`deploy/helm/platform/gateway` owns the shared Gateway named `public` in the
`nginx-gateway` namespace. Application charts should create `HTTPRoute` resources
that attach to this Gateway instead of creating their own Gateway.

Current listeners:

- `namemaster-http` for `namemaster.opsbox.org:80`
- `namemaster-https` for `namemaster.opsbox.org:443`
- `monitoring-http` for `monitoring.opsbox.org:80`
- `monitoring-https` for `monitoring.opsbox.org:443`

TLS certificates are kept in the same namespace as the Gateway because Gateway
TLS termination references Kubernetes Secrets from the Gateway namespace.

Locust does not create a public route. Access its UI with:

```bash
kubectl port-forward -n loadtest service/namemaster-locust 8089:8089
```

The default load-test target is
`http://namemaster.namemaster.svc.cluster.local`, so generated traffic stays on
the cluster network.

## Migration From Terraform Helm Releases

The old Terraform Helm stack was removed. If that stack still has remote state,
remove or migrate the old `helm_release`, `null_resource`, and `local_file`
objects from Terraform state so Terraform does not try to manage Helm-installed
resources again.
