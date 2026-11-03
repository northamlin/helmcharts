#!/usr/bin/env bash
# Sync helmchart services to Strapi.
# Usage:
#   ./sync-to-strapi.sh                  # dry-run, shows what would be created/updated
#   ./sync-to-strapi.sh --apply          # create missing services
#   ./sync-to-strapi.sh --apply --update # also update existing services
#
# Env vars (override defaults):
#   STRAPI_URL   default: http://content.robots.beer
#   STRAPI_TOKEN required (or set in .env in this dir)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load .env if present
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.env"
fi

STRAPI_URL="${STRAPI_URL:-http://content.robots.beer}"
STRAPI_TOKEN="${STRAPI_TOKEN:-}"
STRIPE_SECRET_KEY="${STRIPE_SECRET_KEY:-}"
APPLY=false
UPDATE=false

for arg in "$@"; do
  case $arg in
    --apply)  APPLY=true ;;
    --update) UPDATE=true ;;
  esac
done

if [[ -z "$STRAPI_TOKEN" ]]; then
  echo "ERROR: STRAPI_TOKEN is not set." >&2
  exit 1
fi

if [[ -n "$STRIPE_SECRET_KEY" ]]; then
  echo "Stripe: product lookup enabled"
else
  echo "Stripe: STRIPE_SECRET_KEY not set — stripeId will use chart-{uuid} placeholder"
fi

HEADERS=(-H "Authorization: Bearer $STRAPI_TOKEN" -H "Content-Type: application/json")

# ── helpers ──────────────────────────────────────────────────────────────────

yaml_field() {
  local file="$1" field="$2"
  { grep -E "^${field}:" "$file" 2>/dev/null || true; } | head -1 | sed "s/^${field}:[[:space:]]*//" | tr -d '"'
}

stripe_get_product_id() {
  local name="$1"
  [[ -z "$STRIPE_SECRET_KEY" ]] && echo "" && return
  curl -s -G "https://api.stripe.com/v1/products" \
    -u "${STRIPE_SECRET_KEY}:" \
    --data-urlencode "active=true" \
    --data-urlencode "limit=100" \
    | python3 -c "
import sys, json
d = json.load(sys.stdin)
target = sys.argv[1].lower()
for p in d.get('data', []):
    if p.get('name', '').lower() == target:
        print(p['id'])
        break
" "$name" 2>/dev/null
}

# Prints the documentId, or nothing if no service has this uuid. A failed lookup
# (bad token, Strapi down) must stop the run: treating it as "not found" would
# create a duplicate of every service.
strapi_get_by_uuid() {
  local uuid="$1"
  curl -sg --globoff "${STRAPI_URL}/api/services?filters[uuid][\$eq]=${uuid}" "${HEADERS[@]}" \
    | python3 -c "
import sys, json
d = json.load(sys.stdin)
if not isinstance(d.get('data'), list):
    sys.exit('Strapi lookup failed: ' + json.dumps(d.get('error') or d))
print(d['data'][0]['documentId'] if d['data'] else '')
"
}

strapi_post() {
  local payload="$1"
  curl -s -X POST "${STRAPI_URL}/api/services" "${HEADERS[@]}" -d "$payload"
}

strapi_put() {
  local id="$1" payload="$2"
  curl -s -X PUT "${STRAPI_URL}/api/services/${id}" "${HEADERS[@]}" -d "$payload"
}

is_internal() {
  local name="$1" c
  for c in "${INTERNAL_CHARTS[@]}"; do [[ "$c" == "$name" ]] && return 0; done
  return 1
}

# Descriptions are written with \n escapes for readability; turn them into real
# newlines so Strapi stores markdown, not a literal backslash-n.
unescape_newlines() {
  printf '%b' "$1"
}

json_escape() {
  python3 -c "import sys,json; s=sys.stdin.read(); print(json.dumps(s[:-1] if s.endswith(chr(10)) else s))" <<< "$1"
}

# ── chart definitions ─────────────────────────────────────────────────────────
# Building-block charts that other charts and the deploy path use, and our own tools.
# They are not products, so they are never published to Strapi as services.
# slackbot: our own Slack/NATS bridge, dropped from the catalogue on 2026-11-01.
INTERNAL_CHARTS=(ingress namespace service sql-service slackbot)

# Customer-facing name per chart. Charts not listed fall back to Chart.yaml's name.
declare -A DISPLAY_NAMES=(
  [kurrier]="Kurrier" [matomo]="Matomo" [mautic]="Mautic" [moodle]="Moodle"
  [postal]="Postal" [radicale]="Radicale"
  [wikijs]="Wiki.js" [wordpress]="WordPress" [linkding]="linkding"
  [qdrant]="Qdrant"
  [verdaccio]="Verdaccio"
  [ntfy]="ntfy"
  [mailpit]="Mailpit"
)

# Each entry: "chart_dir|uuid|display_name|description_markdown"
# Description is auto-generated from Chart.yaml if not listed here.

declare -A DESCRIPTIONS
DESCRIPTIONS[radicale]="## What is Radicale?\n\nRadicale is a lightweight, open-source **CalDAV and CardDAV server** for self-hosting calendars and contacts.\n\n* Sync calendars and contacts across all devices via CalDAV/CardDAV\n* IMAP-authenticated — no separate user database needed\n* Minimal resource footprint, no dedicated database engine required\n* Full data ownership: no third-party cloud involved"

DESCRIPTIONS[matomo]="## What is Matomo?\n\nMatomo is an open-source **web analytics platform** — a GDPR-friendly, self-hosted alternative to Google Analytics.\n\n* Track visitors, referrers, and page views without third-party data sharing\n* Heatmaps, session recording, goal and conversion tracking\n* 100% data ownership: everything stays in your own database\n* Compatible with most tag managers and CMS platforms"

DESCRIPTIONS[kurrier]="## What is Kurrier?\n\nKurrier is a **transactional email frontend** with a Redis-backed worker queue and PostgreSQL persistence.\n\n* Send transactional email via a clean API or SMTP relay\n* Queue-based delivery decouples request from send — no email lost under load\n* Real-time delivery, bounce, open, and click tracking\n* CNPG-managed PostgreSQL backend, fully self-hosted"

DESCRIPTIONS[wordpress]="## What is WordPress?\n\nWordPress is the world's most popular open-source **CMS**, powering over 40% of all websites.\n\n* Build any website — blog, portfolio, shop, or community — with no coding required\n* 60,000+ free plugins: SEO, e-commerce, forms, membership, and more\n* Block editor for visual drag-and-drop page building\n* MySQL-backed, pre-seeded and ready on first boot"

DESCRIPTIONS[mautic]="## What is Mautic?\n\nMautic is an open-source **marketing automation platform** — the self-hosted alternative to HubSpot or Mailchimp.\n\n* Automated email campaigns triggered by user behaviour or time\n* Lead scoring, dynamic segmentation, and CRM sync\n* Landing page and form builder with built-in conversion tracking\n* Full data ownership: every contact and event stays in your database"

DESCRIPTIONS[postal]="## What is Postal?\n\nPostal is a full-featured open-source **mail delivery platform** — a self-hosted alternative to SendGrid or Mailgun.\n\n* High-volume transactional and marketing email delivery\n* SMTP and HTTP API — drop-in compatible with most frameworks\n* Per-message delivery tracking: opens, clicks, bounces, spam complaints\n* Multi-tenant: manage multiple organizations and domains from one installation\n* RabbitMQ-backed queue for reliable async processing"


DESCRIPTIONS[moodle]="## What is Moodle?\n\nMoodle is the world's leading open-source **Learning Management System (LMS)**.\n\n* Deliver structured online courses with quizzes, assignments, and grading\n* Supports SCORM, video, forums, and interactive H5P content\n* Role-based access: students, teachers, and admins in one platform\n* Scales from small classrooms to universities with thousands of users"

DESCRIPTIONS[linkding]="## What is linkding?\n\nlinkding is a minimal, fast, open-source **bookmark manager** you host yourself — a private alternative to Pocket or Raindrop.\n\n* Save, tag and full-text search bookmarks from one clean interface\n* Browser extensions for Firefox and Chrome, plus a bookmarklet for everything else\n* Archives page snapshots so links keep working after the site disappears\n* Import and export the standard Netscape HTML format — no lock-in\n* PostgreSQL-backed, ready to log in on first boot"

DESCRIPTIONS[qdrant]="## What is Qdrant?\n\nQdrant is an open-source **vector database** for AI applications: semantic search, RAG and recommendations.\n\n* Store embeddings from OpenAI, Claude-based pipelines, Ollama or any model, and search them by similarity\n* Filter on payload fields while you search\n* Official clients for Python, TypeScript, Go, Rust and more, and works with LangChain and LlamaIndex\n* Protected by an API key from the first boot"

DESCRIPTIONS[verdaccio]="## What is Verdaccio?\n\nVerdaccio is an open-source **private npm registry** and caching proxy for npmjs.org.\n\n* Publish private packages your team installs with plain \`npm\`, \`pnpm\` or \`yarn\`\n* Caches public packages, so installs are faster and survive npmjs outages\n* Works with scoped packages and your existing \`.npmrc\`\n* Private by default: every read and publish needs a login"

DESCRIPTIONS[ntfy]="## What is ntfy?\n\nntfy is an open-source **push notification service**: send a notification to your phone or desktop with a single HTTP request.\n\n* \`curl -d \"deploy done\" https://your-ntfy/alerts\` from any script, cron job or CI pipeline\n* Android, iOS and web apps that subscribe to topics\n* Attachments, priorities, tags, click actions and scheduled delivery\n* Private by default: every topic needs a login"

DESCRIPTIONS[mailpit]="## What is Mailpit?\n\nMailpit is an open-source **email testing tool**. It catches the mail your app sends, so you can inspect it without anything reaching a real inbox.\n\n* Modern web UI with HTML, text, headers and attachment views\n* REST API to send and assert on messages from tests and CI\n* HTML compatibility and link checks for your templates\n* Locked behind a login from the first boot"

DESCRIPTIONS[wikijs]="## What is Wiki.js?\n\nWiki.js is a modern, open-source **wiki platform** for team documentation and knowledge bases.\n\n* Write in Markdown, WYSIWYG or raw HTML, with live preview\n* Page trees, tags, full-text search and page history\n* Granular access control: public pages, private spaces or per-group permissions\n* Locked to your admin login from the first boot; sign-up is off"

# ── main loop ─────────────────────────────────────────────────────────────────

echo "Strapi: $STRAPI_URL"
echo "Mode:   $([ "$APPLY" = true ] && echo apply || echo dry-run) $([ "$UPDATE" = true ] && echo '+update' || :)"
echo ""

CREATED=0
UPDATED=0
SKIPPED=0
MANAGED_UUIDS=()

for chart_dir in "$SCRIPT_DIR"/*/; do
  chart_name="$(basename "$chart_dir")"
  chart_yaml="$chart_dir/Chart.yaml"
  values_yaml="$chart_dir/values.yaml"

  [[ -f "$chart_yaml" ]] || continue

  if is_internal "$chart_name"; then
    echo "[INTERNAL] $chart_name — building-block chart, not a service"
    continue
  fi

  # The chart directory name is the Strapi uuid — the one upsert key. values.yaml's
  # uuid is a per-deployment placeholder (hbdftsrfed, 12345) and must not be used,
  # or a placeholder change creates a second record for the same chart.
  uuid="$chart_name"
  MANAGED_UUIDS+=("$uuid")

  display_name="${DISPLAY_NAMES[$chart_name]:-$(yaml_field "$chart_yaml" "name")}"
  description_raw="${DESCRIPTIONS[$chart_name]:-}"

  if [[ -z "$description_raw" ]]; then
    chart_desc=$(yaml_field "$chart_yaml" "description")
    description_raw="## $display_name\n\n$chart_desc"
  fi
  description_raw=$(unescape_newlines "$description_raw")

  existing_id=$(strapi_get_by_uuid "$uuid") || exit 1

  # Prefer stripeProductId from values.yaml, then fall back to Stripe API name lookup
  stripe_product_id=""
  if [[ -f "$values_yaml" ]]; then
    stripe_product_id=$(yaml_field "$values_yaml" "stripeProductId")
  fi
  if [[ -z "$stripe_product_id" ]]; then
    stripe_product_id=$(stripe_get_product_id "$display_name")
  fi
  if [[ -z "$stripe_product_id" ]]; then
    stripe_product_id="chart-${uuid}"
    [[ -n "$STRIPE_SECRET_KEY" ]] && echo "        [WARN] no Stripe product found for '$display_name', using placeholder"
  fi

  if [[ -n "$existing_id" ]]; then
    if [[ "$UPDATE" = true ]]; then
      echo "[UPDATE] $chart_name (uuid=$uuid, id=$existing_id, stripeId=$stripe_product_id)"
      if [[ "$APPLY" = true ]]; then
        desc_json=$(json_escape "$description_raw")
        payload="{\"data\":{\"name\":$(json_escape "$display_name"),\"desc\":${desc_json},\"uuid\":\"${uuid}\",\"stripeId\":\"${stripe_product_id}\"}}"
        result=$(strapi_put "$existing_id" "$payload")
        updated_id=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print((d.get('data') or {}).get('documentId') or (d.get('error') or {}).get('message','ERROR'))" 2>/dev/null)
        echo "        → updated documentId=$updated_id"
        ((UPDATED++)) || true
      fi
    else
      echo "[SKIP]   $chart_name (uuid=$uuid, id=$existing_id) — already exists"
      ((SKIPPED++)) || true
    fi
  else
    echo "[CREATE] $chart_name (uuid=$uuid, stripeId=$stripe_product_id)"
    if [[ "$APPLY" = true ]]; then
      desc_json=$(json_escape "$description_raw")
      name_json=$(json_escape "$display_name")
      payload="{\"data\":{\"name\":${name_json},\"desc\":${desc_json},\"stripeId\":\"${stripe_product_id}\",\"uuid\":\"${uuid}\",\"price\":0}}"
      result=$(strapi_post "$payload")
      new_id=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print((d.get('data') or {}).get('documentId') or (d.get('error') or {}).get('message','?'))" 2>/dev/null)
      echo "        → created documentId=$new_id"
      ((CREATED++)) || true
    fi
  fi
done

# Report Strapi services this script does not own: internal charts published by an
# older version of this script, hand-made duplicates, or services with no chart.
# They are listed, never deleted — removing a service is a human decision.
echo ""
echo "Strapi services not backed by a public chart (review and remove by hand):"
curl -sg --globoff "${STRAPI_URL}/api/services?pagination[pageSize]=200&fields[0]=uuid&fields[1]=name" "${HEADERS[@]}" \
  | python3 -c "
import sys, json
managed = set(sys.argv[1:])
d = json.load(sys.stdin)
if not isinstance(d.get('data'), list):
    sys.exit('Strapi list failed: ' + json.dumps(d.get('error') or d))
for s in d['data']:
    if s.get('uuid') not in managed:
        print(f\"  [UNMANAGED] {s.get('uuid')} — {s.get('name')} (documentId={s.get('documentId')})\")
" "${MANAGED_UUIDS[@]}"

echo ""
echo "Done. Created=$CREATED Updated=$UPDATED Skipped=$SKIPPED"
if [[ "$APPLY" = false ]]; then
  echo "(dry-run — re-run with --apply to make changes)"
fi
