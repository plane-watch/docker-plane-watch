#!/usr/bin/env bash
# shellcheck shell=bash

set -euo pipefail

REPOSITORY_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# shellcheck disable=SC1090,SC1091
source "${REPOSITORY_ROOT}/rootfs/scripts/initialise.sh"

fail() {
  printf 'Initialisation timezone test: FAIL: %s\n' "$*" >&2
  exit 1
}

output_file=$(mktemp)
trap 'rm -f "$output_file"' EXIT

TZ='"Australia/Sydney"'
EXITCODE=0
prepare_timezone 2> "$output_file"
quoted_output=$(< "$output_file")
[[ "$TZ" == 'Australia/Sydney' ]] || fail 'a quoted valid timezone was not unwrapped'
[[ -z "$quoted_output" ]] || fail 'a quoted valid timezone produced a warning'
(( EXITCODE == 0 )) || fail 'a quoted valid timezone produced a fatal error'

TZ='Invalid/Timezone'
EXITCODE=0
prepare_timezone 2> "$output_file"
invalid_output=$(< "$output_file")
[[ "$TZ" == 'GMT' ]] || fail 'an invalid timezone did not fall back to GMT'
[[ "$invalid_output" == *'WARNING: TZ contains an invalid timezone: Invalid/Timezone; falling back to GMT'* ]] || \
  fail 'an invalid timezone did not produce the expected warning'
(( EXITCODE == 0 )) || fail 'an invalid timezone produced a fatal error'

printf 'Initialisation timezone regression test: PASS\n'
