# healthchecks

Cron job and background task monitoring: every job pings a unique URL when it runs, and
Healthchecks alerts you (webhook, Slack, Telegram, ntfy, email, ...) when a ping is late.
Upstream: https://github.com/healthchecks/healthchecks (BSD-3-Clause).

- **Image**: `healthchecks/healthchecks:v5.0.3` (gunicorn + `sendalerts` + `sendreports` in one container)
- **Database**: PostgreSQL via CNPG (`<name>-<uuid>-pg`); the template's `DB_*` env is exactly what Healthchecks reads
- **Data volume**: none. Checks, pings, projects and users all live in Postgres.
- **Login**: open `https://<url>/accounts/login/`, email `admin@<url>`, password = the
  release's `dbpass`. The admin is also a Django superuser (`/admin/`). A "My First Check"
  project is created with it.
- **Ping URLs**: `https://<url>/ping/<uuid>` (no login, by design: the UUID is the secret).
- **Suggested tier**: `medium`. Two gunicorn workers plus the two background loops use
  about 270Mi at idle, inside `low`'s 512Mi limit but without much headroom.

Built on the `robots-service` skill baseline. The top block of `values.yaml` is set per
release by helmdeployer and must not be renamed.

## How the admin is created

The `create-admin` init container (same image, after `wait-for-db`) runs `migrate`, then a
`manage.py shell` snippet: if no user has the email `auth.username`, it creates one the way
sign-up does (with a default project), sets the password to `dbpass` and makes it superuser;
otherwise it only prints "exists". It is idempotent, and a password the customer changes in
the UI is kept across restarts. It also writes `SECRET_KEY` = sha256 of
`healthchecks-secret-key:<dbpass>` into an emptyDir (`SECRET_KEY_FILE`), so the key is
stable across ArgoCD syncs and never appears in a rendered manifest.

## Security notes

- Pinned: `REGISTRATION_OPEN=False` (sign-up answers 403), `DEBUG=False`,
  `SHELL_ENABLED=False` (the "run a shell command" integration), `APPRISE_ENABLED=False`,
  `REMOTE_USER_HEADER=""` (no header login), `USE_PAYMENTS=False`, no SMTP listener.
- More users: the admin invites them to a project (needs SMTP for the invite email), or
  creates them in `/admin/`.
- **Outbound fetching (SSRF)**: webhooks and every notification integration POST to URLs the
  user types in. `INTEGRATIONS_ALLOW_PRIVATE_IPS=False` is pinned, so private, loopback and
  link-local targets (including cluster Services) are refused. Public internet is reachable
  by design; there is no egress NetworkPolicy.
- No SMTP is configured, so email alerts and "email me a login link" do not work until the
  customer sets `EMAIL_HOST` etc. Password login works without it.
- `ALLOWED_HOSTS` is derived from `SITE_ROOT` (= the release URL only).
- Runs as `hc` (999), read-only root filesystem (`/tmp` is an emptyDir), all capabilities dropped.

## Values a human would change

| Value | Default | What it does |
|---|---|---|
| `resource` | `low` (suggest `medium`) | Size tier: `low`, `medium` or `high` |
| `app.tag` | `v5.0.3` | Upstream tag. Bump `appVersion` and `version` with it |
| `auth.username` | `admin@{{ .Values.url }}` | Admin email (password is always `dbpass`); only applied when the admin is first created |
| `app.env.GUNICORN_WORKERS` | `2` | Web workers |
| `app.env.SITE_NAME` | `Healthchecks` | Name in the UI and emails |
| `database.storage` | `10Gi` | Postgres disk (UpCloud floor is 10Gi) |

To enable email alerts, add `EMAIL_HOST`, `EMAIL_PORT`, `EMAIL_HOST_USER`, `DEFAULT_FROM_EMAIL`
to `app.env` (and the SMTP password through a Secret, not plain env).

## Render

```bash
helm template demo ./healthchecks --set uuid=ab12cd34,url=hc.eu-up.apps.robots.beer,dbpass=change-me
```
