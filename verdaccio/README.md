# verdaccio

Private npm registry that also caches npmjs.org. Publish internal packages and speed up installs. Upstream: https://github.com/verdaccio/verdaccio (MIT).

- **Image**: `verdaccio/verdaccio:7.0.2`
- **Login**: user `admin`, password = the release's `dbpass`. Run `npm login --registry https://<url> --auth-type=legacy`.
- **Private**: every read, publish and unpublish needs a login, and nobody else can register (`max_users: 1`).
- **Data volume**: `/verdaccio/storage` (packages, cache, htpasswd). The config is a ConfigMap at `/verdaccio/conf/config.yaml`.

Built on the `robots-service` skill baseline. The top block of `values.yaml` is set per
release by helmdeployer and must not be renamed.

## Values a human would change

| Value | Default | What it does |
|---|---|---|
| `resource` | `low` | Size tier: `low`, `medium` or `high` |
| `app.tag` | `7.0.2` | Upstream tag. Bump `appVersion` and `version` with it |
| `auth.username` | `admin` | Login name (the password is always `dbpass`) |
| `storage` | `10Gi` | Data disk (UpCloud floor is 10Gi) |

## Render

```bash
helm template demo ./verdaccio --set uuid=ab12cd34,url=verdaccio.eu-up.apps.robots.beer,dbpass=change-me
```
