# homebox

Home inventory and organization system: track what you own, where it is, warranties,
receipts and photos, with labels and QR codes. Upstream:
https://github.com/sysadminsmedia/homebox (AGPL-3.0, fine to host).

- **Image**: `ghcr.io/sysadminsmedia/homebox:0.27.1`, run as uid 1000
- **Database**: none. SQLite on the volume (the chart does not use Homebox's Postgres option)
- **Data volume**: `/data` (`homebox.db` and attachments, photos, thumbnails)

## Login

Homebox logs in by email. Open `https://<url>/`, enter **Email** `admin@<url>` (e.g.
`admin@stuff.eu-up.apps.robots.beer`) and **Password** = the release's `dbpass`, then
**Login**. Change the password under **Profile**: it is kept, the chart never resets it.

`HBOX_OPTIONS_ALLOW_REGISTRATION=false` blocks every sign-up, the first one included, and
there is no env var for an admin. So an init container starts the server on 127.0.0.1 only
with registration on, registers `auth.username` / dbpass, stops it, and writes
`/data/.robots-admin-created`. Later boots see the marker and skip. It exits non-zero rather
than start an app nobody can log in to.

## Backups

Everything is on the one volume. Losing it loses the inventory. Backups are the customer's
job for now: **Tools > Export Inventory** (CSV), attachments not included.

## Security notes

- Pinned: `ALLOW_REGISTRATION=false`, OIDC off, local login on, GitHub release check and analytics off.
- Outbound fetching (SSRF): notifiers send to URLs the user types in (webhooks, shoutrrr).
  `HBOX_NOTIFIER_BLOCK_LOCAL_NETS`, `_LOCALHOST`, `_BOGON_NETS` and `_CLOUD_METADATA` are all
  `true`, so they cannot target cluster-internal addresses. There is no egress NetworkPolicy behind that.
- `HBOX_AUTH_API_KEY_PEPPER` = sha256 of a string built from dbpass: deterministic, so ArgoCD
  re-renders it identically. Changing dbpass invalidates every API key.
- Not verified: whether the login rate limiter (5 attempts/min) keys on Traefik's address,
  since `HBOX_OPTIONS_TRUST_PROXY` is left at `false`. If it does, bad logins slow every visitor.
- Drop ALL capabilities, non-root, no privilege escalation.

Built on the `robots-service` skill baseline. The top block of `values.yaml` is set per
release by helmdeployer and must not be renamed.

## Values a human would change

| Value | Default | What it does |
|---|---|---|
| `resource` | `low` | Size tier: `low`, `medium` or `high` |
| `app.tag` | `0.27.1` | Upstream tag. Bump `appVersion` and `version` with it |
| `auth.username` | `admin@{{ .Values.url }}` | Admin email (templated); the password is always dbpass |
| `storage` | `10Gi` | Data disk (UpCloud floor is 10Gi) |

## Render

```bash
helm template demo ./homebox --set uuid=ab12cd34,url=stuff.eu-up.apps.robots.beer,dbpass=change-me
```
