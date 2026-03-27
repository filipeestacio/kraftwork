#!/bin/sh
#
# write-doc.sh - Write a document to the workspace docs directory
#
# Usage: write-doc.sh <PATH> <CONTENT>
#   PATH:    Relative path within docs/ directory
#   CONTENT: Content to write
#
# Output: Full path of written file
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments
#   2 - Workspace not found
#

set -eu

SCRIPT_DIR=$(dirname "$0")
FIND_WORKSPACE="$SCRIPT_DIR/../../../scripts/find-workspace.sh"
DOC_PATH="${1:-}"
CONTENT="${2:-}"

if [ -z "$DOC_PATH" ] || [ -z "$CONTENT" ]; then
  echo "Usage: write-doc.sh <PATH> <CONTENT>" >&2
  exit 1
fi

WORKSPACE=$("$FIND_WORKSPACE" 2>/dev/null) || {
  echo "Error: workspace not found" >&2
  exit 2
}

FULL_PATH="$WORKSPACE/docs/$DOC_PATH"
mkdir -p "$(dirname "$FULL_PATH")"
printf '%s' "$CONTENT" > "$FULL_PATH"
echo "$FULL_PATH"
