# linkding

Self-hosted bookmark manager — minimal, fast, with tags, full-text search, a browser
extension and archived snapshots. Upstream: https://github.com/sissbruecker/linkding (MIT).

- **Image**: `sissbruecker/linkding:1.47.0`
- **Database**: PostgreSQL via CNPG (`<name>-<uuid>-pg`)
- **Data volume**: `/etc/linkding/data` (secret key, favicons, previews, assets)
- **Login**: user `admin`, password = the release's generated `dbpass`

Built on the `robots-service` skill baseline. The top block of `values.yaml` is set per
release by helmdeployer and must not be renamed.

## Values a human may change

| Value | Default | Description |
|---|---|---|
| `app.tag` | `1.47.0` | Upstream tag — bump `appVersion` and `version` with it |
| `app.env.LD_SUPERUSER_NAME` | `admin` | First-boot admin username |
| `app.startupFailureThreshold` | `60` | x5s allowed for first boot / migrations |
| `database.storage` | `10Gi` | Postgres disk (UpCloud floor is 10Gi) |

## Render

```bash
helm template demo ./linkding --set uuid=ab12cd34,url=links.eu-up.apps.robots.beer
```
