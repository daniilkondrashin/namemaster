# namemaster-locust Helm chart

Internal Locust load generator for `namemaster`.

The default target is the Kubernetes Service DNS name:

```text
http://namemaster.namemaster.svc.cluster.local
```

This keeps load-test traffic inside the cluster and avoids the public
`namemaster.opsbox.org` path through Cloudflare and AWS public ingress.

## Install

```bash
helm upgrade --install namemaster-locust ./chart \
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
token to Locust:

```bash
TOKEN="$(openssl rand -hex 24)"

helm upgrade --install namemaster ../../namemaster/chart \
  --namespace namemaster \
  --set loadTest.enabled=true \
  --set loadTest.token="${TOKEN}"

helm upgrade --install namemaster-locust ./chart \
  --namespace loadtest \
  --set loadTest.mode=cpu \
  --set loadTest.token="${TOKEN}" \
  --set loadTest.cpuDurationMs=50
```

## Headless Run

```bash
helm upgrade --install namemaster-locust ./chart \
  --namespace loadtest \
  --create-namespace \
  --set loadJob.enabled=true \
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
helm upgrade --install namemaster-locust ./chart \
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
