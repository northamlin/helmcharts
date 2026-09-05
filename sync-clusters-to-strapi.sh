#!/usr/bin/env bash
# Collapse the Strapi cluster registry down to the single cluster we host on.
#
# Idempotent and re-runnable:
#   1. upsert the Domain   (by name)
#   2. upsert the Cluster  (by name) and attach the domain
#   3. attach EVERY service to that cluster
#   4. delete every other cluster  -- last, so step 3 never orphans a relation
#
# Usage:
#   ./sync-clusters-to-strapi.sh                 # dry-run, shows what would change
#   ./sync-clusters-to-strapi.sh --apply         # make the changes
#   ./sync-clusters-to-strapi.sh --apply --keep-others   # skip step 4
#
# Env vars (override defaults):
#   STRAPI_URL     default: http://content.robots.beer
#   STRAPI_TOKEN   required for --apply (reads on clusters/services are public)
#   CLUSTER_NAME   default: eu-upcloud-1
#   CLUSTER_DOMAIN default: eu-up.apps.robots.beer

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load .env if present
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.env"
fi

STRAPI_URL="${STRAPI_URL:-http://content.robots.beer}"
STRAPI_TOKEN="${STRAPI_TOKEN:-}"
CLUSTER_NAME="${CLUSTER_NAME:-eu-upcloud-1}"
CLUSTER_DOMAIN="${CLUSTER_DOMAIN:-eu-up.apps.robots.beer}"
APPLY=false
KEEP_OTHERS=false

for arg in "$@"; do
  case $arg in
    --apply)       APPLY=true ;;
    --keep-others) KEEP_OTHERS=true ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

if [[ "$APPLY" = true && -z "$STRAPI_TOKEN" ]]; then
  echo "ERROR: STRAPI_TOKEN is not set (required for --apply)." >&2
  exit 1
fi

HEADERS=(-H "Content-Type: application/json")
[[ -n "$STRAPI_TOKEN" ]] && HEADERS+=(-H "Authorization: Bearer $STRAPI_TOKEN")

CLUSTER_DESC="## ${CLUSTER_NAME}

Our EU cluster on UpCloud. Every hosted service runs here and is reachable at
\`<servicename>.${CLUSTER_DOMAIN}\`.

* Location: UpCloud, EU
* GDPR compliant infrastructure
* Kubernetes-managed workloads, deployed via GitOps
* Automatic TLS on every service"

# ── helpers ──────────────────────────────────────────────────────────────────

api_get() { curl -sg --globoff "${STRAPI_URL}$1" "${HEADERS[@]}"; }

api_write() {
  local method="$1" path="$2" payload="${3:-}"
  if [[ -n "$payload" ]]; then
    curl -s -X "$method" "${STRAPI_URL}${path}" "${HEADERS[@]}" -d "$payload"
  else
    curl -s -X "$method" "${STRAPI_URL}${path}" "${HEADERS[@]}"
  fi
}

# documentId of the first entry matching filters[<field>][$eq]=<value>, or ""
find_doc_id() {
  local plural="$1" field="$2" value="$3"
  api_get "/api/${plural}?filters[${field}][\$eq]=${value}" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); i=d.get('data') or []; print(i[0]['documentId'] if i else '')" 2>/dev/null
}

doc_id_of() {
  python3 -c "import sys,json; d=json.load(sys.stdin); print((d.get('data') or {}).get('documentId') or (d.get('error') or {}).get('message','ERROR'))" 2>/dev/null
}

json_str() { python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))"; }

echo "Strapi:  $STRAPI_URL"
echo "Cluster: $CLUSTER_NAME  ($CLUSTER_DOMAIN)"
echo "Mode:    $([ "$APPLY" = true ] && echo apply || echo dry-run)$([ "$KEEP_OTHERS" = true ] && echo ' +keep-others' || :)"
echo ""

# ── 1. domain ────────────────────────────────────────────────────────────────

# The Domain collection is optional here. A Strapi build that predates the Domain
# content type answers 404 on /api/domains; the cluster's own `domain` string field is
# what the deploy wizard falls back to when /api/our/domain comes back empty, so the
# flow works either way. Re-run this script after a hosts-backend rollout to attach it.
DOMAIN_ID=""
DOMAIN_STATUS="$(curl -sg --globoff -o /dev/null -w '%{http_code}' "${STRAPI_URL}/api/domains" "${HEADERS[@]}")"
if [[ "$DOMAIN_STATUS" == "404" ]]; then
  echo "[WARN]   /api/domains -> 404; this Strapi build has no Domain content type."
  echo "         Skipping the Domain entry. cluster.domain=$CLUSTER_DOMAIN still drives"
  echo "         the deploy wizard. Re-run after the next hosts-backend rollout."
else
  DOMAIN_ID="$(find_doc_id domains name "$CLUSTER_DOMAIN")"
  if [[ -n "$DOMAIN_ID" ]]; then
    echo "[SKIP]   domain $CLUSTER_DOMAIN (id=$DOMAIN_ID) — already exists"
  else
    echo "[CREATE] domain $CLUSTER_DOMAIN"
    if [[ "$APPLY" = true ]]; then
      DOMAIN_ID=$(api_write POST /api/domains "{\"data\":{\"name\":\"${CLUSTER_DOMAIN}\"}}" | doc_id_of)
      echo "         → documentId=$DOMAIN_ID"
    fi
  fi
fi

# ── 2. cluster ───────────────────────────────────────────────────────────────

CLUSTER_ID="$(find_doc_id clusters name "$CLUSTER_NAME")"
DESC_JSON="$(printf '%s' "$CLUSTER_DESC" | json_str)"
CLUSTER_PAYLOAD="{\"data\":{\"name\":\"${CLUSTER_NAME}\",\"domain\":\"${CLUSTER_DOMAIN}\",\"location\":\"UpCloud, EU\",\"tier\":\"tier1\",\"active\":true,\"support\":\"support@robots.beer\",\"desc\":${DESC_JSON}$([ -n "${DOMAIN_ID:-}" ] && echo ",\"domains\":{\"set\":[\"${DOMAIN_ID}\"]}" || :)}}"

if [[ -n "$CLUSTER_ID" ]]; then
  echo "[UPDATE] cluster $CLUSTER_NAME (id=$CLUSTER_ID)"
  [[ "$APPLY" = true ]] && api_write PUT "/api/clusters/${CLUSTER_ID}" "$CLUSTER_PAYLOAD" | doc_id_of | sed 's/^/         → /'
else
  echo "[CREATE] cluster $CLUSTER_NAME"
  if [[ "$APPLY" = true ]]; then
    CLUSTER_ID=$(api_write POST /api/clusters "$CLUSTER_PAYLOAD" | doc_id_of)
    echo "         → documentId=$CLUSTER_ID"
  fi
fi

# ── 3. attach every service ──────────────────────────────────────────────────

echo ""
LINKED=0
while IFS=$'\t' read -r svc_id svc_name svc_clusters; do
  [[ -z "$svc_id" ]] && continue
  if [[ "$svc_clusters" == *"$CLUSTER_NAME"* && "$svc_clusters" != *","* ]]; then
    echo "[SKIP]   service $svc_name — already only on $CLUSTER_NAME"
    continue
  fi
  echo "[LINK]   service $svc_name (id=$svc_id) — was: ${svc_clusters:-none}"
  if [[ "$APPLY" = true ]]; then
    api_write PUT "/api/services/${svc_id}" \
      "{\"data\":{\"cluster\":{\"set\":[\"${CLUSTER_ID}\"]}}}" >/dev/null
    ((LINKED++)) || true
  fi
done < <(api_get "/api/services?pagination[pageSize]=200&populate=cluster" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for s in d.get('data', []):
    cl = s.get('cluster') or []
    if isinstance(cl, dict):
        cl = [cl]
    print('\t'.join([s['documentId'], (s.get('name') or '')[:40], ','.join(c.get('name','') for c in cl)]))
")

# ── 4. drop the other clusters ───────────────────────────────────────────────

echo ""
DELETED=0
if [[ "$KEEP_OTHERS" = true ]]; then
  echo "[SKIP]   leaving other clusters in place (--keep-others)"
else
  while IFS=$'\t' read -r c_id c_name; do
    [[ -z "$c_id" || "$c_name" == "$CLUSTER_NAME" ]] && continue
    echo "[DELETE] cluster $c_name (id=$c_id)"
    if [[ "$APPLY" = true ]]; then
      api_write DELETE "/api/clusters/${c_id}" >/dev/null
      ((DELETED++)) || true
    fi
  done < <(api_get "/api/clusters?pagination[pageSize]=200" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for c in d.get('data', []):
    print('\t'.join([c['documentId'], c.get('name') or '']))
")
fi

echo ""
echo "Done. Linked=$LINKED Deleted=$DELETED"
if [[ "$APPLY" = false ]]; then
  echo "(dry-run — re-run with --apply to make changes)"
fi
