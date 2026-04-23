# Wiki.js Helm Chart

Modern, fast and powerful open-source wiki application built on Node.js. Wiki.js supports Markdown, a visual editor, granular permissions and a wide range of storage backends including Git.

Read more: https://js.wiki

- **Chart version**: 0.1.0
- **App version**: 1.0

## Dependencies

| Component | Description |
|-----------|-------------|
| MySQL | Primary database |

## Key values

| Value | Default | Description |
|-------|---------|-------------|
| `url` | `wiki.apps.northamlin.com` | Ingress hostname |
| `name` | (required) | Deployment name, used as DB name |
| `dbuser` | (required) | MySQL username |
| `dbpass` | (required) | MySQL password |

## Deploy

```bash
helm upgrade --install wiki ./wikijs \
  --namespace mywiki \
  --set name=mywiki \
  --set url=wiki.apps.northamlin.com \
  --set dbuser=wikiuser \
  --set dbpass=<password>
```
