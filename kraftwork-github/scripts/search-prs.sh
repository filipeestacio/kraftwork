#!/bin/sh
#
# search-prs.sh - Search GitHub PRs matching a ticket
#
# Usage: search-prs.sh <TICKET_ID> [ORG]
#   TICKET_ID: Ticket identifier (e.g., PROJ-1234)
#   ORG:       GitHub organization or username (defaults to workspace.json config)
#
# Output: JSON array of matching PRs
#   [{"id": N, "title": "...", "url": "...", "branch": "...", "state": "...", "repo": "..."}]
#
# Exit codes:
#   0 - Success (may have 0 results)
#   1 - Missing ticket ID
#

set -eu

TICKET_ID="${1:-}"
ORG="${2:-}"

if [ -z "$TICKET_ID" ]; then
  echo "Usage: search-prs.sh <TICKET_ID> [ORG]" >&2
  exit 1
fi

if [ -z "$ORG" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  WORKSPACE_ROOT=$("$SCRIPT_DIR/../../kraftwork/scripts/find-workspace.sh" "$(pwd)" 2>/dev/null) || true

  if [ -n "$WORKSPACE_ROOT" ] && [ -f "$WORKSPACE_ROOT/workspace.json" ]; then
    ORG=$(jq -r '.providers."git-hosting".config.org // empty' "$WORKSPACE_ROOT/workspace.json")
  fi

  if [ -z "$ORG" ]; then
    echo "No GitHub org specified and none found in workspace.json" >&2
    echo "[]"
    exit 0
  fi
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "[]"
  exit 0
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "[]"
  exit 0
fi

ENCODED_TICKET=$(printf '%s' "$TICKET_ID" | jq -sRr @uri)

RESULTS=$(gh api "search/issues?q=${ENCODED_TICKET}+type:pr+org:${ORG}&per_page=20" 2>/dev/null || echo '{"items": []}')

if [ -z "$RESULTS" ] || [ "$RESULTS" = "null" ]; then
  echo "[]"
  exit 0
fi

echo "$RESULTS" | jq '
  if .items then
    [.items[] | {
      id: .number,
      title: .title,
      url: .html_url,
      branch: (.pull_request.url | gsub(".*/pulls/[0-9]+$"; "") | split("/repos/")[1] | split("/pulls")[0] | split("/")[2] // ""),
      state: .state,
      repo: (.repository_url | split("/repos/")[1])
    }]
  else
    []
  end
' 2>/dev/null || echo "[]"
