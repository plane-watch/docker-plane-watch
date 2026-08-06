#!/command/with-contenv bash
# shellcheck shell=bash

set -uo pipefail

ENABLE_MLAT="${ENABLE_MLAT:-true}"
LAT="${LAT:-}"
LONG="${LONG:-}"
ALT="${ALT:-}"
MLAT_DATASOURCE="${MLAT_DATASOURCE:-}"
BEASTHOST="${BEASTHOST:-}"
BEASTPORT="${BEASTPORT:-30005}"
MLAT_INPUT_TYPE="${MLAT_INPUT_TYPE:-beast}"
MLATSERVERHOST="${MLATSERVERHOST:-127.0.0.1}"
MLATSERVERPORT="${MLATSERVERPORT:-12346}"
API_KEY="${API_KEY:-}"

ENABLE_MLAT="${ENABLE_MLAT//$'\r'/}"
LAT="${LAT//$'\r'/}"
LONG="${LONG//$'\r'/}"
ALT="${ALT//$'\r'/}"
MLAT_DATASOURCE="${MLAT_DATASOURCE//$'\r'/}"
BEASTHOST="${BEASTHOST//$'\r'/}"
BEASTPORT="${BEASTPORT//$'\r'/}"
MLAT_INPUT_TYPE="${MLAT_INPUT_TYPE//$'\r'/}"
MLATSERVERHOST="${MLATSERVERHOST//$'\r'/}"
MLATSERVERPORT="${MLATSERVERPORT//$'\r'/}"
API_KEY="${API_KEY//$'\r'/}"

is_true() {
  [[ "$1" =~ ^[Tt][Rr][Uu][Ee]$ ]]
}

format_host_port() {
  local host=$1
  local port=$2
  if [[ "$host" == *:* && "$host" != \[*\] ]]; then
    printf '[%s]:%s\n' "$host" "$port"
  else
    printf '%s:%s\n' "$host" "$port"
  fi
}

if ! is_true "$ENABLE_MLAT"; then
  printf '[mlat-client] MLAT is disabled\n'
  exec sleep infinity
fi

if [[ -z "$LAT" || -z "$LONG" || -z "$ALT" ]]; then
  printf '[mlat-client] MLAT is disabled because LAT, LONG, or ALT is missing\n'
  exec sleep infinity
fi

if [[ -z "$MLAT_DATASOURCE" ]]; then
  MLAT_DATASOURCE=$(format_host_port "$BEASTHOST" "$BEASTPORT")
fi
MLAT_SERVER=$(format_host_port "$MLATSERVERHOST" "$MLATSERVERPORT")

# Replace the wrapper with mlat-client so s6 supervises and signals the real process.
exec /opt/mlat-client/bin/mlat-client \
  --input-type "$MLAT_INPUT_TYPE" \
  --input-connect "$MLAT_DATASOURCE" \
  --lat "$LAT" \
  --lon "$LONG" \
  --alt "$ALT" \
  --results "beast,listen,30105" \
  --server "$MLAT_SERVER" \
  --user "$API_KEY" \
  2>&1
