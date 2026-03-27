#!/bin/sh
#
# ci-status.sh - Check CI workflow status for a branch
#
# Usage: ci-status.sh <BRANCH>
#   BRANCH: Git branch name to check
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or gh failure
#

set -eu

BRANCH="${1:-}"

if [ -z "$BRANCH" ]; then
  echo "Usage: ci-status.sh <BRANCH>" >&2
  exit 1
fi

gh run list --branch "$BRANCH" --json name,status,conclusion --limit 10
