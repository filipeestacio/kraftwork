#!/bin/sh
#
# search-branches.sh - Search local branches matching a ticket ID
#
# Usage: search-branches.sh <TICKET_ID> [WORKSPACE]
#   TICKET_ID: Ticket identifier to search for
#   WORKSPACE: Path to workspace root (defaults to auto-detect)
#
# Output: JSON array of matching branches
#   [{"repo": "name", "branch": "branch-name", "location": "local"}]
#
# Exit codes:
#   0 - Success (may have 0 results)
#   1 - Missing ticket ID
#   2 - Workspace not found
#

set -eu

SCRIPT_DIR=$(dirname "$0")
FIND_WORKSPACE="$SCRIPT_DIR/../../../scripts/find-workspace.sh"
TICKET_ID="${1:-}"
WORKSPACE="${2:-}"

if [ -z "$TICKET_ID" ]; then
  echo "Usage: search-branches.sh <TICKET_ID> [WORKSPACE]" >&2
  exit 1
fi

if [ -z "$WORKSPACE" ]; then
  WORKSPACE=$("$FIND_WORKSPACE" 2>/dev/null) || {
    echo '{"error": "workspace not found"}' >&2
    exit 2
  }
fi

MODULES_DIR="$WORKSPACE/modules"
if [ ! -d "$MODULES_DIR" ]; then
  echo "[]"
  exit 0
fi

echo "["
FIRST=1

for REPO_PATH in "$MODULES_DIR"/*/; do
  [ -d "$REPO_PATH/.git" ] || continue

  REPO_NAME=$(basename "$REPO_PATH")
  BRANCHES=$(git -C "$REPO_PATH" branch 2>/dev/null | grep -i "$TICKET_ID" || true)

  if [ -n "$BRANCHES" ]; then
    echo "$BRANCHES" | while read -r BRANCH_LINE; do
      BRANCH=$(echo "$BRANCH_LINE" | sed 's/^[* ]*//')

      if [ "$FIRST" = "1" ]; then
        FIRST=0
        printf '  {"repo": "%s", "branch": "%s", "location": "local"}' "$REPO_NAME" "$BRANCH"
      else
        printf ',\n  {"repo": "%s", "branch": "%s", "location": "local"}' "$REPO_NAME" "$BRANCH"
      fi
    done
  fi
done

echo ""
echo "]"
