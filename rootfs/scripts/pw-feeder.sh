#!/command/with-contenv bash
# shellcheck shell=bash

set -uo pipefail

ENABLE_MLAT="${ENABLE_MLAT:-true}"
LAT="${LAT:-}"
LONG="${LONG:-}"
ALT="${ALT:-}"

ENABLE_MLAT="${ENABLE_MLAT//$'\r'/}"
LAT="${LAT//$'\r'/}"
LONG="${LONG//$'\r'/}"
ALT="${ALT//$'\r'/}"

is_true() {
  [[ "$1" =~ ^[Tt][Rr][Uu][Ee]$ ]]
}

if is_true "$ENABLE_MLAT" && [[ -n "$LAT" && -n "$LONG" && -n "$ALT" ]]; then
  export NOMLAT=false
else
  export NOMLAT=true
fi

# Replace the wrapper so s6 supervises and signals the real process.
exec /usr/local/sbin/pw-feeder 2>&1
