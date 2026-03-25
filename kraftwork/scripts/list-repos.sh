#!/bin/sh
#
# list-repos.sh - List all repositories in the workspace
#
# Usage: list-repos.sh [WORKSPACE]
#   WORKSPACE: Path to workspace root (defaults to auto-detect)
#
# Options (via environment):
#   FORMAT=simple  - Just repo names (default)
#   FORMAT=full    - Full paths
#   FORMAT=json    - JSON array
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

if [ ! -d "$WORKSPACE/sources" ]; then
  echo "Error: No sources directory at $WORKSPACE" >&2
  exit 1
fi

# List repositories
case "$FORMAT" in
  json)
    echo "["
    FIRST=1
    find "$WORKSPACE/sources" -maxdepth 1 -type d ! -name "sources" | sort | while read -r REPO_PATH; do
      if [ -d "$REPO_PATH/.git" ]; then
        REPO_NAME=$(basename "$REPO_PATH")
        if [ "$FIRST" = "1" ]; then
          FIRST=0
          printf '  "%s"' "$REPO_NAME"
        else
          printf ',\n  "%s"' "$REPO_NAME"
        fi
      fi
    done
    echo ""
    echo "]"
    ;;
  full)
    find "$WORKSPACE/sources" -maxdepth 1 -type d ! -name "sources" | sort | while read -r REPO_PATH; do
      if [ -d "$REPO_PATH/.git" ]; then
        echo "$REPO_PATH"
      fi
    done
    ;;
  *)
    find "$WORKSPACE/sources" -maxdepth 1 -type d ! -name "sources" | sort | while read -r REPO_PATH; do
      if [ -d "$REPO_PATH/.git" ]; then
        basename "$REPO_PATH"
      fi
    done
    ;;
esac
