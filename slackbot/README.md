# Slackbot Helm Chart

Custom HRB Slack bot integration built on NATS messaging. Enables event-driven notifications and commands bridging internal cluster events with Slack channels.

- **Chart version**: 0.4.0
- **App version**: 1.16.0

## Dependencies

| Component | Description |
|-----------|-------------|
| NATS | Message broker (embedded via deployment) |

## Key values

| Value | Default | Description |
|-------|---------|-------------|
| `gitsha` | `latest` | Docker image tag |
| `slacktoken` | (required) | Slack bot OAuth token |

## Deploy

```bash
helm upgrade --install slackbot ./slackbot \
  --namespace default \
  --set slacktoken=<token> \
  --set gitsha=<sha>
```
