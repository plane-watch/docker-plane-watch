#!/usr/bin/env bash
# shellcheck shell=bash

set -euo pipefail

if [[ -z "${HEALTHCHECK_SCRIPT:-}" ]]; then
  REPOSITORY_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
  HEALTHCHECK_SCRIPT="${REPOSITORY_ROOT}/rootfs/scripts/healthcheck.sh"
fi

export BEASTHOST=ultrafeeder
export BEASTPORT=30005
export MLATSERVERHOST=127.0.0.1
export MLATSERVERPORT=12346
export MLAT_DATASOURCE=
export ENABLE_MLAT=true
export LAT=1
export LONG=1
export ALT=1
export PW_BEAST_ENDPOINT=feed.push.plane.watch:12345
export PW_MLAT_ENDPOINT=feed.push.plane.watch:12346
export PW_NOMETRICS=true

# shellcheck disable=SC1090,SC1091
source "$HEALTHCHECK_SCRIPT"

INCLUDE_MLAT_IPV6=true

# Exact dual-stack DNS shape reported in issue #53.
getent() {
  [[ "$1" == "ahosts" ]] || return 1

  case "$2" in
    ultrafeeder)
      printf '%s\n' \
        'fd00:cafe:face:2::1d STREAM ultrafeeder' \
        'fd00:cafe:face:2::1d DGRAM' \
        'fd00:cafe:face:2::1d RAW' \
        '172.31.0.29 STREAM' \
        '172.31.0.29 DGRAM' \
        '172.31.0.29 RAW'
      ;;
    feed.push.plane.watch)
      printf '%s\n' '110.173.227.69 STREAM feed.push.plane.watch'
      ;;
    127.0.0.1)
      printf '%s\n' '127.0.0.1 STREAM localhost'
      ;;
    *)
      return 2
      ;;
  esac
}

# pw-feeder chooses IPv4 while mlat-client chooses IPv6, reproducing the
# happy-eyeballs split that originally caused issue #53.
ss() {
  if [[ "$*" == *'sport = :12346'* ]]; then
    printf '%s\n' \
      '0 0 127.0.0.1:12346 127.0.0.1:58300 users:(("pw-feeder",pid=70,fd=9))'
    return
  fi

  printf '%s\n' \
    '0 0 172.31.0.31:52356 172.31.0.29:30005 users:(("pw-feeder",pid=70,fd=5))' \
    '0 0 172.31.0.31:53064 110.173.227.69:12345 users:(("pw-feeder",pid=70,fd=8))' \
    '0 0 172.31.0.31:42932 110.173.227.69:12346 users:(("pw-feeder",pid=70,fd=10))' \
    '0 0 127.0.0.1:12346 127.0.0.1:58300 users:(("pw-feeder",pid=70,fd=9))' \
    '0 0 127.0.0.1:58300 127.0.0.1:12346 users:(("mlat-client",pid=103,fd=4))'

  if is_true "$INCLUDE_MLAT_IPV6"; then
    printf '%s\n' \
      '0 0 [fd00:cafe:face:2::1f]:35354 [fd00:cafe:face:2::1d]:30005 users:(("mlat-client",pid=103,fd=6))'
  fi
}

EXITCODE=0
if ! OUTPUT=$(run_healthchecks); then
  printf 'Issue #53 regression fixture unexpectedly failed:\n%s\n' "$OUTPUT" >&2
  exit 1
fi

if grep --quiet 'FAIL' <<< "$OUTPUT"; then
  printf 'Issue #53 regression fixture reported a failed check:\n%s\n' "$OUTPUT" >&2
  exit 1
fi

grep --fixed-strings --line-regexp --quiet \
  'pw-feeder connected to ultrafeeder:30005: OK' <<< "$OUTPUT"
grep --fixed-strings --line-regexp --quiet \
  'mlat-client connected to ultrafeeder:30005: OK' <<< "$OUTPUT"

# Negative control: the pw-feeder IPv4 connection must not mask a missing
# mlat-client IPv6 connection to the same hostname and port.
INCLUDE_MLAT_IPV6=false
EXITCODE=0
if check_connection_to_port \
  'mlat-client' \
  'ultrafeeder' \
  '30005' \
  'issue #53 negative control' >/dev/null; then
  printf 'Issue #53 negative control unexpectedly passed\n' >&2
  exit 1
fi
if (( EXITCODE != 1 )); then
  printf 'Issue #53 negative control did not set EXITCODE=1\n' >&2
  exit 1
fi

printf 'Issue #53 dual-stack regression test: PASS\n'
