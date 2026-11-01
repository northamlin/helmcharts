# wikijs

Wiki.js 2: a modern wiki with Markdown, WYSIWYG and raw HTML editors, page trees, search and
per-group permissions. Upstream: https://github.com/requarks/wiki (AGPL-3.0, run unmodified).

- **Image**: `ghcr.io/requarks/wiki:2.5.317`, runs as uid 1000 with every capability dropped.
- **Database**: CloudNativePG Postgres (pages, users, uploads). No app data volume; `/wiki/data` is a cache.
- **Login**: email `admin@<url>`, password = the release's `dbpass`. Sign-up is disabled.
  Guests can read published pages (Wiki.js's default guest group); writing needs a login.
  Tighten the guest group under Administration → Groups for a private wiki.

## First boot

A fresh Wiki.js opens a setup wizard, and whoever submits it first becomes admin. The chart
closes that window: `bootstrap.js` (a configFile) runs next to the server, posts `/finalize`
on localhost with the release's login, and exits. The pod is not Ready until then, because the
wizard answers 200 to every GET, so readiness is an exec probe that requires `/healthz` to
return Wiki.js's JSON `{"ok":true}`. On later boots `bootstrap.js` sees that JSON and exits at once.

1.0.0 replaces the 0.x chart (in-chart MySQL, broken Service selector and Ingress backend).
There is no upgrade path from 0.x: no 0.x release ever served traffic.

## Values a human would change

| Value | Default | What it does |
|---|---|---|
| `resource` | `low` | Size tier: `low`, `medium` or `high` |
| `app.tag` | `2.5.317` | Upstream tag. Bump `appVersion` and `version` with it |
| `auth.username` | `admin@{{ .Values.url }}` | Admin email (the password is always `dbpass`) |
| `database.storage` | `10Gi` | Postgres disk |

## Render

```bash
helm template demo ./wikijs --set uuid=ab12cd34,url=wiki.eu-up.apps.robots.beer,dbpass=change-me
```
