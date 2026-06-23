# Helm Deployment

Kubernetes add-ons are installed directly with Helm. Terraform should only keep
the cloud infrastructure/EKS layer.

## Order

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

`00-capacity.sh` installs Karpenter into `kube-system` and applies the default
`NodePool` and `EC2NodeClass` from `deploy/helm/platform/karpenter`. Terraform
must be applied first because this script reads Karpenter IAM and queue outputs
from `infra/terraform/k8s`.

`04-storage.sh` installs the AWS EBS CSI EKS addon after Karpenter can launch EC2
nodes, then applies the `gp3` StorageClass used by stateful workloads.

`07-apps.sh` installs `namemaster`, the Kubernetes monitoring dashboard, and
the internal Locust load generator.

## Node Autoscaling

Terraform owns the AWS resources Karpenter needs: the Fargate profile used to
run the Karpenter controller during first start, controller IAM through IRSA,
node IAM role, EKS access entry, interruption queue, and discovery tags on the
private subnets and node security group. Terraform also creates the IAM role
used by the EBS CSI controller, but the EBS CSI addon is installed by
`04-storage.sh` after Karpenter-managed EC2 nodes are available.

Helm owns the Kubernetes side:

- Karpenter controller chart in `kube-system`
- `EC2NodeClass/default`
- `NodePool/default`

The default NodePool starts on-demand Linux `amd64` capacity from non-burstable
`c`, `m`, and `r` instance families. The zone list is rendered from Terraform's
private subnet AZs, so Karpenter only launches in AZs that have discovery-tagged
subnets. It consolidates empty or underutilized Karpenter-owned nodes after 5
minutes, with weekday business-hour disruption budgets for underutilized nodes.
Spot capacity is intentionally disabled for now. Use Locust to create pending
pods and watch Karpenter add nodes:

```bash
kubectl get pods -n kube-system -l workload=karpenter,runtime=fargate \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.metadata.labels.eks\.amazonaws\.com/fargate-profile}{"\n"}{end}'
kubectl get nodepool,ec2nodeclass,nodeclaim
kubectl logs -n kube-system deploy/karpenter -f
kubectl get nodes -w
```

Production Terraform does not keep an EKS managed node group. EC2 worker nodes
should be Karpenter-owned and labelled with `karpenter.sh/nodepool`; nodes
without that label are outside Karpenter's consolidation and replacement logic.
For a brand-new empty cluster, `terraform apply` creates the Fargate profile
that matches the Karpenter controller pods. `00-capacity.sh` installs Karpenter
with IRSA on that Fargate runtime, then applies the `EC2NodeClass` and
`NodePool` so application capacity is created as Karpenter-managed EC2 nodes.

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

## Delete Resources

Remove resources in reverse dependency order: applications first, then data and
observability, then autoscaling and gateway components. Run this before
`terraform destroy` so Kubernetes controllers can clean up AWS load balancers,
volumes, and Karpenter-managed nodes.

```bash
helm uninstall namemaster-locust --namespace loadtest --ignore-not-found
helm uninstall kubernetes-monitor --namespace monitoring --ignore-not-found
helm uninstall namemaster --namespace namemaster --ignore-not-found
helm uninstall postgresql --namespace namemaster --ignore-not-found

helm uninstall prometheus --namespace monitoring --ignore-not-found
helm uninstall metrics-server --namespace kube-system --ignore-not-found

kubectl delete storageclass gp3 --ignore-not-found
aws eks delete-addon \
  --cluster-name "$(terraform -chdir=infra/terraform/k8s output -raw cluster_name)" \
  --addon-name aws-ebs-csi-driver || true

kubectl delete nodepool default --ignore-not-found
kubectl delete nodeclaim --all --ignore-not-found
kubectl wait --for=delete nodeclaim --all --timeout=10m || true
helm uninstall karpenter --namespace kube-system --ignore-not-found

helm uninstall shared-gateway --namespace nginx-gateway --ignore-not-found
kubectl delete clusterissuer letsencrypt-prod --ignore-not-found
helm uninstall cert-manager --namespace cert-manager --ignore-not-found
helm uninstall ngf --namespace nginx-gateway --ignore-not-found
```

Delete project namespaces only after the Helm releases are gone:

```bash
kubectl delete namespace \
  loadtest \
  monitoring \
  namemaster \
  cert-manager \
  nginx-gateway \
  gitlab-runner \
  --ignore-not-found
```

Check for leftovers before destroying the EKS cluster:

```bash
kubectl get svc -A --field-selector spec.type=LoadBalancer
kubectl get pv,pvc -A
kubectl get nodeclaim
```

## Migration From Terraform Helm Releases

The old Terraform Helm stack was removed. If that stack still has remote state,
remove or migrate the old `helm_release`, `null_resource`, and `local_file`
objects from Terraform state so Terraform does not try to manage Helm-installed
resources again.
