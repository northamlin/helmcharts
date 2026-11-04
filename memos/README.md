# memos

Memos: a lightweight, self-hosted note-taking and microblogging service. Write short Markdown
notes, tag them, attach files, and share selected memos. Upstream: https://github.com/usememos/memos (MIT).

- **Image**: `neosmemo/memos:26.11.0`, runs as uid 10001 with every capability dropped.
- **Database**: CloudNativePG Postgres (memos, users, settings) via `MEMOS_DSN`.
- **Data volume**: `/var/opt/memos` (attachments when storage is set to local files).
- **Login**: username `admin`, password = the release's `dbpass`.

## Locked down by declarative configuration

`/etc/memos/config/lock.json` (a configFile) is applied by Memos itself at every startup, in
one transaction. It creates the admin and pins two instance settings, which then cannot be
changed from the UI or the API (`MANAGED_BY_CONFIGURATION`):

- **GENERAL**: `disallowUserRegistration: true`, and `additionalScript` / `additionalStyle`
  empty. Those two are admin-only fields that Memos injects into every page as raw
  `<script>` / `<style>`, i.e. stored XSS on every visitor. Pinning them closes that.
- **ACCESS**: `INSTANCE_ACCESS_MODE_PRIVATE`. Nothing is readable without a login, not even
  memos marked Public; the API answers 401.

The admin's password is set only when the user is created. If the customer changes it in
Settings, the new password sticks; the chart does not reset it to `dbpass` on restart.

## Security notes

- **Outbound fetches (SSRF)**: link previews are fetched server-side, but Memos refuses
  internal IP addresses. Webhooks to private networks are refused unless listed in
  `--webhook-private-network-allowlist` (not set). There is no egress NetworkPolicy.
- Sign-up is refused (`403 user registration is not allowed`); the admin can still create
  users from Settings → Members.
- `db-ready` is a second, instant DB wait kept for `local-run.sh` (see values.yaml).

## Values a human would change

| Value | Default | What it does |
|---|---|---|
| `resource` | `low` | Size tier: `low`, `medium` or `high` |
| `app.tag` | `26.11.0` | Upstream tag. Bump `appVersion` and `version` with it |
| `auth.username` | `admin` | Admin username, `[a-z0-9-]` (the password is always `dbpass`) |
| `app.configFiles` (lock.json) | private, no sign-up | Switch `accessMode` to `INSTANCE_ACCESS_MODE_PUBLIC` for a public explore page |
| `storage` / `database.storage` | `10Gi` | Attachment disk / Postgres disk |

## Render

```bash
helm template demo ./memos --set uuid=ab12cd34,url=memos.eu-up.apps.robots.beer,dbpass=change-me
```
