# Moodle Helm Chart

Open-source Learning Management System used by millions of educators and students worldwide. Moodle provides a flexible platform for creating online courses, quizzes, assignments and collaborative activities.

Read more: https://moodle.org

- **Chart version**: 0.1.1
- **App version**: 1.0

## Dependencies

| Component | Description |
|-----------|-------------|
| MySQL | Primary database (cluster or single instance) |
| Redis | Session cache |

## Key values

| Value | Default | Description |
|-------|---------|-------------|
| `url` | `moodle.server.robots.beer` | Ingress hostname |
| `storageClass` | `hcloud-volumes` | PVC storage class |
| `mysql.cluster` | `true` | Use MySQL PXC cluster |

## Deploy

```bash
helm upgrade --install moodle ./moodle \
  --namespace default \
  --set url=moodle.server.robots.beer
```
