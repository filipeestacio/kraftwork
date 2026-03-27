#!/bin/sh
#
# search-branches.sh - Search local and remote branches matching a ticket
#
# Usage: search-branches.sh <TICKET_ID> [WORKSPACE]
#   TICKET_ID: Ticket identifier (e.g., PROJ-1234)
#   WORKSPACE: Path to workspace root (defaults to auto-detect)
#
# Output: JSON array of matching branches
#   [{"repo": "...", "branch": "...", "location": "local|remote"}]
#
# Exit codes:
#   0 - Success (may have 0 results)
#   1 - Missing ticket ID
#   2 - Workspace not found
#

set -eu

TICKET_ID="${1:-}"
WORKSPACE="${2:-}"

if [ -z "$TICKET_ID" ]; then
  echo "Usage: search-branches.sh <TICKET_ID> [WORKSPACE]" >&2
  exit 1
fi

if [ -z "$WORKSPACE" ]; then
  DIR="$(pwd)"
  while [ "$DIR" != "/" ]; do
    [ -f "$DIR/workspace.json" ] && break
    DIR=$(dirname "$DIR")
  done
  WORKSPACE="$DIR"
fi

if [ -d "$WORKSPACE/modules" ]; then
  REPOS_DIR="$WORKSPACE/modules"
elif [ -d "$WORKSPACE/sources" ]; then
  REPOS_DIR="$WORKSPACE/sources"
else
  echo "[]"
  exit 0
fi

# --- IMPLEMENT BELOW ---
# This implementation is generic (git-based, not vendor-specific).
# You can usually copy it as-is.

for REPO_PATH in "$REPOS_DIR"/*/; do
  [ -d "$REPO_PATH/.git" ] || continue
  REPO_NAME=$(basename "$REPO_PATH")
  git -C "$REPO_PATH" fetch --quiet 2>/dev/null || true
  BRANCHES=$(git -C "$REPO_PATH" branch -a 2>/dev/null | grep -i "$TICKET_ID" || true)
  [ -z "$BRANCHES" ] && continue
  echo "$BRANCHES" | while IFS= read -r BRANCH_LINE; do
    BRANCH=$(echo "$BRANCH_LINE" | sed 's/^[* ]*//' | sed 's|remotes/origin/||')
    case "$BRANCH" in *HEAD*) continue ;; esac
    case "$BRANCH_LINE" in
      *remotes/*) LOCATION="remote" ;;
      *) LOCATION="local" ;;
    esac
    SAFE_BRANCH=$(printf '%s' "$BRANCH" | jq -sR '.')
    SAFE_REPO=$(printf '%s' "$REPO_NAME" | jq -sR '.')
    printf '{"repo": %s, "branch": %s, "location": "%s"}\n' "$SAFE_REPO" "$SAFE_BRANCH" "$LOCATION"
  done
done | jq -s '.' 2>/dev/null || echo "[]"
