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

strapi_get_by_uuid() {
  local uuid="$1"
  curl -sg --globoff "${STRAPI_URL}/api/services?filters[uuid][\$eq]=${uuid}" "${HEADERS[@]}" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); items=d.get('data',[]); print(items[0]['documentId'] if items else '')" 2>/dev/null
}

strapi_post() {
  local payload="$1"
  curl -s -X POST "${STRAPI_URL}/api/services" "${HEADERS[@]}" -d "$payload"
}

strapi_put() {
  local id="$1" payload="$2"
  curl -s -X PUT "${STRAPI_URL}/api/services/${id}" "${HEADERS[@]}" -d "$payload"
}

json_escape() {
  python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" <<< "$1"
}

# ── chart definitions ─────────────────────────────────────────────────────────
# Each entry: "chart_dir|uuid|display_name|description_markdown"
# Description is auto-generated from Chart.yaml if not listed here.

declare -A DESCRIPTIONS
DESCRIPTIONS[radicale]="## What is Radicale?\n\nRadicale is a lightweight, open-source **CalDAV and CardDAV server** for self-hosting calendars and contacts.\n\n* Sync calendars and contacts across all devices via CalDAV/CardDAV\n* IMAP-authenticated — no separate user database needed\n* Minimal resource footprint, no dedicated database engine required\n* Full data ownership: no third-party cloud involved"

DESCRIPTIONS[matomo]="## What is Matomo?\n\nMatomo is an open-source **web analytics platform** — a GDPR-friendly, self-hosted alternative to Google Analytics.\n\n* Track visitors, referrers, and page views without third-party data sharing\n* Heatmaps, session recording, goal and conversion tracking\n* 100% data ownership: everything stays in your own database\n* Compatible with most tag managers and CMS platforms"

DESCRIPTIONS[kurrier]="## What is Kurrier?\n\nKurrier is a **transactional email frontend** with a Redis-backed worker queue and PostgreSQL persistence.\n\n* Send transactional email via a clean API or SMTP relay\n* Queue-based delivery decouples request from send — no email lost under load\n* Real-time delivery, bounce, open, and click tracking\n* CNPG-managed PostgreSQL backend, fully self-hosted"

DESCRIPTIONS[wordpress]="## What is WordPress?\n\nWordPress is the world's most popular open-source **CMS**, powering over 40% of all websites.\n\n* Build any website — blog, portfolio, shop, or community — with no coding required\n* 60,000+ free plugins: SEO, e-commerce, forms, membership, and more\n* Block editor for visual drag-and-drop page building\n* MySQL-backed, pre-seeded and ready on first boot"

DESCRIPTIONS[mautic]="## What is Mautic?\n\nMautic is an open-source **marketing automation platform** — the self-hosted alternative to HubSpot or Mailchimp.\n\n* Automated email campaigns triggered by user behaviour or time\n* Lead scoring, dynamic segmentation, and CRM sync\n* Landing page and form builder with built-in conversion tracking\n* Full data ownership: every contact and event stays in your database"

DESCRIPTIONS[postal]="## What is Postal?\n\nPostal is a full-featured open-source **mail delivery platform** — a self-hosted alternative to SendGrid or Mailgun.\n\n* High-volume transactional and marketing email delivery\n* SMTP and HTTP API — drop-in compatible with most frameworks\n* Per-message delivery tracking: opens, clicks, bounces, spam complaints\n* Multi-tenant: manage multiple organizations and domains from one installation\n* RabbitMQ-backed queue for reliable async processing"

DESCRIPTIONS[slackbot]="## What is Slackbot?\n\nSlackbot is a **custom Slack integration service** that runs your bot logic inside your own cluster.\n\n* Define custom slash commands that trigger backend logic\n* Subscribe to Slack events: messages, reactions, file uploads\n* Bridge Slack and internal systems: trigger deploys, alerts, or data lookups from chat\n* Bot tokens managed as Kubernetes secrets — never exposed outside the cluster"

DESCRIPTIONS[moodle]="## What is Moodle?\n\nMoodle is the world's leading open-source **Learning Management System (LMS)**.\n\n* Deliver structured online courses with quizzes, assignments, and grading\n* Supports SCORM, video, forums, and interactive H5P content\n* Role-based access: students, teachers, and admins in one platform\n* Scales from small classrooms to universities with thousands of users"

DESCRIPTIONS[wikijs]="## What is Wiki.js?\n\nWiki.js is a modern, open-source **wiki platform** with a powerful editor and flexible storage backends.\n\n* Write documentation in Markdown, WYSIWYG, or raw HTML\n* Git-backed storage: your wiki content lives in a version-controlled repository\n* Granular access control: public pages, private spaces, or per-group permissions\n* Full-text search, page trees, and rich media embedding"

# ── main loop ─────────────────────────────────────────────────────────────────

echo "Strapi: $STRAPI_URL"
echo "Mode:   $([ "$APPLY" = true ] && echo apply || echo dry-run) $([ "$UPDATE" = true ] && echo '+update' || :)"
echo ""

CREATED=0
UPDATED=0
SKIPPED=0

for chart_dir in "$SCRIPT_DIR"/*/; do
  chart_name="$(basename "$chart_dir")"
  chart_yaml="$chart_dir/Chart.yaml"
  values_yaml="$chart_dir/values.yaml"

  [[ -f "$chart_yaml" ]] || continue

  # Derive uuid: prefer values.yaml uuid field, fall back to chart name
  uuid=""
  if [[ -f "$values_yaml" ]]; then
    uuid=$(yaml_field "$values_yaml" "uuid")
  fi
  # Skip placeholder uuids
  if [[ "$uuid" == "hbdftsrfed" || -z "$uuid" ]]; then
    uuid="$chart_name"
  fi

  display_name=$(yaml_field "$chart_yaml" "name")
  description_raw="${DESCRIPTIONS[$chart_name]:-}"

  if [[ -z "$description_raw" ]]; then
    chart_desc=$(yaml_field "$chart_yaml" "description")
    description_raw="## $display_name\n\n$chart_desc"
  fi

  existing_id=$(strapi_get_by_uuid "$uuid")

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
        payload="{\"data\":{\"name\":$(python3 -c "import json; print(json.dumps('$display_name'))"),\"desc\":${desc_json},\"uuid\":\"${uuid}\",\"stripeId\":\"${stripe_product_id}\"}}"
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
      name_json=$(python3 -c "import json; print(json.dumps('$display_name'))")
      payload="{\"data\":{\"name\":${name_json},\"desc\":${desc_json},\"stripeId\":\"${stripe_product_id}\",\"uuid\":\"${uuid}\",\"price\":0}}"
      result=$(strapi_post "$payload")
      new_id=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print((d.get('data') or {}).get('documentId') or (d.get('error') or {}).get('message','?'))" 2>/dev/null)
      echo "        → created documentId=$new_id"
      ((CREATED++)) || true
    fi
  fi
done

echo ""
echo "Done. Created=$CREATED Updated=$UPDATED Skipped=$SKIPPED"
if [[ "$APPLY" = false ]]; then
  echo "(dry-run — re-run with --apply to make changes)"
fi
