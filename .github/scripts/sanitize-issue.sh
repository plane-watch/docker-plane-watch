#!/usr/bin/env bash

set -euo pipefail

readonly API_KEY_PATTERN='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
readonly API_KEY_REPLACEMENT='[REDACTED API KEY]'

sanitize_issue_text() {
  local value=$1

  jq \
    --null-input \
    --raw-output \
    --arg value "$value" \
    --arg pattern "$API_KEY_PATTERN" \
    --arg replacement "$API_KEY_REPLACEMENT" \
    '$value
      | gsub("\u001b\\[[0-?]*[ -/]*[@-~]"; "")
      | gsub("(?i)(?<name>\\b(?:LAT|LONG)=)[-+]?[0-9]+(?:\\.[0-9]+)?"; "\(.name)[REDACTED]")
      | gsub("(?i)(?<flag>--(?:lat|lon)(?:=|\\s+))[-+]?[0-9]+(?:\\.[0-9]+)?"; "\(.flag)[REDACTED]")
      | gsub($pattern; $replacement)'
}

main() {
  local body
  local comment_id
  local event_name
  local api_key
  local -a api_keys=()
  local issue_number
  local sanitized_body
  local sanitized_title
  local title

  : "${GITHUB_EVENT_NAME:?GITHUB_EVENT_NAME must be set}"
  : "${GITHUB_EVENT_PATH:?GITHUB_EVENT_PATH must be set}"
  : "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY must be set}"
  : "${GH_TOKEN:?GH_TOKEN must be set}"

  event_name=$GITHUB_EVENT_NAME
  issue_number=$(jq --raw-output '.issue.number' "$GITHUB_EVENT_PATH")

  if [[ "$event_name" == issue_comment ]]; then
    if [[ $(jq --raw-output '.issue.pull_request != null' "$GITHUB_EVENT_PATH") == true ]]; then
      printf 'Skipping a pull-request comment.\n'
      return
    fi

    body=$(jq --raw-output '.comment.body // ""' "$GITHUB_EVENT_PATH")
    title=''
  else
    body=$(jq --raw-output '.issue.body // ""' "$GITHUB_EVENT_PATH")
    title=$(jq --raw-output '.issue.title // ""' "$GITHUB_EVENT_PATH")
  fi

  while IFS= read -r api_key; do
    api_keys+=("$api_key")
  done < <(
    printf '%s\n%s\n' "$body" "$title" |
      grep --only-matching --extended-regexp "$API_KEY_PATTERN" |
      sort --unique
  )

  sanitized_body=$(sanitize_issue_text "$body")
  sanitized_title=$(sanitize_issue_text "$title")

  if (( ${#api_keys[@]} == 0 )) && \
    [[ "$sanitized_body" == "$body" && "$sanitized_title" == "$title" ]]; then
    printf 'No API keys, receiver coordinates, or ANSI colour sequences were found.\n'
    return
  fi

  for api_key in "${api_keys[@]}"; do
    printf '::add-mask::%s\n' "$api_key"
  done

  if [[ "$event_name" == issue_comment ]]; then
    comment_id=$(jq --raw-output '.comment.id' "$GITHUB_EVENT_PATH")
    gh api \
      --method PATCH \
      --silent \
      "repos/${GITHUB_REPOSITORY}/issues/comments/${comment_id}" \
      --raw-field body="$sanitized_body"
  else
    gh api \
      --method PATCH \
      --silent \
      "repos/${GITHUB_REPOSITORY}/issues/${issue_number}" \
      --raw-field body="$sanitized_body" \
      --raw-field title="$sanitized_title"
  fi

  if (( ${#api_keys[@]} > 0 )); then
    gh api \
      --method POST \
      --silent \
      "repos/${GITHUB_REPOSITORY}/issues/${issue_number}/comments" \
      --raw-field body="$(printf '%s\n\n%s' \
        '⚠️ A UUID matching the Plane Watch API-key format was automatically removed.' \
        'Assume the key was exposed. Revoke it and generate a replacement in ATC immediately.')"
  fi

  printf 'Sanitized issue text; redacted %d unique UUID-shaped API key(s).\n' "${#api_keys[@]}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
