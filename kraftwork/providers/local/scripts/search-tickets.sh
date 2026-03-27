#!/bin/sh
#
# search-tickets.sh - Search local task files for a query
#
# Usage: search-tickets.sh <QUERY> [WORKSPACE]
#   QUERY:     Text to search for in task files
#   WORKSPACE: Path to workspace root (defaults to auto-detect)
#
# Output: JSON array of matching tickets
#
# Exit codes:
#   0 - Success (may have 0 results)
#   1 - Missing query
#   2 - Workspace not found
#

set -eu

SCRIPT_DIR=$(dirname "$0")
FIND_WORKSPACE="$SCRIPT_DIR/../../../scripts/find-workspace.sh"
QUERY="${1:-}"
WORKSPACE="${2:-}"

if [ -z "$QUERY" ]; then
  echo "Usage: search-tickets.sh <QUERY> [WORKSPACE]" >&2
  exit 1
fi

if [ -z "$WORKSPACE" ]; then
  WORKSPACE=$("$FIND_WORKSPACE" 2>/dev/null) || {
    echo "Error: workspace not found" >&2
    exit 2
  }
fi

TASKS_DIR="$WORKSPACE/tasks"
if [ ! -d "$TASKS_DIR" ]; then
  echo "[]"
  exit 0
fi

echo "["
FIRST=1

for TASK_FILE in "$TASKS_DIR"/*.md; do
  [ -f "$TASK_FILE" ] || continue

  if grep -qi "$QUERY" "$TASK_FILE"; then
    TICKET_ID=$(basename "$TASK_FILE" .md)
    SUMMARY=$(head -1 "$TASK_FILE" | sed 's/^#* *//')

    STATUS="unknown"
    if grep -qi '\[done\]' "$TASK_FILE"; then
      STATUS="done"
    elif grep -qi '\[in-progress\]' "$TASK_FILE"; then
      STATUS="in-progress"
    elif grep -qi '\[todo\]' "$TASK_FILE"; then
      STATUS="todo"
    fi

    if [ "$FIRST" = "1" ]; then
      FIRST=0
      printf '  {"id": "%s", "summary": "%s", "status": "%s"}' "$TICKET_ID" "$SUMMARY" "$STATUS"
    else
      printf ',\n  {"id": "%s", "summary": "%s", "status": "%s"}' "$TICKET_ID" "$SUMMARY" "$STATUS"
    fi
  fi
done

echo ""
echo "]"
