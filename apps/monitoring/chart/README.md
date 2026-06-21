# kubernetes-monitor Helm chart

Create the Docker Hub pull secret first:

```bash
cd apps/monitoring
export DOCKERHUB_USERNAME="daniil3680"
export DOCKERHUB_TOKEN="paste-dockerhub-access-token-here"
NAMESPACE=monitoring ../../scripts/create-dockerhub-pull-secret.example.sh
```

Install:

```bash
helm upgrade --install kubernetes-monitor ./chart \
  --namespace monitoring \
  --create-namespace
```

Render locally:

```bash
helm template kubernetes-monitor ./chart --namespace monitoring
```

Defaults:

- image: `daniil3680/monitoring:latest`
- imagePullSecret: `dockerhub-pull-secret`
- HTTPRoute parentRef: `public` in namespace `nginx-gateway`
- HTTP to HTTPS redirect: enabled on `monitoring-http`
- Certificate creation: disabled by default; owned by `deploy/helm/platform/gateway`
- ClusterIssuer: `letsencrypt-prod`

`ServiceMonitor` is disabled by default because it requires the Prometheus Operator CRD:

```bash
helm upgrade --install kubernetes-monitor ./chart \
  --namespace monitoring \
  --create-namespace \
  --set serviceMonitor.enabled=true
```
