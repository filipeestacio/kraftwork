#!/bin/sh
#
# stack-metadata.sh - Read/write stack metadata for split worktrees
#
# Usage:
#   stack-metadata.sh read <worktree-path>    → outputs JSON (or {} if none)
#   stack-metadata.sh write <worktree-path> <json-string>
#
# Exit codes:
#   0 - Success
#   1 - Invalid usage
#

set -eu

COMMAND="${1:-}"
WORKTREE_PATH="${2:-}"

if [ -z "$COMMAND" ] || [ -z "$WORKTREE_PATH" ]; then
  echo "Usage: stack-metadata.sh read|write <worktree-path> [json]" >&2
  exit 1
fi

META_FILE="$WORKTREE_PATH/.stack-metadata.json"

case "$COMMAND" in
  read)
    if [ -f "$META_FILE" ]; then
      cat "$META_FILE"
    else
      echo '{}'
    fi
    ;;
  write)
    JSON="${3:-}"
    if [ -z "$JSON" ]; then
      echo "Usage: stack-metadata.sh write <worktree-path> <json>" >&2
      exit 1
    fi
    echo "$JSON" > "$META_FILE"
    ;;
  *)
    echo "Unknown command: $COMMAND. Use read or write." >&2
    exit 1
    ;;
esac
