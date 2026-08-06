#!/usr/bin/env bash

set -euo pipefail

# shellcheck disable=SC1090,SC1091
source "$(dirname "$0")/../.github/scripts/sanitize-issue.sh"

fail() {
  printf 'Issue sanitization test: FAIL: %s\n' "$*" >&2
  exit 1
}

first_key=123e4567-e89b-12d3-a456-426614174000
second_key=ABCDEF12-3456-7890-ABCD-EF1234567890
command -v uuidgen >/dev/null || fail 'uuidgen is not installed'
third_key=$(uuidgen)
input=$(printf 'API_KEY=%s\nmlat-client --user %s\ngenerated key: %s\nstandalone key: %s' \
  "$first_key" "$second_key" "$third_key" "$first_key")
expected=$(printf '%s\n%s\n%s\n%s' \
  'API_KEY=[REDACTED API KEY]' \
  'mlat-client --user [REDACTED API KEY]' \
  'generated key: [REDACTED API KEY]' \
  'standalone key: [REDACTED API KEY]')
actual=$(sanitize_issue_text "$input")

[[ "$actual" == "$expected" ]] || fail 'UUID-shaped keys were not redacted correctly'
[[ $(sanitize_issue_text 'API_KEY=already-redacted') == 'API_KEY=already-redacted' ]] || \
  fail 'safe text was changed'

coloured_text=$'\033[90m[pw-feeder]\033[0m connected'
[[ $(sanitize_issue_text "$coloured_text") == '[pw-feeder] connected' ]] || \
  fail 'ANSI colour sequences were not removed'

location_input=$(printf '%s\n%s\n%s' \
  'LAT=-31.9505 LONG=115.8605' \
  'mlat-client --lat -31.9505 --lon=115.8605' \
  'unrelated altitude: ALT=30m')
location_expected=$(printf '%s\n%s\n%s' \
  'LAT=[REDACTED] LONG=[REDACTED]' \
  'mlat-client --lat [REDACTED] --lon=[REDACTED]' \
  'unrelated altitude: ALT=30m')
[[ $(sanitize_issue_text "$location_input") == "$location_expected" ]] || \
  fail 'receiver coordinates were not redacted correctly'

event_path=$(mktemp)
trap 'rm -f "$event_path"' EXIT
jq \
  --null-input \
  --arg api_key "$first_key" \
  --arg generated_key "$third_key" \
  '{issue: {
    number: 53,
    title: ("Failure " + $api_key),
    body: ("API_KEY=" + $api_key + "\nSECOND_API_KEY=" + $generated_key + "\nLAT=-31.9505\nLONG=115.8605")
  }}' \
  > "$event_path"

GH_CALLS=()
gh() {
  GH_CALLS+=("$*")
}

export GH_TOKEN=test-token
export GITHUB_EVENT_NAME=issues
export GITHUB_EVENT_PATH=$event_path
export GITHUB_REPOSITORY=plane-watch/docker-plane-watch

main >/dev/null

combined_calls=${GH_CALLS[*]}
[[ "$combined_calls" != *"$first_key"* ]] || fail 'the API key was passed to the GitHub API'
[[ "$combined_calls" != *"$third_key"* ]] || fail 'the generated API key was passed to the GitHub API'
[[ "$combined_calls" == *'API_KEY=[REDACTED API KEY]'* ]] || fail 'the issue body was not redacted'
[[ "$combined_calls" == *'SECOND_API_KEY=[REDACTED API KEY]'* ]] || \
  fail 'the generated API key was not redacted from the issue body'
[[ "$combined_calls" == *'LAT=[REDACTED]'* ]] || fail 'LAT was not redacted from the issue body'
[[ "$combined_calls" == *'LONG=[REDACTED]'* ]] || fail 'LONG was not redacted from the issue body'
[[ "$combined_calls" == *'Failure [REDACTED API KEY]'* ]] || fail 'the issue title was not redacted'
[[ ${#GH_CALLS[@]} -eq 2 ]] || fail 'the issue update and warning comment were not both requested'

printf 'Issue sanitization test: PASS\n'
