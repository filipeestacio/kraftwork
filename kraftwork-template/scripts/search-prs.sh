#!/bin/sh
#
# search-prs.sh - Search for PRs matching a ticket
#
# Usage: search-prs.sh <TICKET_ID> [ORG_OR_GROUP]
#   TICKET_ID:    Ticket identifier (e.g., PROJ-1234)
#   ORG_OR_GROUP: Organization/group to search (defaults to workspace.json config)
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
  echo "Usage: search-prs.sh <TICKET_ID> [ORG_OR_GROUP]" >&2
  exit 1
fi

if [ -z "$ORG" ]; then
  DIR="$(pwd)"
  while [ "$DIR" != "/" ]; do
    [ -f "$DIR/workspace.json" ] && break
    DIR=$(dirname "$DIR")
  done
  if [ -f "$DIR/workspace.json" ]; then
    ORG=$(jq -r '.providers."git-hosting".config.org // .providers."git-hosting".config.defaultGroup // empty' "$DIR/workspace.json")
  fi
  if [ -z "$ORG" ]; then
    echo "[]"
    exit 0
  fi
fi

# --- IMPLEMENT BELOW ---
echo "[]"
