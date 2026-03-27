#!/bin/sh
#
# list-docs.sh - List documents in the workspace docs directory
#
# Usage: list-docs.sh [PREFIX]
#   PREFIX: Optional subdirectory prefix to list under
#
# Output: Paths relative to docs/, one per line
#
# Exit codes:
#   0 - Success
#   2 - Workspace not found
#

set -eu

SCRIPT_DIR=$(dirname "$0")
FIND_WORKSPACE="$SCRIPT_DIR/../../../scripts/find-workspace.sh"
PREFIX="${1:-}"

WORKSPACE=$("$FIND_WORKSPACE" 2>/dev/null) || {
  echo "Error: workspace not found" >&2
  exit 2
}

DOCS_DIR="$WORKSPACE/docs"
TARGET="$DOCS_DIR/$PREFIX"

if [ ! -d "$TARGET" ]; then
  exit 0
fi

find "$TARGET" -type f | while read -r FILE; do
  echo "${FILE#"$DOCS_DIR"/}"
done
