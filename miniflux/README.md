# miniflux

Minimalist, fast RSS/Atom/JSON feed reader with a clean web UI, keyboard shortcuts, a REST
API and Fever/Google Reader API compatibility for mobile apps. Upstream:
https://github.com/miniflux/v2 (Apache-2.0).

- **Image**: `miniflux/miniflux:2.3.5`
- **Database**: PostgreSQL via CNPG (`<name>-<uuid>-pg`), libpq key=value DSN built from the
  template's DB env with `$(VAR)` expansion
- **Data volume**: none. Feeds, entries, users and sessions all live in Postgres.
- **Login**: open `https://<url>/`, user `admin`, password = the release's `dbpass`. The same
  pair works as HTTP basic auth on the API (`curl -u admin:… https://<url>/v1/me`).

Built on the `robots-service` skill baseline. The top block of `values.yaml` is set per
release by helmdeployer and must not be renamed.

## Security notes

- **No sign-up exists.** Miniflux only creates users from the admin's settings page or the
  admin API. The admin is created on first boot by `CREATE_ADMIN=1` and skipped on every
  later boot (so changing the password in the UI sticks).
- Auth-proxy and OAuth2 user creation are pinned off, local (password) auth is pinned on.
- **Outbound fetching (SSRF)**: Miniflux fetches every feed URL a user subscribes to, plus
  scraped article pages and media. `FETCHER_ALLOW_PRIVATE_NETWORKS=0`,
  `FETCHER_ALLOW_PRIVATE_FEED_PROXY=0` and `INTEGRATION_ALLOW_PRIVATE_NETWORKS=0` are pinned,
  so private, loopback and link-local addresses (including cluster Services) are refused at
  connect time. There is still no egress NetworkPolicy; public internet is reachable by design.
- Runs as 65534 (nobody), read-only root filesystem, all capabilities dropped.
- `/metrics` is off (`METRICS_COLLECTOR=0`).

## Values a human would change

| Value | Default | What it does |
|---|---|---|
| `resource` | `low` | Size tier: `low`, `medium` or `high` |
| `app.tag` | `2.3.5` | Upstream tag. Bump `appVersion` and `version` with it |
| `auth.username` | `admin` | Admin login name (the password is always `dbpass`); only applied on first boot |
| `app.env.WORKER_POOL_SIZE` | `4` | Parallel feed fetchers; raise on bigger tiers |
| `database.storage` | `10Gi` | Postgres disk (UpCloud floor is 10Gi) |

## Render

```bash
helm template demo ./miniflux --set uuid=ab12cd34,url=feeds.eu-up.apps.robots.beer,dbpass=change-me
```
