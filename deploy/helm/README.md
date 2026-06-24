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

Default listeners:

- `namemaster-http` for `namemaster.<domain>:80`
- `namemaster-https` for `namemaster.<domain>:443`
- `monitoring-http` for `monitoring.<domain>:80`
- `monitoring-https` for `monitoring.<domain>:443`

The default domain is `opsbox.org`. To move the stack to your own domain, run
the platform and app scripts with the same value:

```bash
PUBLIC_DOMAIN=example.com deploy/helm/scripts/03-platform.sh
PUBLIC_DOMAIN=example.com deploy/helm/scripts/07-apps.sh
```

The same value can be passed manually with `--set-string global.domain=example.com`
to the `shared-gateway`, `namemaster`, and `kubernetes-monitor` chart releases.

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
observability, then gateway components and autoscaling. Run this before
`terraform destroy` so Kubernetes controllers can clean up AWS load balancers,
volumes, and Karpenter-managed nodes.

```bash
helm uninstall namemaster-locust --namespace loadtest --ignore-not-found
helm uninstall kubernetes-monitor --namespace monitoring --ignore-not-found
helm uninstall namemaster --namespace namemaster --ignore-not-found
helm uninstall postgresql --namespace namemaster --ignore-not-found

helm uninstall prometheus --namespace monitoring --ignore-not-found
helm uninstall metrics-server --namespace kube-system --ignore-not-found

helm uninstall shared-gateway --namespace nginx-gateway --ignore-not-found
kubectl wait \
  --for=delete service \
  --namespace nginx-gateway \
  --selector=gateway.networking.k8s.io/gateway-name=public \
  --timeout=10m || true
kubectl delete clusterissuer letsencrypt-prod --ignore-not-found
helm uninstall cert-manager --namespace cert-manager --ignore-not-found
helm uninstall ngf --namespace nginx-gateway --ignore-not-found

kubectl delete namespace \
  loadtest \
  monitoring \
  namemaster \
  cert-manager \
  nginx-gateway \
  --ignore-not-found
kubectl wait \
  --for=delete namespace \
  loadtest \
  monitoring \
  namemaster \
  cert-manager \
  nginx-gateway \
  --timeout=10m || true

kubectl delete storageclass gp3 --ignore-not-found
aws eks delete-addon \
  --cluster-name "$(terraform -chdir=infra/terraform/k8s output -raw cluster_name)" \
  --addon-name aws-ebs-csi-driver || true

kubectl delete nodepool default --ignore-not-found
kubectl delete nodeclaim --all --ignore-not-found
kubectl wait --for=delete nodeclaim --all --timeout=10m || true
kubectl wait --for=delete node --selector=karpenter.sh/nodepool=default --timeout=10m || true
helm uninstall karpenter --namespace kube-system --ignore-not-found
```

Delete project namespaces while the EBS CSI addon and Karpenter nodes are still
running, so Kubernetes can detach and delete dynamically provisioned EBS volumes.
If a namespace stays in `Terminating`, inspect its finalizers before continuing.

```bash
kubectl get namespace
kubectl get pv,pvc -A
```

Check for leftovers before destroying the EKS cluster:

```bash
kubectl get svc -A --field-selector spec.type=LoadBalancer
kubectl get pv,pvc -A
kubectl get nodeclaim
```

If `terraform destroy` fails with `DependencyViolation` while deleting a subnet
or the EKS node security group, look for AWS-owned Kubernetes ENIs that
Terraform does not track:

```bash
REGION="$(terraform -chdir=infra/terraform/k8s output -raw region)"
CLUSTER_NAME="$(terraform -chdir=infra/terraform/k8s output -raw cluster_name)"

aws ec2 describe-network-interfaces \
  --region "${REGION}" \
  --filters "Name=tag:cluster.k8s.amazonaws.com/name,Values=${CLUSTER_NAME}" \
  --query 'NetworkInterfaces[].{Id:NetworkInterfaceId,Status:Status,Description:Description,SubnetId:SubnetId,Groups:Groups[].GroupId,Instance:Attachment.InstanceId,Owner:TagSet[?Key==`eks:eni:owner`]|[0].Value,NodeInstance:TagSet[?Key==`node.k8s.amazonaws.com/instance_id`]|[0].Value}' \
  --output table
```

For a specific Terraform error, inspect the blocking subnet or security group
directly:

```bash
aws ec2 describe-network-interfaces \
  --region "${REGION}" \
  --filters "Name=subnet-id,Values=<subnet-id-from-error>" \
  --output table

aws ec2 describe-network-interfaces \
  --region "${REGION}" \
  --filters "Name=group-id,Values=<sg-id-from-error>" \
  --output table
```

An orphaned AWS VPC CNI ENI usually has description `aws-K8S-<instance-id>`,
tag `eks:eni:owner=amazon-vpc-cni`, status `available`, no attachment, and a
`node.k8s.amazonaws.com/instance_id` tag whose EC2 instance no longer exists.
After confirming the cluster and node instance are gone, delete that ENI and
rerun `terraform destroy`:

```bash
aws ec2 delete-network-interface \
  --region "${REGION}" \
  --network-interface-id <orphan-eni-id>
```

## Migration From Terraform Helm Releases

The old Terraform Helm stack was removed. If that stack still has remote state,
remove or migrate the old `helm_release`, `null_resource`, and `local_file`
objects from Terraform state so Terraform does not try to manage Helm-installed
resources again.
