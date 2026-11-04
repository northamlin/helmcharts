# vaultwarden

Lightweight Bitwarden-compatible password manager server: use the official Bitwarden apps,
browser extensions and the bundled web vault against your own server. Upstream:
https://github.com/dani-garcia/vaultwarden (AGPL-3.0, fine to host).

- **Image**: `vaultwarden/server:1.37.5`, run as uid 1000 (the image defaults to root; nothing needs it with `ROCKET_PORT=8080`)
- **Database**: PostgreSQL via CNPG (`<name>-<uuid>-pg`), wired as `DATABASE_URL` from `$(DB_*)` references
- **Data volume**: `/var/lib/vaultwarden` (`DATA_FOLDER`): `rsa_key.pem` (signs every session), attachments, sends, icon cache, and `config.json` (settings saved in /admin)

## Login

Sign-up is closed (`SIGNUPS_ALLOWED=false`). There is no admin account; the admin panel takes
a token, and the token is the release's password (`dbpass`). The customer creates their own
account through an invitation:

1. Open `https://<url>/admin`, paste the release password into **Admin token**, press **Enter**.
2. Go to **Users**, type your own email under **Invite User**, press **Invite**.
3. Open `https://<url>/` and choose **Create account**. Enter the same email and your name, then **Continue**.
   No email is sent (SMTP is not configured). The web vault goes straight to the next step.
4. Choose your master password, then **Create account**. Log in with that email and master password.

Anyone else gets "Registration not allowed". To add family or colleagues, repeat step 2 for
their email, or create an organization and invite them from it (`INVITATIONS_ALLOWED=true`).
The master password is never known to us and cannot be reset: lose it, lose the vault.

The hashed admin token is written at every boot by an init container (`vaultwarden hash
--preset owasp`, argon2id with a random salt, so at runtime and never in the template) into
an emptyDir read through `ADMIN_TOKEN_FILE`. Settings saved in /admin go to `config.json` and
override env: a customer can reopen sign-ups there, and that is their choice.

## Backups

All vaults live in Postgres and the signing key on the volume. Losing the volume loses
`rsa_key.pem`, which logs every client out; losing the database loses every vault. Backups
are the customer's job for now: export from the web vault (**Tools > Export vault**).

## Security notes

- Pinned: `SIGNUPS_ALLOWED=false`, `SIGNUPS_VERIFY=false`, `INVITATIONS_ALLOWED=true`, `DISABLE_ADMIN_TOKEN=false`, `PASSWORD_HINTS_ALLOWED=false`, `SHOW_PASSWORD_HINT=false`.
- Outbound fetching (SSRF): the server downloads a favicon for every website saved in a vault.
  `ICON_BLACKLIST_NON_GLOBAL_IPS=true` and `HTTP_REQUEST_BLOCK_NON_GLOBAL_IPS=true` refuse
  private and cluster-internal targets. There is no egress NetworkPolicy behind that.
- `/admin` is on the public URL, protected only by the token. Drop ALL capabilities, non-root, no privilege escalation.

Built on the `robots-service` skill baseline. The top block of `values.yaml` is set per
release by helmdeployer and must not be renamed.

## Values a human would change

| Value | Default | What it does |
|---|---|---|
| `resource` | `low` | Size tier: `low`, `medium` or `high` |
| `app.tag` | `1.37.5` | Upstream tag. Bump `appVersion` and `version` with it |
| `app.env.SIGNUPS_ALLOWED` | `"false"` | Open sign-up. Leave it closed on a public URL |
| `app.env.ICON_SERVICE` | `internal` | `internal` fetches favicons server-side; `bitwarden`/`duckduckgo` let the client fetch from them instead |
| `storage` / `database.storage` | `10Gi` | Data and Postgres disks (UpCloud floor is 10Gi) |

## Render

```bash
helm template demo ./vaultwarden --set uuid=ab12cd34,url=vault.eu-up.apps.robots.beer,dbpass=change-me
```
