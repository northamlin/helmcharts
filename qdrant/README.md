# qdrant

Vector similarity search engine for semantic search, RAG and recommendations, with a REST API and a web dashboard at `/dashboard`. Upstream: https://github.com/qdrant/qdrant (Apache-2.0).

- **Image**: `qdrant/qdrant:v1.20.0-unprivileged`
- **API key**: the release's `dbpass`. Every request needs the `api-key: <dbpass>` header, except `/healthz`, `/readyz` and the static `/dashboard` (which asks for the key).
- **gRPC** (6334) is not exposed. REST on 443 only.
- **Data volume**: `/qdrant/data` (`storage/` and `snapshots/`). Runs as uid 1000 (the upstream `-unprivileged` image).

Built on the `robots-service` skill baseline. The top block of `values.yaml` is set per
release by helmdeployer and must not be renamed.

## Values a human would change

| Value | Default | What it does |
|---|---|---|
| `resource` | `low` | Size tier: `low`, `medium` or `high` |
| `app.tag` | `v1.20.0-unprivileged` | Upstream tag. Bump `appVersion` and `version` with it |
| `auth.username` | `admin` | Login name (the password is always `dbpass`) |
| `storage` | `10Gi` | Data disk (UpCloud floor is 10Gi) |

## Render

```bash
helm template demo ./qdrant --set uuid=ab12cd34,url=qdrant.eu-up.apps.robots.beer,dbpass=change-me
```
