# Kubernetes Monitor

Small FastAPI application for monitoring a Kubernetes cluster and the `namemaster` pods. It reads current resource metrics from `metrics-server`, cluster objects from the Core API, keeps a short in-memory history, serves a plain HTML page, and exposes Prometheus metrics at `/metrics`.

The application uses one background collector. Browser clients receive the latest shared snapshot through Server-Sent Events at `/api/events`; they do not trigger their own Kubernetes API polling loops.

## Endpoints

- `GET /` - HTML dashboard.
- `GET /healthz` - process health.
- `GET /readyz` - Kubernetes API readiness check.
- `GET /api/snapshot` - current JSON snapshot.
- `GET /api/events` - SSE stream with snapshot updates.
- `GET /metrics` - Prometheus metrics.

## Environment Variables

- `METRICS_POLL_INTERVAL` - polling interval in seconds, default `5`.
- `MONITORED_POD_SELECTOR` - optional label selector, for example `app.kubernetes.io/name=namemaster`. If unset, pod names containing `namemaster` are used.
- `LOG_LEVEL` - Python logging level, default `INFO`.

## Docker Hub Pull Secret

The image is private: `daniil3680/monitoring:latest`.

Create the pull secret from shell environment variables, without committing the token:

```bash
cd apps/monitoring
export DOCKERHUB_USERNAME="daniil3680"
export DOCKERHUB_TOKEN="paste-dockerhub-access-token-here"
NAMESPACE=monitoring ../../scripts/create-dockerhub-pull-secret.example.sh
```

By default this creates `dockerhub-pull-secret` in namespace `monitoring`.

## Local Run

Use a local kubeconfig with access to the target cluster:

```bash
cd apps/monitoring
python3 -m venv .venv
. .venv/bin/activate
make install
make run
```

Open `http://127.0.0.1:8080/`.

The app first tries `load_incluster_config()`. Outside a cluster it falls back to `load_kube_config()`.

## Docker

Build locally:

```bash
cd apps/monitoring
make docker-build
```

Or choose a repository tag:

```bash
docker build -t daniil3680/monitoring:latest .
```

Run with your local kubeconfig mounted read-only:

```bash
docker run --rm -p 8080:8080 \
  -v "$HOME/.kube:/srv/app/.kube:ro" \
  -e KUBECONFIG=/srv/app/.kube/config \
  daniil3680/monitoring:latest
```

## Kubernetes Deploy

The manifests use these project defaults:

- image: `daniil3680/monitoring:latest`
- imagePullSecret: `dockerhub-pull-secret`
- Gateway parentRef: `public` in namespace `nginx-gateway`
- HTTP to HTTPS redirect: enabled on `monitoring-http`
- Certificate namespace: `nginx-gateway`; owned by `deploy/helm/platform/gateway` in the Helm flow
- ClusterIssuer: `letsencrypt-prod`

Create the Docker Hub pull secret before applying the Deployment.

Deploy core resources:

```bash
kubectl apply -f docs/examples/monitoring-kubernetes/namespace.yaml
kubectl apply -f docs/examples/monitoring-kubernetes/service-account.yaml
kubectl apply -f docs/examples/monitoring-kubernetes/rbac.yaml
kubectl apply -f docs/examples/monitoring-kubernetes/deployment.yaml
kubectl apply -f docs/examples/monitoring-kubernetes/service.yaml
kubectl apply -f docs/examples/monitoring-kubernetes/certificate.yaml
kubectl apply -f docs/examples/monitoring-kubernetes/httproute.yaml
```

`docs/examples/monitoring-kubernetes/servicemonitor.yaml` is optional and requires the Prometheus Operator CRD:

```bash
kubectl apply -f docs/examples/monitoring-kubernetes/servicemonitor.yaml
```

## Helm Deploy

The Helm chart is in `apps/monitoring/chart`.

Create the Docker Hub pull secret first:

```bash
cd apps/monitoring
export DOCKERHUB_USERNAME="daniil3680"
export DOCKERHUB_TOKEN="paste-dockerhub-access-token-here"
NAMESPACE=monitoring ../../scripts/create-dockerhub-pull-secret.example.sh
```

Render manifests locally:

```bash
helm template kubernetes-monitor ./chart --namespace monitoring
```

Install or upgrade:

```bash
helm upgrade --install kubernetes-monitor ./chart \
  --namespace monitoring \
  --create-namespace
```

Enable the optional `ServiceMonitor` only when the CRD exists:

```bash
helm upgrade --install kubernetes-monitor ./chart \
  --namespace monitoring \
  --create-namespace \
  --set serviceMonitor.enabled=true
```

## metrics-server Checks

```bash
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl top nodes
kubectl top pods -A
```

The app reads:

- `/apis/metrics.k8s.io/v1beta1/nodes`
- `/apis/metrics.k8s.io/v1beta1/pods`

If metrics are missing for new pods or nodes, the dashboard keeps running and shows partial data.

## Gateway API

The app is published with `HTTPRoute`, not the old Ingress API.

Check the route:

```bash
kubectl get httproute -n monitoring
kubectl describe httproute kubernetes-monitor -n monitoring
```

If the shared Gateway only allows routes from its own namespace, update `Gateway.spec.listeners[].allowedRoutes.namespaces` to allow the `monitoring` namespace. See `docs/examples/monitoring-kubernetes/gateway-listener-example.yaml` for a listener fragment.

## cert-manager and TLS

`deploy/helm/platform/gateway` creates the TLS secret in the Helm flow:

```text
monitoring-tls
```

For Gateway API TLS termination, keep the `Certificate` and its resulting Secret in the same namespace as the Gateway. The shared Gateway in `nginx-gateway` references that Secret:

```yaml
listeners:
  - name: monitoring-https
    hostname: monitoring.<domain>
    port: 443
    protocol: HTTPS
    tls:
      mode: Terminate
      certificateRefs:
        - kind: Secret
          name: monitoring-tls
```

Do not put the TLS secret in `HTTPRoute`; `HTTPRoute` only routes traffic.

## DNS

Create a DNS record for:

```text
monitoring.<domain>
```

Point it at the external address of the shared Gateway or load balancer used by NGINX Gateway Fabric.

## RBAC Checks

```bash
kubectl auth can-i list nodes \
  --as=system:serviceaccount:monitoring:kubernetes-monitor

kubectl auth can-i list nodes.metrics.k8s.io \
  --as=system:serviceaccount:monitoring:kubernetes-monitor
```

The app does not use `cluster-admin`.

## Prometheus Metrics

Check manually:

```bash
kubectl port-forward -n monitoring service/kubernetes-monitor 8080:80
curl http://127.0.0.1:8080/metrics
```

Exported metrics include:

- `kubernetes_monitor_node_count`
- `kubernetes_monitor_ready_node_count`
- `kubernetes_monitor_running_pod_count`
- `kubernetes_monitor_pending_pod_count`
- `kubernetes_monitor_cluster_cpu_usage_cores`
- `kubernetes_monitor_cluster_memory_usage_bytes`
- `kubernetes_monitor_namemaster_cpu_usage_cores`
- `kubernetes_monitor_namemaster_memory_usage_bytes`
- `kubernetes_monitor_collection_errors_total`
- `kubernetes_monitor_node_cpu_usage_cores{node="..."}`
- `kubernetes_monitor_node_memory_usage_bytes{node="..."}`
- `kubernetes_monitor_node_ready{node="..."}`

## Troubleshooting

- `/readyz` returns `503`: kubeconfig is missing locally, the ServiceAccount token is unavailable in-cluster, or RBAC blocks API access.
- Pod has `ImagePullBackOff`: verify `dockerhub-pull-secret` exists in namespace `monitoring` and the Docker Hub token has pull access.
- Dashboard shows metrics errors: verify `metrics-server` with `kubectl top nodes` and `kubectl top pods -A`.
- `namemaster` pods are empty: verify labels with `kubectl get pods -A -l app.kubernetes.io/name=namemaster` and adjust `MONITORED_POD_SELECTOR` if your release uses different labels.
- `HTTPRoute` is not accepted: verify the `parentRefs` Gateway name/namespace and Gateway `allowedRoutes`.
- HTTPS is not ready: check `kubectl describe certificate -n nginx-gateway monitoring` and verify the Gateway listener references `monitoring-tls`.
