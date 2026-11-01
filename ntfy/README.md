# ntfy

Send push notifications to your phone or desktop with a plain HTTP request: `curl -u admin:… -d "build done" https://<url>/ci`. Upstream: https://github.com/binwiederhier/ntfy (Apache-2.0).

- **Image**: `binwiederhier/ntfy:v2.36.0`
- **Login**: user `admin`, password = the release's `dbpass`. It is provisioned as a declarative user (`auth-users`) on every boot.
- **Locked down**: `auth-default-access: deny-all`, and sign-up is off. Nothing can be read or published without a login.
- **Data volume**: `/var/lib/ntfy` (message cache, user DB, attachments, generated `server.yml`).

Built on the `robots-service` skill baseline. The top block of `values.yaml` is set per
release by helmdeployer and must not be renamed.

## Values a human would change

| Value | Default | What it does |
|---|---|---|
| `resource` | `low` | Size tier: `low`, `medium` or `high` |
| `app.tag` | `v2.36.0` | Upstream tag. Bump `appVersion` and `version` with it |
| `auth.username` | `admin` | Login name (the password is always `dbpass`) |
| `storage` | `10Gi` | Data disk (UpCloud floor is 10Gi) |

## Render

```bash
helm template demo ./ntfy --set uuid=ab12cd34,url=ntfy.eu-up.apps.robots.beer,dbpass=change-me
```
