#!/bin/sh
#
# fetch-ticket.sh - Fetch a ticket from local task files
#
# Usage: fetch-ticket.sh <TICKET_ID> [WORKSPACE]
#   TICKET_ID: Filename (without .md) in the tasks/ directory
#   WORKSPACE: Path to workspace root (defaults to auto-detect)
#
# Output: JSON {"id": "...", "summary": "...", "status": "..."}
#
# Exit codes:
#   0 - Success
#   1 - Ticket not found or missing arguments
#   2 - Workspace not found
#

set -eu

SCRIPT_DIR=$(dirname "$0")
FIND_WORKSPACE="$SCRIPT_DIR/../../../scripts/find-workspace.sh"
TICKET_ID="${1:-}"
WORKSPACE="${2:-}"

if [ -z "$TICKET_ID" ]; then
  echo "Usage: fetch-ticket.sh <TICKET_ID> [WORKSPACE]" >&2
  exit 1
fi

if [ -z "$WORKSPACE" ]; then
  WORKSPACE=$("$FIND_WORKSPACE" 2>/dev/null) || {
    echo "Error: workspace not found" >&2
    exit 2
  }
fi

TASK_FILE="$WORKSPACE/tasks/$TICKET_ID.md"
if [ ! -f "$TASK_FILE" ]; then
  echo "Error: ticket not found: $TICKET_ID" >&2
  exit 1
fi

SUMMARY=$(head -1 "$TASK_FILE" | sed 's/^#* *//')

STATUS="unknown"
if grep -qi '\[done\]' "$TASK_FILE"; then
  STATUS="done"
elif grep -qi '\[in-progress\]' "$TASK_FILE"; then
  STATUS="in-progress"
elif grep -qi '\[todo\]' "$TASK_FILE"; then
  STATUS="todo"
fi

printf '{"id": "%s", "summary": "%s", "status": "%s"}\n' "$TICKET_ID" "$SUMMARY" "$STATUS"
