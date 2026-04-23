# Mautic Helm Chart

Open-source marketing automation platform for email campaigns, lead management and CRM integration. Mautic lets you segment contacts, build drip campaigns and track engagement without vendor lock-in.

Read more: https://mautic.org

- **Chart version**: 0.1.1
- **App version**: 1.16.0

## Dependencies

| Component | Description |
|-----------|-------------|
| MySQL | Primary database |

## Key values

| Value | Default | Description |
|-------|---------|-------------|
| `url` | `mautic.server.robots.beer` | Ingress hostname |
| `admin.email` | `matte@elino.se` | Initial admin email |

## Deploy

```bash
helm upgrade --install mautic ./mautic \
  --namespace default \
  --set url=mautic.server.robots.beer
```
