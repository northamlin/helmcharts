# atuin

Atuin sync server: syncs your shell history (bash, zsh, fish, nushell) between machines.
History is end-to-end encrypted by the client before it is uploaded; the server only stores
ciphertext. Upstream: https://github.com/atuinsh/atuin (MIT).

- **Image**: `ghcr.io/atuinsh/atuin:18.24.4` (`atuin-server start`)
- **Database**: PostgreSQL via CNPG (`<name>-<uuid>-pg`), `ATUIN_DB_URI` built from the
  template's DB env with `$(VAR)` expansion (dbpass is base64url, so it is URI-safe)
- **Data volume**: none. `/config` is an emptyDir (the server writes a default
  `server.toml` there; every setting comes from env).
- **No web UI.** `https://<url>/` answers a JSON banner; the service is the sync API.

## Login (what the customer types)

```bash
# ~/.config/atuin/config.toml:   sync_address = "https://<url>"
atuin login -u admin -p '<dbpass>' -k "$(atuin key)"   # -k: your own encryption key
atuin sync
```

The username is `admin` (`auth.username`), its email `admin@<url>`, the password the
release's `dbpass`. The encryption key never leaves the customer's machines: lose it and
the history on the server is unreadable, including to us. To change the password:
`atuin account change-password`.

Built on the `robots-service` skill baseline. The top block of `values.yaml` is set per
release by helmdeployer and must not be renamed.

## How the admin is created

The `create-admin` init container (same image, after `wait-for-db`) pipes dbpass to
`atuin-server admin user create --email admin@<url> admin`, which works with registration
closed and runs the migrations. On later boots the duplicate-username error is recognised
and ignored, so a changed password survives restarts; any other error (DB down) fails the
init and Kubernetes retries it.

## Security notes

- Pinned: `ATUIN_OPEN_REGISTRATION=false` (`atuin register` gets 400 "this server is not open
  for registrations"), metrics off, `ATUIN_HOST`/`ATUIN_PORT` explicit.
- Single-account by design: there is no way to create further users except
  `atuin-server admin user create` inside the pod.
- **Outbound fetching (SSRF)**: none. The server makes no outbound requests (the
  registration webhook is unset and not user-settable).
- Runs as `atuin` (1000), read-only root filesystem, all capabilities dropped.

## Values a human would change

| Value | Default | What it does |
|---|---|---|
| `resource` | `low` | Size tier: `low`, `medium` or `high` |
| `app.tag` | `18.24.4` | Upstream tag. Bump `appVersion` and `version` with it |
| `auth.username` | `admin` | Atuin username (letters, digits, hyphens); only applied on first boot |
| `database.storage` | `10Gi` | Postgres disk (UpCloud floor is 10Gi) |

## Render

```bash
helm template demo ./atuin --set uuid=ab12cd34,url=atuin.eu-up.apps.robots.beer,dbpass=change-me
```
