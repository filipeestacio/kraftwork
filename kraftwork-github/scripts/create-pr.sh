#!/bin/sh
#
# create-pr.sh - Create a GitHub pull request
#
# Usage: create-pr.sh <SOURCE_BRANCH> <TARGET_BRANCH> <TITLE> [BODY]
#   SOURCE_BRANCH: Branch to merge from
#   TARGET_BRANCH: Branch to merge into
#   TITLE:         PR title
#   BODY:          PR description (optional)
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or PR creation failed
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

git push -u origin "$SOURCE_BRANCH"

gh pr create \
  --base "$TARGET_BRANCH" \
  --head "$SOURCE_BRANCH" \
  --title "$TITLE" \
  --body "${BODY:-}"
