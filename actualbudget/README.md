# actualbudget

Actual Budget: a local-first envelope budgeting app. The server stores and syncs budget
files between your browsers and devices. Upstream: https://github.com/actualbudget/actual (MIT).

- **Image**: `actualbudget/actual-server:26.11.0`, run as uid 1001 (the image's `actual` user)
- **Database**: none. SQLite files on the volume
- **Data volume**: `/data` (`server-files/account.sqlite`: password hash and sessions; `user-files/`: budgets)

## Login

Actual has one server password and no user name. Open `https://<url>/`, type the release's
`dbpass` into **Password**, press **Sign in**. Then create or import a budget. Change the
password under **Settings > Server**: it is kept, the chart never resets it.

There is no env var for that password: a fresh server hands `/account/bootstrap` to whoever
calls it first. An init container starts `node app.js` on 127.0.0.1 only, posts the bootstrap
with dbpass and stops it before the app listens on 0.0.0.0. On later boots it sees the
server is bootstrapped and exits 0. It exits non-zero if bootstrapping failed, so the public
URL never serves an open bootstrap.

## Backups

Budgets live on the volume (and locally in each browser). Losing the volume loses the synced
copies. Backups are the customer's job for now: **Settings > Export data** gives a zip.
End-to-end encrypted budgets cannot be read by the server or by us.

## Security notes

- Pinned: `ACTUAL_LOGIN_METHOD=password`, `ACTUAL_ALLOWED_LOGIN_METHODS=password` (no header
  or OpenID login), `ACTUAL_USER_CREATION_MODE=manual`. Env beats `/data/config.json`.
- Outbound fetching (SSRF): `ACTUAL_CORS_PROXY_ENABLED=false`, so the server does not relay
  requests for frontend plugins. Bank sync (GoCardless, SimpleFIN) is customer-configured and
  fetches the provider's URL; SimpleFIN refuses private addresses unless
  `ACTUAL_SIMPLEFIN_ALLOWED_NETWORKS` is set (it is not). Plugins run in the browser only.
- Drop ALL capabilities, non-root, no privilege escalation.

Built on the `robots-service` skill baseline. The top block of `values.yaml` is set per
release by helmdeployer and must not be renamed.

## Values a human would change

| Value | Default | What it does |
|---|---|---|
| `resource` | `low` | Size tier: `low`, `medium` or `high` |
| `app.tag` | `26.11.0` | Upstream tag. Bump `appVersion` and `version` with it |
| `app.env.ACTUAL_UPLOAD_FILE_SYNC_SIZE_LIMIT_MB` | (unset, 20) | Raise for large budgets |
| `storage` | `10Gi` | Data disk (UpCloud floor is 10Gi) |

## Render

```bash
helm template demo ./actualbudget --set uuid=ab12cd34,url=budget.eu-up.apps.robots.beer,dbpass=change-me
```
