#!/bin/sh
#
# fetch-pr-details.sh - Fetch full details of a GitLab merge request
#
# Usage: fetch-pr-details.sh <MR_IID>
#   MR_IID: Merge request internal ID (must be run from within a git repo)
#
# Output: JSON object with details, discussions, changes, and commits
#   {"details": {...}, "discussions": [...], "changes": {...}, "commits": [...]}
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or not in a git repo
#

set -eu

MR_IID="${1:-}"

if [ -z "$MR_IID" ]; then
  echo "Usage: fetch-pr-details.sh <MR_IID>" >&2
  exit 1
fi

REMOTE_URL=$(git remote get-url origin 2>/dev/null) || {
  echo "Not inside a git repository or no origin remote" >&2
  exit 1
}

PROJECT_PATH=$(echo "$REMOTE_URL" | sed -E 's|^https?://[^/]+/||; s|^.*:||; s|\.git$||')
ENCODED_PATH=$(printf '%s' "$PROJECT_PATH" | jq -sRr @uri)

DETAILS=$(glab api "projects/${ENCODED_PATH}/merge_requests/${MR_IID}" 2>/dev/null || echo '{}')
DISCUSSIONS=$(glab api "projects/${ENCODED_PATH}/merge_requests/${MR_IID}/discussions?per_page=100" 2>/dev/null || echo '[]')
CHANGES=$(glab api "projects/${ENCODED_PATH}/merge_requests/${MR_IID}/changes" 2>/dev/null || echo '{}')
COMMITS=$(glab api "projects/${ENCODED_PATH}/merge_requests/${MR_IID}/commits?per_page=100" 2>/dev/null || echo '[]')

jq -n \
  --argjson details "$DETAILS" \
  --argjson discussions "$DISCUSSIONS" \
  --argjson changes "$CHANGES" \
  --argjson commits "$COMMITS" \
  '{details: $details, discussions: $discussions, changes: $changes, commits: $commits}'
