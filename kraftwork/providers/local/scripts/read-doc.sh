#!/bin/sh
#
# read-doc.sh - Read a document from the workspace docs directory
#
# Usage: read-doc.sh <PATH>
#   PATH: Relative path within docs/ directory
#
# Output: File content
#
# Exit codes:
#   0 - Success
#   1 - File not found or missing arguments
#   2 - Workspace not found
#

set -eu

SCRIPT_DIR=$(dirname "$0")
FIND_WORKSPACE="$SCRIPT_DIR/../../../scripts/find-workspace.sh"
DOC_PATH="${1:-}"

if [ -z "$DOC_PATH" ]; then
  echo "Usage: read-doc.sh <PATH>" >&2
  exit 1
fi

WORKSPACE=$("$FIND_WORKSPACE" 2>/dev/null) || {
  echo "Error: workspace not found" >&2
  exit 2
}

FULL_PATH="$WORKSPACE/docs/$DOC_PATH"
if [ ! -f "$FULL_PATH" ]; then
  echo "Error: not found: $DOC_PATH" >&2
  exit 1
fi

cat "$FULL_PATH"
