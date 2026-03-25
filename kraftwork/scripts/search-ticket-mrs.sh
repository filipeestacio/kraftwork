#!/bin/sh
#
# search-ticket-mrs.sh - Search GitLab MRs for a Jira ticket
#
# Usage: search-ticket-mrs.sh <TICKET_ID> [GITLAB_GROUP]
#   TICKET_ID: Jira ticket (e.g., PROJ-1234)
#   GITLAB_GROUP: GitLab group to search (defaults to git.group from workspace.json)
#
# Output: JSON array of matching MRs with repo info
#
# Exit codes:
#   0 - Success (may have 0 results)
#   1 - Missing ticket ID
#   2 - glab not available or not authenticated
#

set -eu

TICKET_ID="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GITLAB_GROUP="${2:-$("$SCRIPT_DIR/read-config.sh" git group)}"

if [ -z "$TICKET_ID" ]; then
  echo "Usage: search-ticket-mrs.sh <TICKET_ID> [GITLAB_GROUP]" >&2
  exit 1
fi

# Check glab is available
if ! command -v glab >/dev/null 2>&1; then
  echo '{"error": "glab not installed"}' >&2
  exit 2
fi

# Check glab is authenticated
if ! glab auth status >/dev/null 2>&1; then
  echo '{"error": "glab not authenticated"}' >&2
  exit 2
fi

# Search for MRs mentioning the ticket
# Use URL encoding for the search term
ENCODED_TICKET=$(printf '%s' "$TICKET_ID" | sed 's/-/%2D/g')

MRS=$(glab api "groups/${GITLAB_GROUP}/merge_requests?search=${TICKET_ID}&state=all&per_page=20" 2>/dev/null || echo "[]")

# Check if we got valid JSON
if [ -z "$MRS" ] || [ "$MRS" = "null" ]; then
  echo "[]"
  exit 0
fi

# Filter and format results
# Extract relevant fields: id, title, web_url, source_branch, project path
echo "$MRS" | jq -r '
  if type == "array" then
    [.[] | {
      id: .iid,
      title: .title,
      url: .web_url,
      branch: .source_branch,
      state: .state,
      repo: (.references.full | split("!")[0])
    }]
  else
    []
  end
' 2>/dev/null || echo "[]"
