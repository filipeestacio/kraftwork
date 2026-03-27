#!/bin/sh
#
# create-pr.sh - Create a GitLab merge request
#
# Usage: create-pr.sh <SOURCE_BRANCH> <TARGET_BRANCH> <TITLE> [BODY]
#   SOURCE_BRANCH: Branch to merge from
#   TARGET_BRANCH: Branch to merge into
#   TITLE:         MR title
#   BODY:          MR description (optional)
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or MR creation failed
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

git push -u origin "$SOURCE_BRANCH" 2>/dev/null

if [ -n "$BODY" ]; then
  glab mr create \
    --source-branch "$SOURCE_BRANCH" \
    --target-branch "$TARGET_BRANCH" \
    --title "$TITLE" \
    --description "$BODY" \
    --yes
else
  glab mr create \
    --source-branch "$SOURCE_BRANCH" \
    --target-branch "$TARGET_BRANCH" \
    --title "$TITLE" \
    --yes
fi
