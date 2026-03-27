#!/bin/sh
#
# search-prs.sh - Search GitLab MRs matching a ticket
#
# Usage: search-prs.sh <TICKET_ID> [GITLAB_GROUP]
#   TICKET_ID:    Ticket identifier (e.g., PROJ-1234)
#   GITLAB_GROUP: GitLab group to search (defaults to workspace.json config)
#
# Output: JSON array of matching MRs
#   [{"id": N, "title": "...", "url": "...", "branch": "...", "state": "...", "repo": "..."}]
#
# Exit codes:
#   0 - Success (may have 0 results)
#   1 - Missing ticket ID
#

set -eu

TICKET_ID="${1:-}"
GITLAB_GROUP="${2:-}"

if [ -z "$TICKET_ID" ]; then
  echo "Usage: search-prs.sh <TICKET_ID> [GITLAB_GROUP]" >&2
  exit 1
fi

if [ -z "$GITLAB_GROUP" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  WORKSPACE_ROOT=$("$SCRIPT_DIR/../../kraftwork/scripts/find-workspace.sh" "$(pwd)" 2>/dev/null) || true

  if [ -n "$WORKSPACE_ROOT" ] && [ -f "$WORKSPACE_ROOT/workspace.json" ]; then
    GITLAB_GROUP=$(jq -r '.providers."git-hosting".config.defaultGroup // .git.group // empty' "$WORKSPACE_ROOT/workspace.json")
  fi

  if [ -z "$GITLAB_GROUP" ]; then
    echo "No GitLab group specified and none found in workspace.json" >&2
    echo "[]"
    exit 0
  fi
fi

if ! command -v glab >/dev/null 2>&1; then
  echo "[]"
  exit 0
fi

if ! glab auth status >/dev/null 2>&1; then
  echo "[]"
  exit 0
fi

ENCODED_GROUP=$(printf '%s' "$GITLAB_GROUP" | jq -sRr @uri)

MRS=$(glab api "groups/${ENCODED_GROUP}/merge_requests?search=${TICKET_ID}&state=all&per_page=20" 2>/dev/null || echo "[]")

if [ -z "$MRS" ] || [ "$MRS" = "null" ]; then
  echo "[]"
  exit 0
fi

echo "$MRS" | jq '
  if type == "array" then
    [.[] | {
      id: .iid,
      title: .title,
      url: .web_url,
      branch: .source_branch,
      state: .state,
      repo: (.references.full | split("!")[0] | rtrimstr("/"))
    }]
  else
    []
  end
' 2>/dev/null || echo "[]"
