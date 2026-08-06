#!/command/with-contenv bash
# shellcheck shell=bash

set -uo pipefail

EXITCODE=0

TZ="${TZ:-GMT}"
BEASTHOST="${BEASTHOST:-}"
BEASTPORT="${BEASTPORT:-30005}"
API_KEY="${API_KEY:-}"
ENABLE_MLAT="${ENABLE_MLAT:-true}"
LAT="${LAT:-}"
LONG="${LONG:-}"
ALT="${ALT:-}"
MLATSERVERPORT="${MLATSERVERPORT:-12346}"
PW_METRICSPORT="${PW_METRICSPORT:-2112}"
PW_NOMETRICS="${PW_NOMETRICS:-false}"
IMAGE_REVISION="${IMAGE_REVISION:-unknown}"

TZ="${TZ//$'\r'/}"
BEASTHOST="${BEASTHOST//$'\r'/}"
BEASTPORT="${BEASTPORT//$'\r'/}"
API_KEY="${API_KEY//$'\r'/}"
ENABLE_MLAT="${ENABLE_MLAT//$'\r'/}"
LAT="${LAT//$'\r'/}"
LONG="${LONG//$'\r'/}"
ALT="${ALT//$'\r'/}"
MLATSERVERPORT="${MLATSERVERPORT//$'\r'/}"
PW_METRICSPORT="${PW_METRICSPORT//$'\r'/}"
PW_NOMETRICS="${PW_NOMETRICS//$'\r'/}"
IMAGE_REVISION="${IMAGE_REVISION//$'\r'/}"

is_true() {
  [[ "$1" =~ ^[Tt][Rr][Uu][Ee]$ ]]
}

is_false() {
  [[ "$1" =~ ^[Ff][Aa][Ll][Ss][Ee]$ ]]
}

is_valid_port() {
  local port=$1
  [[ "$port" =~ ^[0-9]{1,5}$ ]] && (( 10#$port >= 1 && 10#$port <= 65535 ))
}

error() {
  printf '[init] ERROR: %s\n' "$*" >&2
  EXITCODE=1
}

warning() {
  printf '[init] WARNING: %s\n' "$*" >&2
}

printf '[init] Setting timezone to %s...\n' "$TZ"

# Set up timezone
if [[ "$TZ" == /* || "$TZ" == *'..'* || ! -e "/usr/share/zoneinfo/$TZ" ]]; then
  error "TZ contains an invalid timezone: $TZ"
elif ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && printf '%s\n' "$TZ" > /etc/timezone; then
  :
else
  error "could not configure timezone: $TZ"
fi

printf '[init] Checking environment variables...\n'

# Check the API key before enabling shell tracing so it can never appear in
# debug output. The value is not referenced again in this script.
if [[ -z "$API_KEY" ]]; then
  error "API_KEY environment variable is not set"
fi

if is_true "${DEBUG_LOGGING:-false}"; then
  set -x
fi

# Check the remaining required configuration.
if [[ -z "$BEASTHOST" ]]; then
  error "BEASTHOST environment variable is not set"
fi

# Validate the ports consumed by the services and health check.
if ! is_valid_port "$BEASTPORT"; then
  error "BEASTPORT must be an integer between 1 and 65535"
fi
if ! is_valid_port "$MLATSERVERPORT"; then
  error "MLATSERVERPORT must be an integer between 1 and 65535"
fi
if ! is_true "${PW_NOMETRICS:-false}" && ! is_valid_port "$PW_METRICSPORT"; then
  error "PW_METRICSPORT must be an integer between 1 and 65535"
fi

if ! is_true "$ENABLE_MLAT" && ! is_false "$ENABLE_MLAT"; then
  error "ENABLE_MLAT must be either true or false"
fi
if ! is_true "$PW_NOMETRICS" && ! is_false "$PW_NOMETRICS"; then
  error "PW_NOMETRICS must be either true or false"
fi

# Missing coordinates disable MLAT without preventing ADS-B feeding.
if is_true "$ENABLE_MLAT"; then
  MISSING_MLAT_VARIABLES=()
  [[ -n "$LAT" ]] || MISSING_MLAT_VARIABLES+=(LAT)
  [[ -n "$LONG" ]] || MISSING_MLAT_VARIABLES+=(LONG)
  [[ -n "$ALT" ]] || MISSING_MLAT_VARIABLES+=(ALT)
  if (( ${#MISSING_MLAT_VARIABLES[@]} > 0 )); then
    MISSING_MLAT_TEXT=$(IFS=,; printf '%s' "${MISSING_MLAT_VARIABLES[*]}")
    warning "MLAT will remain disabled because these variables are missing: $MISSING_MLAT_TEXT"
  fi
fi

# If any errors above are fatal, don't proceed starting the container
if (( EXITCODE != 0 )); then
  exit "$EXITCODE"
fi

printf '[init] Image revision: %s\n' "$IMAGE_REVISION"
printf '[init] Completed\n'

exit "$EXITCODE"
