# Radicale Helm Chart

Lightweight open-source CalDAV and CardDAV server. Radicale lets you self-host your calendars, to-do lists and contacts with minimal configuration and a tiny resource footprint.

Read more: https://radicale.org

Helm chart uses image: [tomsquest/docker-radicale](https://github.com/tomsquest/docker-radicale)

- **Chart version**: 0.1.0
- **App version**: latest

## Deploy

```bash
helm upgrade --install radicale ./radicale \
  --namespace <namespace> \
  -f radicale/hrb-cluster-values.yaml \
  --kubeconfig ~/.kube/confighrb
```

## Key values

| Value | Default | Description |
|-------|---------|-------------|
| `image` | `tomsquest/docker-radicale` | Container image |
| `url` | `radicale.example.com` | Ingress hostname |
| `storage` | `1Gi` | PVC size |
| `storageClass` | `standard` | Storage class |
| `auth.type` | `imap` | Auth type (`imap`, `none`, `htpasswd`) |
| `auth.imapHost` | `postfix-internal` | IMAP server hostname |
| `auth.imapSecurity` | `none` | IMAP connection security (`none`, `tls`, `starttls`) |

## HRB cluster

```bash
helm upgrade --install radicale ./radicale \
  --namespace hrb \
  -f radicale/hrb-cluster-values.yaml \
  --kubeconfig ~/.kube/confighrb

# Check status
kubectl get pods -n hrb --kubeconfig ~/.kube/confighrb -l app=radicale-hrb01
kubectl logs -n hrb --kubeconfig ~/.kube/confighrb -l app=radicale-hrb01
```
