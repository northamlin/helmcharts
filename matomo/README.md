# Matomo Helm Chart

Open-source web analytics platform and a GDPR-compliant alternative to Google Analytics. Matomo gives you full ownership of your visitor data with no data sampling and over 100 built-in reports.

Read more: https://matomo.org

- **Chart version**: 0.1.2
- **App version**: 1.16.0

## Dependencies

| Component | Description |
|-----------|-------------|
| MySQL | Primary database |

## Key values

| Value | Default | Description |
|-------|---------|-------------|
| `url` | `matomo-test.server.robots.beer` | Ingress hostname |

## Deploy

```bash
helm upgrade --install matomo ./matomo \
  --namespace default \
  --set url=matomo.server.robots.beer
```
