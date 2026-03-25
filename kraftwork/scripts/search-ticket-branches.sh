#!/bin/sh
#
# search-ticket-branches.sh - Search local repos for branches matching a ticket
#
# Usage: search-ticket-branches.sh <TICKET_ID> [WORKSPACE]
#   TICKET_ID: Jira ticket (e.g., PROJ-1234)
#   WORKSPACE: Path to workspace root (defaults to auto-detect)
#
# Output: JSON array of matching branches with repo info
#
# Exit codes:
#   0 - Success (may have 0 results)
#   1 - Missing ticket ID
#   2 - Workspace not found
#

set -eu

SCRIPT_DIR=$(dirname "$0")
TICKET_ID="${1:-}"
WORKSPACE="${2:-}"

if [ -z "$TICKET_ID" ]; then
  echo "Usage: search-ticket-branches.sh <TICKET_ID> [WORKSPACE]" >&2
  exit 1
fi

# Find workspace
if [ -z "$WORKSPACE" ]; then
  WORKSPACE=$("$SCRIPT_DIR/find-workspace.sh" 2>/dev/null) || {
    echo '{"error": "workspace not found"}' >&2
    exit 2
  }
fi

if [ ! -d "$WORKSPACE/sources" ]; then
  echo '{"error": "no sources directory"}' >&2
  exit 2
fi

# Search for matching branches
echo "["
FIRST=1

find "$WORKSPACE/sources" -maxdepth 1 -type d ! -name "sources" | sort | while read -r REPO_PATH; do
  if [ ! -d "$REPO_PATH/.git" ]; then
    continue
  fi

  REPO_NAME=$(basename "$REPO_PATH")

  # Fetch to ensure we have latest remote branches
  git -C "$REPO_PATH" fetch --quiet 2>/dev/null || true

  # Search local and remote branches (case insensitive)
  BRANCHES=$(git -C "$REPO_PATH" branch -a 2>/dev/null | grep -i "$TICKET_ID" || true)

  if [ -n "$BRANCHES" ]; then
    echo "$BRANCHES" | while read -r BRANCH_LINE; do
      # Clean up branch name (remove leading spaces, asterisk, remotes/origin/)
      BRANCH=$(echo "$BRANCH_LINE" | sed 's/^[* ]*//' | sed 's|remotes/origin/||')

      # Skip if it's a HEAD reference
      case "$BRANCH" in
        *HEAD*) continue ;;
      esac

      # Determine if local or remote
      case "$BRANCH_LINE" in
        *remotes/*) LOCATION="remote" ;;
        *) LOCATION="local" ;;
      esac

      if [ "$FIRST" = "1" ]; then
        FIRST=0
        printf '  {"repo": "%s", "branch": "%s", "location": "%s"}' "$REPO_NAME" "$BRANCH" "$LOCATION"
      else
        printf ',\n  {"repo": "%s", "branch": "%s", "location": "%s"}' "$REPO_NAME" "$BRANCH" "$LOCATION"
      fi
    done
  fi
done

echo ""
echo "]"
