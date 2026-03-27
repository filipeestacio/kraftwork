#!/bin/sh
#
# create-pr.sh - Create a pull/merge request
#
# Usage: create-pr.sh <SOURCE_BRANCH> <TARGET_BRANCH> <TITLE> [BODY]
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or creation failed
#

set -eu

SOURCE_BRANCH="${1:-}"
TARGET_BRANCH="${2:-}"
TITLE="${3:-}"
BODY="${4:-}"

if [ -z "$SOURCE_BRANCH" ] || [ -z "$TARGET_BRANCH" ] || [ -z "$TITLE" ]; then
  echo "Usage: create-pr.sh <SOURCE_BRANCH> <TARGET_BRANCH> <TITLE> [BODY]" >&2
  exit 1
fi

# --- IMPLEMENT BELOW ---
echo "create-pr.sh: not implemented" >&2
exit 1
