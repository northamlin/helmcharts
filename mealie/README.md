# mealie

Mealie: a self-hosted recipe manager and meal planner. Import recipes from a URL, plan the
week, and build shopping lists for a household. Upstream: https://github.com/mealie-recipes/mealie (AGPL-3.0, run unmodified).

- **Image**: `ghcr.io/mealie-recipes/mealie:v3.30.0`, runs as uid 911 with every capability dropped.
- **Database**: CloudNativePG Postgres (recipes, users, meal plans).
- **Data volume**: `/app/data` (recipe images, backups, and the generated `SECRET` / `SESSION_SECRET` files).
- **Login**: email `admin@<url>`, password = the release's `dbpass`. Sign-up is disabled.
- **Tier**: defaults to `medium`.

## First boot: the default admin is never reachable

A fresh Mealie seeds the admin `changeme@example.com` / `MyPassword`. Everyone knows that
login, and no env var changes it. The chart handles it like this:

- `bootstrap.py` (a configFile) runs next to the server and works on localhost. It logs in
  with the release password, or with the default password if that fails. It changes the
  password to `dbpass` first and the email to `admin@<url>` second.
- Startup and readiness use an exec probe (liveness is tcp). It needs
  `/api/app/about/startup-info` to say `"isFirstLogin":false`, which means no user with the
  default email exists. Traefik routes only to Ready pods, so the default login never works
  through the ingress.
- A restart between the two steps leaves the default email with the new password. The
  probe stays red. On the next start the script's first login (release password) works and it
  finishes the job. Tested by forcing that state and running `docker restart`.
- On every later boot the script sees `isFirstLogin:false` and exits without logging in.

## Security notes

- `SECURITY_MAX_LOGIN_ATTEMPTS=100`, `SECURITY_USER_LOCKOUT_TIME=1`. Mealie's default (5 failures,
  then locked for 24h) also refuses the right password, so five anonymous POSTs would lock the
  customer out for a day. The release password is 144 random bits, so a lockout adds nothing
  against guessing it. 100 failures and a 1h lock still caps guessing at about 100 tries an hour
  if the customer later picks a weak password.
- Pinned off: `ALLOW_SIGNUP`, OIDC, LDAP and reverse-proxy header auth.
- **Outbound fetches (SSRF)**: recipe import by URL, webhooks and recipe actions fetch URLs a user
  types in. Mealie's `safehttp` transport refuses private, loopback and link-local targets, as
  tested with `127.0.0.1` and `169.254.169.254`. `HTTP_ALLOW_LIST` is pinned empty. There is no
  egress NetworkPolicy, so public URLs are reachable.
- No SMTP, so password-reset and invite emails don't work. The admin creates users and invite links in the UI.

## Values a human would change

| Value | Default | What it does |
|---|---|---|
| `resource` | `medium` | Size tier: `low`, `medium` or `high` |
| `app.tag` | `v3.30.0` | Upstream tag. Bump `appVersion` and `version` with it |
| `auth.username` | `admin@{{ .Values.url }}` | Admin email (the password is always `dbpass`) |
| `app.env.SECURITY_MAX_LOGIN_ATTEMPTS` | `100` | Failed logins before the account locks |
| `storage` / `database.storage` | `10Gi` | Data disk / Postgres disk |

## Render

```bash
helm template demo ./mealie --set uuid=ab12cd34,url=recipes.eu-up.apps.robots.beer,dbpass=change-me
```
