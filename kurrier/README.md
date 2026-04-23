# Kurrier Helm Chart

Webmail frontend with integrated calendar and contacts synchronisation. Provides a browser-based interface for email, CalDAV calendars and CardDAV address books hosted on the same cluster.

- **Chart version**: 0.1.0
- **App version**: 1.1.11

## Dependencies

| Component | Description |
|-----------|-------------|
| PostgreSQL (CNPG) | Primary database |
| Redis | Session cache |
| Typesense | Search backend |
| Supabase | Auth and realtime |
| Postfix (internal) | SMTP relay (`postfix-internal.hrb.svc.cluster.local:25`) |

## Key values

| Value | Default | Description |
|-------|---------|-------------|
| `url` | `mail.server.robots.beer` | Ingress hostname |
| `storageClass` | `standard` | PVC storage class |
| `hosting.tags.host/id` | `hrb01` | Cluster identifier |

## Deploy

```bash
# Generic
helm upgrade --install kurrier ./kurrier --namespace hrb

# HRB cluster
helm upgrade --install kurrier ./kurrier \
  --namespace hrb \
  -f kurrier/hrb-cluster-values.yaml \
  --kubeconfig ~/.kube/confighrb
```
