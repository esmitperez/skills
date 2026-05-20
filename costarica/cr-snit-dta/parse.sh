#!/usr/bin/env bash
# parse.sh — extract cantones.csv and distritos.csv from a DTA .txt
#
# Driver contract (called by fetch_dta.sh):
#   parse.sh <txt-path> <out-dir> <year>
#
# Outputs:
#   <out-dir>/cantones.csv    prov_id,canton_id,name
#   <out-dir>/distritos.csv   prov_id,canton_id,dist_id,codigo,name
#
# Adapted from the user's notebook cells (removed leading "!" Jupyter prefix
# and parameterized hard-coded ./data/orig/territorio/ paths).

set -euo pipefail

TXT_PATH="${1:?usage: parse.sh <txt-path> <out-dir> <year>}"
OUT_DIR="${2:?usage: parse.sh <txt-path> <out-dir> <year>}"
YEAR="${3:-unknown}"

mkdir -p "$OUT_DIR"

CANTONES="${OUT_DIR}/cantones.csv"
DISTRITOS="${OUT_DIR}/distritos.csv"

echo "==> parse.sh (year=$YEAR)"
echo "    txt: $TXT_PATH"
echo "    out: $OUT_DIR"

# ---- CANTONES ----
# Source rows look like:  "                CANTÓN 101: SAN JOSÉ"
echo "CANTONES"
echo "prov_id,canton_id,name" > "$CANTONES"
grep -e "CANTÓN [0-9][0-9][0-9]" "$TXT_PATH" \
  | sed -E -e 's/CANTÓN[[:space:]]*([0-9])([0-9][0-9]):[[:space:]]*(.+)/\1,\2,\3/gi' \
  | sed -E -e 's/^[[:space:]]+//' \
  >> "$CANTONES"
wc -l "$CANTONES"

# ---- DISTRITOS ----
# Source rows look like:  "101 01 CARMEN: 1,49 km2. ..."
# "Desierto" handling preserves the prior name of districts that were
# upgraded into cantons.
echo "DISTRITOS"
echo "prov_id,canton_id,dist_id,codigo,name" > "$DISTRITOS"

sed -E \
    -e 's/Se declara desierto, producto de que el anterior distrito de /<</gi' \
    -e 's/ pasa a ser el cantón N/>>/gi' \
    -e 's/<<(.+)>>/DESIERTO - ANTES \1/g' \
    "$TXT_PATH" \
  | tr '[:lower:]' '[:upper:]' \
  | env LC_ALL=en_US.UTF-8 grep -E -o "^[1234567][0-9][0-9]\s?[0-9][0-9](\s[A-ZÁÉÍÓÚÜÑ\-]+)+" \
  | cut -f1 -d':' \
  | sed -E -e 's/([0-9])([0-9][0-9]) ([0-9][0-9]) (.*)/\1,\2,\3,\4/' \
  | sed -E -e 's/([0-9])([0-9][0-9])\s?([0-9][0-9]) (.+)/\1,\2,\3,\4/g' \
  | sed -E -e 's/([0-9]),([0-9][0-9]),([0-9][0-9]),(.+)/\1,\2,\3,\1\2\3,\4/g' \
  >> "$DISTRITOS"

head -2 "$DISTRITOS"
wc -l "$DISTRITOS"
echo "Alajuela rows: $(grep -c ALAJUELA "$DISTRITOS" || true)"
