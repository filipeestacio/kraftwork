#!/bin/sh
#
# list-worktrees.sh - List all active worktrees in the workspace
#
# Usage: list-worktrees.sh [WORKSPACE]
#   WORKSPACE: Path to workspace root (defaults to auto-detect)
#
# Options (via environment):
#   FORMAT=simple  - Just worktree names (default)
#   FORMAT=full    - Full paths
#   FORMAT=detail  - Name, branch, and repo info
#
# Exit codes:
#   0 - Success
#   1 - Workspace not found
#

set -eu

SCRIPT_DIR=$(dirname "$0")
FORMAT="${FORMAT:-simple}"

# Find workspace
if [ -n "${1:-}" ]; then
  WORKSPACE="$1"
else
  WORKSPACE=$("$SCRIPT_DIR/find-workspace.sh" 2>/dev/null) || {
    echo "Error: Workspace not found" >&2
    exit 1
  }
fi

TREES_DIR="$WORKSPACE/trees"
if [ ! -d "$TREES_DIR" ]; then
  TREES_DIR="$WORKSPACE/tasks"
fi

if [ ! -d "$TREES_DIR" ]; then
  echo "Error: No trees directory at $WORKSPACE" >&2
  exit 1
fi

TREES_NAME=$(basename "$TREES_DIR")

# List worktrees
case "$FORMAT" in
  detail)
    find "$TREES_DIR" -maxdepth 1 -type d ! -name "$TREES_NAME" | sort | while read -r WT_PATH; do
      if [ -d "$WT_PATH/.git" ] || [ -f "$WT_PATH/.git" ]; then
        WT_NAME=$(basename "$WT_PATH")
        BRANCH=$(git -C "$WT_PATH" branch --show-current 2>/dev/null || echo "unknown")

        # Get the main repo this worktree belongs to
        GIT_DIR=$(git -C "$WT_PATH" rev-parse --git-dir 2>/dev/null || echo "")
        if [ -n "$GIT_DIR" ]; then
          # worktree .git files point to the main repo's .git/worktrees/
          MAIN_REPO=$(echo "$GIT_DIR" | sed 's|/\.git/worktrees/.*||')
          REPO_NAME=$(basename "$MAIN_REPO")
        else
          REPO_NAME="unknown"
        fi

        # Check for uncommitted changes
        if [ -n "$(git -C "$WT_PATH" status --porcelain 2>/dev/null)" ]; then
          STATUS="*"
        else
          STATUS=""
        fi

        printf "%s%s\t%s\t%s\n" "$WT_NAME" "$STATUS" "$BRANCH" "$REPO_NAME"
      fi
    done
    ;;
  full)
    find "$TREES_DIR" -maxdepth 1 -type d ! -name "$TREES_NAME" | sort | while read -r WT_PATH; do
      if [ -d "$WT_PATH/.git" ] || [ -f "$WT_PATH/.git" ]; then
        echo "$WT_PATH"
      fi
    done
    ;;
  *)
    find "$TREES_DIR" -maxdepth 1 -type d ! -name "$TREES_NAME" | sort | while read -r WT_PATH; do
      if [ -d "$WT_PATH/.git" ] || [ -f "$WT_PATH/.git" ]; then
        basename "$WT_PATH"
      fi
    done
    ;;
esac
