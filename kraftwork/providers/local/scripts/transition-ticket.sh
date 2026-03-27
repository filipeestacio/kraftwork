#!/bin/sh
#
# transition-ticket.sh - Transition a local ticket's status
#
# Usage: transition-ticket.sh <TICKET_ID> <STATUS> [WORKSPACE]
#   TICKET_ID: Filename (without .md) in the tasks/ directory
#   STATUS:    New status (todo, in-progress, done)
#   WORKSPACE: Path to workspace root (defaults to auto-detect)
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or ticket not found
#   2 - Workspace not found
#

set -eu

SCRIPT_DIR=$(dirname "$0")
FIND_WORKSPACE="$SCRIPT_DIR/../../../scripts/find-workspace.sh"
TICKET_ID="${1:-}"
STATUS="${2:-}"
WORKSPACE="${3:-}"

if [ -z "$TICKET_ID" ] || [ -z "$STATUS" ]; then
  echo "Usage: transition-ticket.sh <TICKET_ID> <STATUS> [WORKSPACE]" >&2
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

TMP_FILE=$(mktemp)
sed -e 's/\[todo\]/['"$STATUS"']/gi' \
    -e 's/\[in-progress\]/['"$STATUS"']/gi' \
    -e 's/\[done\]/['"$STATUS"']/gi' "$TASK_FILE" > "$TMP_FILE"
mv "$TMP_FILE" "$TASK_FILE"

echo "Transitioned $TICKET_ID to [$STATUS]"
