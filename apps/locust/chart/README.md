# namemaster-locust Helm chart

Internal Locust load generator for `namemaster`.

The default target is the Kubernetes Service DNS name:

```text
http://namemaster.namemaster.svc.cluster.local
```

This keeps load-test traffic inside the cluster and avoids the public
ingress path through Cloudflare and AWS public ingress.

## Install

```bash
helm upgrade --install namemaster-locust apps/locust/chart \
  --namespace loadtest \
  --create-namespace
```

## Open Locust UI

```bash
kubectl port-forward -n loadtest service/namemaster-locust 8089:8089
```

Open `http://127.0.0.1:8089/`.

Start with a moderate test, for example:

- users: `100`
- spawn rate: `10`
- host: `http://namemaster.namemaster.svc.cluster.local`

By default Locust submits the normal HTML form. For more predictable HPA tests,
enable the protected CPU endpoint in the `namemaster` chart and pass the same
token to Locust. The endpoint returns `404` when the token is missing or does
not match, so keep both namespaces on the same Secret and restart pods after
rotating it:

```bash
TOKEN="$(openssl rand -hex 24)"

kubectl create namespace namemaster --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace loadtest --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic namemaster-load-test \
  --namespace namemaster \
  --from-literal=load-test-token="${TOKEN}" \
  --dry-run=client \
  -o yaml | kubectl apply -f -

kubectl create secret generic namemaster-load-test \
  --namespace loadtest \
  --from-literal=load-test-token="${TOKEN}" \
  --dry-run=client \
  -o yaml | kubectl apply -f -

helm upgrade --install namemaster apps/namemaster/chart \
  --namespace namemaster \
  --reuse-values \
  --set loadTest.enabled=true \
  --set loadTest.existingSecret.name=namemaster-load-test

helm upgrade --install namemaster-locust apps/locust/chart \
  --namespace loadtest \
  --set loadTest.mode=cpu \
  --set loadTest.existingSecret.name=namemaster-load-test \
  --set loadTest.cpuDurationMs=50

kubectl rollout restart deployment/namemaster -n namemaster
kubectl rollout restart deployment/namemaster-locust -n loadtest
kubectl rollout status deployment/namemaster -n namemaster
kubectl rollout status deployment/namemaster-locust -n loadtest
```

Check the CPU endpoint from inside the cluster:

```bash
kubectl run namemaster-load-cpu-check \
  --namespace loadtest \
  --rm \
  -i \
  --restart=Never \
  --image=curlimages/curl \
  -- curl -fsS \
  -X POST \
  "http://namemaster.namemaster.svc.cluster.local/load/cpu?duration_ms=50" \
  -H "X-Load-Test-Token: ${TOKEN}"
```

## Headless Run

```bash
helm upgrade --install namemaster-locust apps/locust/chart \
  --namespace loadtest \
  --create-namespace \
  --set loadJob.enabled=true \
  --set loadJob.runId="$(date +%Y%m%d-%H%M%S)" \
  --set loadJob.users=300 \
  --set loadJob.spawnRate=30 \
  --set loadJob.runTime=10m
```

Watch the one-off load job:

```bash
kubectl get jobs,pods -n loadtest
kubectl logs -n loadtest -l app.kubernetes.io/component=load-job -f
```

Disable or stop the job:

```bash
helm upgrade --install namemaster-locust apps/locust/chart \
  --namespace loadtest \
  --set loadJob.enabled=false
```

## Watch Scaling

```bash
kubectl get hpa -n namemaster -w
kubectl get pods -n namemaster -w
kubectl top pods -n namemaster
kubectl top nodes
```
