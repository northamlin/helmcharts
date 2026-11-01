# mailpit

Email and SMTP testing tool with a web UI and REST API. Catches mail from your apps so you can inspect it without anything reaching a real inbox. Upstream: https://github.com/axllent/mailpit (MIT).

- **Image**: `axllent/mailpit:v1.33.0`
- **Login**: user `admin`, password = the release's `dbpass`. It protects the web UI, the API and the send API (`MP_UI_AUTH`).
- **SMTP** (1025) listens inside the pod network only and also requires the admin login. It is not reachable from outside the cluster yet: that needs a Traefik TCP entrypoint.
- **Data volume**: `/data` (SQLite message store, capped at 1000 messages).

Built on the `robots-service` skill baseline. The top block of `values.yaml` is set per
release by helmdeployer and must not be renamed.

## Values a human would change

| Value | Default | What it does |
|---|---|---|
| `resource` | `low` | Size tier: `low`, `medium` or `high` |
| `app.tag` | `v1.33.0` | Upstream tag. Bump `appVersion` and `version` with it |
| `auth.username` | `admin` | Login name (the password is always `dbpass`) |
| `storage` | `10Gi` | Data disk (UpCloud floor is 10Gi) |

## Render

```bash
helm template demo ./mailpit --set uuid=ab12cd34,url=mailpit.eu-up.apps.robots.beer,dbpass=change-me
```
