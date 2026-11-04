# paperless

Paperless-ngx: a document management system. Upload scans and PDFs, and it OCRs them,
makes them full-text searchable, tags them automatically and archives them as PDF/A.
Upstream: https://github.com/paperless-ngx/paperless-ngx (GPL-3.0).

- **Image**: `ghcr.io/paperless-ngx/paperless-ngx:3.4.1`, s6-overlay started as uid 1000 with every
  capability dropped. Started non-root, s6 skips its usermod/chown steps and needs only a
  writable `/run` (emptyDir).
- **Redis**: a `redis:7-alpine` sidecar in the same pod on `127.0.0.1:6379`. It is the Celery broker
  only. It has no persistence and it isn't reachable from outside the pod.
- **Database**: CloudNativePG Postgres (documents' metadata, users, settings).
- **Data volume**: `/usr/src/paperless/store`, which holds `data/` (search index, classifier, logs)
  and `media/` (originals, archived PDFs, thumbnails). `consume`, `export`, `/tmp` and `/run` are emptyDirs.
- **Login**: username `admin`, password = the release's `dbpass`. Sign-up is closed.
- **Tier**: always at least `high` (`minResource: high`), whatever tier the wizard sends: price it as
  a high-tier service. Measured locally: about 530–665 MiB idle and about 870 MiB peak OCRing one
  300-dpi A4 scan; `low` (512 MiB limit) would be OOM-killed even when idle.

## How the admin is created

`PAPERLESS_ADMIN_USER` / `PAPERLESS_ADMIN_PASSWORD` come from the `<fullname>-auth` Secret. s6's
`init-superuser` creates the user once, before the webserver listens. On later boots it logs
"a user admin already exists" and changes nothing. A password the customer changes in the UI
therefore sticks.

`PAPERLESS_SECRET_KEY` is `sha256("paperless-ngx-secret-key:" + dbpass)`. That is deterministic,
so ArgoCD re-renders it identically and sessions survive syncs.

## Security notes

- Pinned: `ACCOUNT_ALLOW_SIGNUPS=false`, `SOCIALACCOUNT_ALLOW_SIGNUPS=false`, `ENABLE_UPDATE_CHECK=false`,
  `DEBUG=false`, and HTTP remote-user (header) auth off for both UI and API.
- **Outbound fetches (SSRF)**: users can configure workflow webhooks, mail accounts (IMAP) and,
  from the admin's Application Configuration, AI/LLM and remote-OCR endpoints. All four
  `*_ALLOW_INTERNAL_*` switches are pinned `false`, so those requests may not target
  cluster-internal addresses. There is no egress NetworkPolicy, so public hosts are reachable.
- Pre/post-consume scripts are env-only (`PAPERLESS_PRE_CONSUME_SCRIPT`) and unset. A customer
  cannot add server-side code.
- Don't set `PAPERLESS_OCR_LANGUAGES`. It apt-installs packages at boot, which fails in a non-root pod.
  Choose among the bundled languages with `PAPERLESS_OCR_LANGUAGE` (e.g. `deu+eng`).

## Values a human would change

| Value | Default | What it does |
|---|---|---|
| `minResource` | `high` | Tier floor. A release that asks for `low` or `medium` gets `high` |
| `app.tag` | `3.4.1` | Upstream tag. Bump `appVersion` and `version` with it |
| `auth.username` | `admin` | Admin username (the password is always `dbpass`) |
| `app.env.PAPERLESS_OCR_LANGUAGE` | `eng` | OCR language(s), from the languages bundled in the image |
| `app.env.PAPERLESS_TASK_WORKERS` | `1` | Parallel consume jobs. Each adds roughly one OCR peak of memory |
| `storage` / `database.storage` | `10Gi` | Document disk / Postgres disk |

## Render

```bash
helm template demo ./paperless --set uuid=ab12cd34,url=docs.eu-up.apps.robots.beer,dbpass=change-me
```
