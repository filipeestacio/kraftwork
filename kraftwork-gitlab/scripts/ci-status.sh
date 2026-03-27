#!/bin/sh
#
# ci-status.sh - Check CI pipeline status for a branch
#
# Usage: ci-status.sh <BRANCH>
#   BRANCH: Git branch name to check
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or glab failure
#

set -eu

BRANCH="${1:-}"

if [ -z "$BRANCH" ]; then
  echo "Usage: ci-status.sh <BRANCH>" >&2
  exit 1
fi

glab ci status --branch "$BRANCH"
