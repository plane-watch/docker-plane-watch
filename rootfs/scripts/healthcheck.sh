#!/command/with-contenv bash
# shellcheck shell=bash

set -uo pipefail

# Both monitored services run as nobody. In this container, ss only exposes
# process metadata for sockets owned by the caller's effective user, so match
# the service user before performing the process-aware connection checks.
if (( EUID == 0 )); then
  exec /command/s6-setuidgid nobody /usr/bin/bash "$0" "$@"
fi

EXITCODE=0
METRICS_STATE=unknown
METRICS_OUTPUT=

BEASTHOST="${BEASTHOST:-}"
BEASTPORT="${BEASTPORT:-30005}"
MLATSERVERHOST="${MLATSERVERHOST:-127.0.0.1}"
MLATSERVERPORT="${MLATSERVERPORT:-12346}"
MLAT_DATASOURCE="${MLAT_DATASOURCE:-}"
ENABLE_MLAT="${ENABLE_MLAT:-true}"
LAT="${LAT:-}"
LONG="${LONG:-}"
ALT="${ALT:-}"
PW_BEAST_ENDPOINT="${PW_BEAST_ENDPOINT:-feed.push.plane.watch:12345}"
PW_MLAT_ENDPOINT="${PW_MLAT_ENDPOINT:-feed.push.plane.watch:12346}"
PW_METRICSHOST="${PW_METRICSHOST:-0.0.0.0}"
PW_METRICSPORT="${PW_METRICSPORT:-2112}"
PW_NOMETRICS="${PW_NOMETRICS:-false}"

BEASTHOST="${BEASTHOST//$'\r'/}"
BEASTPORT="${BEASTPORT//$'\r'/}"
MLATSERVERHOST="${MLATSERVERHOST//$'\r'/}"
MLATSERVERPORT="${MLATSERVERPORT//$'\r'/}"
MLAT_DATASOURCE="${MLAT_DATASOURCE//$'\r'/}"
ENABLE_MLAT="${ENABLE_MLAT//$'\r'/}"
LAT="${LAT//$'\r'/}"
LONG="${LONG//$'\r'/}"
ALT="${ALT//$'\r'/}"
PW_BEAST_ENDPOINT="${PW_BEAST_ENDPOINT//$'\r'/}"
PW_MLAT_ENDPOINT="${PW_MLAT_ENDPOINT//$'\r'/}"
PW_METRICSHOST="${PW_METRICSHOST//$'\r'/}"
PW_METRICSPORT="${PW_METRICSPORT//$'\r'/}"
PW_NOMETRICS="${PW_NOMETRICS//$'\r'/}"

is_true() {
  [[ "$1" =~ ^[Tt][Rr][Uu][Ee]$ ]]
}

is_valid_port() {
  local port=$1
  [[ "$port" =~ ^[0-9]{1,5}$ ]] && (( 10#$port >= 1 && 10#$port <= 65535 ))
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

load_metrics() {
  local metrics_host metrics_endpoint

  if [[ "$METRICS_STATE" != "unknown" ]]; then
    return
  fi

  if is_true "$PW_NOMETRICS"; then
    METRICS_STATE=disabled
    return
  fi

  if ! is_valid_port "$PW_METRICSPORT"; then
    METRICS_STATE=invalid-port
    return
  fi

  case "$PW_METRICSHOST" in
    "" | 0.0.0.0)
      metrics_host=127.0.0.1
      ;;
    :: | "[::]")
      metrics_host=::1
      ;;
    *)
      metrics_host=$PW_METRICSHOST
      ;;
  esac
  metrics_endpoint=$(format_host_port "$metrics_host" "$PW_METRICSPORT")

  if METRICS_OUTPUT=$(curl \
    --connect-timeout 3 \
    --fail \
    --max-time 5 \
    --silent \
    "http://${metrics_endpoint}/metrics" \
    2>/dev/null); then
    METRICS_STATE=available
  else
    METRICS_STATE=unavailable
  fi
}

check_atc_status() {
  local protocol=$1
  local description=$2
  local metric_name metric_value

  printf '%s: ' "$description"
  load_metrics

  case "$METRICS_STATE" in
    disabled)
      printf 'N/A (metrics disabled)\n'
      return 0
      ;;
    invalid-port)
      printf 'FAIL (invalid metrics port)\n'
      EXITCODE=1
      return 1
      ;;
    unavailable)
      printf 'FAIL (metrics endpoint unavailable)\n'
      EXITCODE=1
      return 1
      ;;
  esac

  metric_name="pwfeeder_atc_feed_healthy{protocol=\"${protocol}\"}"
  metric_value=$(awk -v name="$metric_name" '$1 == name { print $2; exit }' <<< "$METRICS_OUTPUT")
  if [[ "$metric_value" == "1" ]]; then
    printf 'OK\n'
    return 0
  fi

  if [[ -z "$metric_value" ]]; then
    printf 'FAIL (metric unavailable)\n'
  else
    printf 'FAIL\n'
  fi
  EXITCODE=1
  return 1
}

resolve_ips() {
  local host=$1
  [[ -n "$host" ]] || return 1
  getent ahosts "$host" 2>/dev/null | awk '{ sub(/^::ffff:/, "", $1); print $1 }' | sort -u
}

extract_host() {
  local endpoint=$1

  if [[ "$endpoint" =~ ^\[([^]]+)\]:[0-9]+$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  elif [[ "$endpoint" =~ ^([^:]+):[0-9]+$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  else
    printf '%s\n' "$endpoint"
  fi
}

extract_port() {
  local endpoint=$1
  if [[ "$endpoint" =~ ^\[[^]]+\]:([0-9]+)$ || "$endpoint" =~ ^[^:]+:([0-9]+)$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  fi
}

extract_ip() {
  local peer=$1
  local ip
  ip=$(extract_host "$peer")
  printf '%s\n' "${ip#::ffff:}"
}

check_connection_to_port() {
  local process=$1
  local host=$2
  local port=$3
  local description=$4
  local valid_ips peer_addresses peer peer_ip peer_port

  printf '%s: ' "$description"

  if ! is_valid_port "$port"; then
    printf 'FAIL (missing or invalid port)\n'
    EXITCODE=1
    return 1
  fi

  valid_ips=$(resolve_ips "$host")

  if [[ -z "$valid_ips" ]]; then
    printf 'FAIL (could not resolve %s)\n' "${host:-<empty host>}"
    EXITCODE=1
    return 1
  fi

  peer_addresses=$(
    ss -Htnp state established 2>/dev/null |
      awk -v process="\"${process}\"" 'index($0, process) { print $(NF - 1) }'
  )

  while IFS= read -r peer; do
    [[ -n "$peer" ]] || continue

    peer_ip=$(extract_ip "$peer")
    peer_port=$(extract_port "$peer")

    if grep --fixed-strings --line-regexp --quiet "$peer_ip" <<< "$valid_ips" && [[ "$peer_port" == "$port" ]]; then
      printf 'OK\n'
      return 0
    fi
  done <<< "$peer_addresses"

  printf 'FAIL\n'
  EXITCODE=1
  return 1
}

check_listening_on_sport() {
  local process=$1
  local sport=$2
  local description=$3

  printf '%s: ' "$description"

  if ! is_valid_port "$sport"; then
    printf 'FAIL (missing or invalid local port)\n'
    EXITCODE=1
    return 1
  fi

  if ss -Htnp state established sport = ":${sport}" 2>/dev/null |
    grep --fixed-strings --quiet "\"${process}\""; then
    printf 'OK\n'
    return 0
  fi

  printf 'FAIL\n'
  EXITCODE=1
  return 1
}

check_atc_status "adsb" "ATC reports healthy ADS-B feed"

check_connection_to_port \
  "pw-feeder" \
  "$BEASTHOST" \
  "$BEASTPORT" \
  "pw-feeder connected to $(format_host_port "$BEASTHOST" "$BEASTPORT")"

PW_BEAST_HOST=$(extract_host "$PW_BEAST_ENDPOINT")
PW_BEAST_PORT=$(extract_port "$PW_BEAST_ENDPOINT")

check_connection_to_port \
  "pw-feeder" \
  "$PW_BEAST_HOST" \
  "$PW_BEAST_PORT" \
  "pw-feeder connected to $PW_BEAST_ENDPOINT"

MLAT_ACTIVE=false
if is_true "$ENABLE_MLAT" && [[ -n "$LAT" && -n "$LONG" && -n "$ALT" ]]; then
  MLAT_ACTIVE=true
fi

if is_true "$MLAT_ACTIVE"; then
  check_atc_status "mlat" "ATC reports healthy MLAT feed"

  if [[ -z "$MLAT_DATASOURCE" ]]; then
    MLAT_DATASOURCE=$(format_host_port "$BEASTHOST" "$BEASTPORT")
  fi
  MLAT_DATA_HOST=$(extract_host "$MLAT_DATASOURCE")
  MLAT_DATA_PORT=$(extract_port "$MLAT_DATASOURCE")

  check_connection_to_port \
    "mlat-client" \
    "$MLAT_DATA_HOST" \
    "$MLAT_DATA_PORT" \
    "mlat-client connected to $MLAT_DATASOURCE"

  check_connection_to_port \
    "mlat-client" \
    "$MLATSERVERHOST" \
    "$MLATSERVERPORT" \
    "mlat-client connected to pw-feeder ($(format_host_port "$MLATSERVERHOST" "$MLATSERVERPORT"))"

  check_listening_on_sport \
    "pw-feeder" \
    "$MLATSERVERPORT" \
    "pw-feeder accepted the mlat-client connection"

  PW_MLAT_HOST=$(extract_host "$PW_MLAT_ENDPOINT")
  PW_MLAT_PORT=$(extract_port "$PW_MLAT_ENDPOINT")

  check_connection_to_port \
    "pw-feeder" \
    "$PW_MLAT_HOST" \
    "$PW_MLAT_PORT" \
    "pw-feeder connected to $PW_MLAT_ENDPOINT"
fi

exit "$EXITCODE"
