# WordPress Helm Chart

The world's most popular open-source CMS, powering over 43% of all websites. WordPress offers a rich plugin ecosystem and a familiar editor for building anything from simple blogs to full e-commerce sites.

Read more: https://wordpress.org

- **Chart version**: 0.8.0
- **App version**: 1.0

## Dependencies

| Component | Description |
|-----------|-------------|
| MySQL | Primary database (`wp_` table prefix) |
| Redis | Optional object cache |

## Key values

| Value | Default | Description |
|-------|---------|-------------|
| `url` | `wordpress-hosting.server.robots.beer` | Ingress hostname |
| `storageClass` | `standard` | PVC storage class |
| `redis.enabled` | `false` | Enable Redis object cache |

## Deploy

```bash
# Generic
helm upgrade --install wordpress ./wordpress \
  --namespace default \
  --set url=mysite.northamlin.com

# With Redis
helm upgrade --install wordpress ./wordpress \
  --namespace default \
  --set url=mysite.northamlin.com \
  --set redis.enabled=true
```
