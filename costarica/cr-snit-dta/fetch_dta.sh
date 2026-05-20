#!/usr/bin/env bash
# fetch_dta.sh — download the latest "División Territorial Administrativa"
# PDF from Costa Rica's SNIT, convert it to text, and (if present) hand it
# to parse.sh.
#
# Cache layout (under the skill dir):
#   cache/<year>/dta-<year>.pdf
#   cache/<year>/dta-<year>.txt
#   cache/<year>/parsed/                # populated by parse.sh
#   cache/index.json                    # raw API response, for inspection
#
# Usage:
#   ./fetch_dta.sh                  # latest year, idempotent (skip if cached)
#   ./fetch_dta.sh --year 2023      # specific year
#   ./fetch_dta.sh --force          # re-download even if cached
#   ./fetch_dta.sh --list           # print all DTA years SNIT publishes, then exit
#   ./fetch_dta.sh --no-parse       # stop after .txt, do not run parse.sh

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="${SKILL_DIR}/cache"
API_URL="https://www.snitcr.go.cr/consultar_DTA_documentos_generales"
REFERER="https://www.snitcr.go.cr/biblioteca_DTA"

YEAR=""
FORCE=0
LIST_ONLY=0
RUN_PARSE=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --year)     YEAR="$2"; shift 2 ;;
    --force)    FORCE=1; shift ;;
    --list)     LIST_ONLY=1; shift ;;
    --no-parse) RUN_PARSE=0; shift ;;
    -h|--help)
      sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

for bin in curl python3 pdftotext; do
  command -v "$bin" >/dev/null 2>&1 || { echo "missing required tool: $bin" >&2; exit 1; }
done

mkdir -p "$CACHE_DIR"
INDEX_JSON="${CACHE_DIR}/index.json"

echo "==> POST ${API_URL}"
curl -sSL --fail --max-time 60 -X POST "$API_URL" \
  -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
  -H 'X-Requested-With: XMLHttpRequest' \
  -H "Referer: ${REFERER}" \
  --data-urlencode 'anio=TODOS' \
  --data-urlencode 'tipo_documento=TODOS' \
  -o "$INDEX_JSON"

# Filter to "División Territorial Administrativa <year>" rows, pick year+url.
# Tab-separated because the URL contains spaces.
IFS=$'\t' read -r PICKED_YEAR PICKED_URL PICKED_FECHA < <(YEAR_ARG="$YEAR" LIST_ONLY="$LIST_ONLY" python3 - "$INDEX_JSON" <<'PY'
import json, os, sys, re
path = sys.argv[1]
year_arg = os.environ.get("YEAR_ARG", "").strip()
list_only = os.environ.get("LIST_ONLY") == "1"
with open(path, encoding="utf-8") as f:
    payload = json.load(f)
rows = [r for r in payload.get("data", [])
        if r.get("titulo", "").startswith("División Territorial Administrativa")]
# Each row has anio (string) and url; sort descending by integer year.
rows.sort(key=lambda r: int(r["anio"]), reverse=True)
if list_only:
    for r in rows:
        print(f"{r['anio']}\t{r['fecha']}\t{r['url']}", file=sys.stderr)
    sys.exit(0)
if year_arg:
    rows = [r for r in rows if r["anio"] == year_arg]
    if not rows:
        print(f"no DTA document found for year {year_arg!r}", file=sys.stderr)
        sys.exit(3)
picked = rows[0]
print(f"{picked['anio']}\t{picked['url']}\t{picked['fecha']}")
PY
)

if [[ "$LIST_ONLY" == "1" ]]; then
  exit 0
fi

if [[ -z "${PICKED_YEAR:-}" ]]; then
  echo "failed to pick a DTA document from API response" >&2
  exit 4
fi

echo "==> picked: DTA ${PICKED_YEAR} (published ${PICKED_FECHA})"

YEAR_DIR="${CACHE_DIR}/${PICKED_YEAR}"
PDF_PATH="${YEAR_DIR}/dta-${PICKED_YEAR}.pdf"
TXT_PATH="${YEAR_DIR}/dta-${PICKED_YEAR}.txt"
mkdir -p "$YEAR_DIR"

ENCODED_URL=$(python3 - "$PICKED_URL" <<'PY'
import sys
from urllib.parse import urlsplit, urlunsplit, quote
u = sys.argv[1]
p = urlsplit(u)
print(urlunsplit((p.scheme, p.netloc, quote(p.path), p.query, p.fragment)))
PY
)

if [[ -s "$PDF_PATH" && "$FORCE" == "0" ]]; then
  echo "==> PDF already cached: $PDF_PATH (use --force to re-download)"
else
  echo "==> downloading PDF -> $PDF_PATH"
  curl -sSL --fail --max-time 180 -o "$PDF_PATH" "$ENCODED_URL"
fi

# Quick sanity check: file must start with %PDF.
head -c 4 "$PDF_PATH" | grep -q '^%PDF' || { echo "downloaded file is not a PDF" >&2; exit 5; }

if [[ -s "$TXT_PATH" && "$FORCE" == "0" && ! "$PDF_PATH" -nt "$TXT_PATH" ]]; then
  echo "==> TXT already up-to-date: $TXT_PATH"
else
  echo "==> converting PDF -> TXT (pdftotext -layout)"
  pdftotext -layout -enc UTF-8 "$PDF_PATH" "$TXT_PATH"
fi

echo "==> PDF: $PDF_PATH"
echo "==> TXT: $TXT_PATH"

PARSER="${SKILL_DIR}/parse.sh"
if [[ "$RUN_PARSE" == "1" && -x "$PARSER" ]]; then
  PARSED_DIR="${YEAR_DIR}/parsed"
  mkdir -p "$PARSED_DIR"
  echo "==> running parse.sh"
  # parse.sh contract: parse.sh <txt-path> <out-dir> <year>
  "$PARSER" "$TXT_PATH" "$PARSED_DIR" "$PICKED_YEAR"
  echo "==> parsed output: $PARSED_DIR"
elif [[ "$RUN_PARSE" == "1" ]]; then
  echo "==> parse.sh not present (or not executable); skipping parse step"
fi
