# Kubernetes manifests

Manifests for every component of the system. **Not deployed anywhere** — this is
the topology, validated against the Kubernetes schema.

## Components

| Manifest | Resource(s) | Role |
|---|---|---|
| `namespace.yaml` | Namespace `bravo` | isolates the app |
| `configmap.yaml` | ConfigMap | non-secret env (hosts, DB name, Redis URL, origins) |
| `secrets.example.yaml` | Secret (**template**) | placeholders only — real values come from the secrets manager |
| `postgres.yaml` | Deployment + PVC + Service | database (use RDS/StatefulSet in prod) |
| `redis.yaml` | Deployment + Service | cache + Sidekiq broker + ActionCable |
| `api.yaml` | Deployment (+ migrate initContainer) + Service | Rails API (`/up` probes), 2 replicas |
| `worker.yaml` | Deployment | Sidekiq jobs (risk, webhooks), 2 replicas |
| `dispatcher.yaml` | Deployment | outbox drain loop (`FOR UPDATE SKIP LOCKED`), 2 replicas |
| `frontend.yaml` | Deployment + Service | built React SPA (static) |
| `ingress.yaml` | Ingress | `app.bravo.example` → frontend, `api.bravo.example` → api (WS-friendly) |

## Scaling

`api`, `worker`, and `dispatcher` are all horizontally scalable — bump `replicas`.
Parallel dispatchers never double-claim outbox rows (`SKIP LOCKED`); jobs are
idempotent.

## Validate

```bash
make k8s-validate     # kubeconform schema check (no cluster needed)
# or, against a real cluster:
kubectl apply --dry-run=client -f k8s/
```

## Secrets

`secrets.example.yaml` contains only `REPLACE_ME` placeholders and is the only
secret file committed. In a real cluster, secrets are supplied by an
external-secrets operator / sealed-secrets / the cloud secrets manager — never
committed.
