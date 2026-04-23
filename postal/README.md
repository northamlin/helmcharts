# Postal Helm Chart

Full-featured open-source mail server for sending, receiving and processing email. Postal provides SMTP, HTTP API delivery, click and open tracking, bounce handling and a web-based management console.

Read more: https://postalapp.net

- **Chart version**: 0.1.0
- **App version**: 1.16.0

## Dependencies

| Component | Description |
|-----------|-------------|
| MySQL (PXC) | Primary database (`mysql-pxc.sql.svc`) |
| RabbitMQ | Message queue for worker communication |

## Key values

| Value | Default | Description |
|-------|---------|-------------|
| `db.host` | `mysql-pxc.sql.svc` | MySQL host |
| `db.name` | `postal` | Database name |

## DNS requirements

| Record | Value |
|--------|-------|
| MX | `mx.elino.se` |
| SMTP | `postal.elino.se` |

## Deploy

```bash
helm upgrade --install postal ./postal \
  --namespace default
```
