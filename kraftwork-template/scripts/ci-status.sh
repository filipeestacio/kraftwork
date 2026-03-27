#!/bin/sh
#
# ci-status.sh - Check CI status for a branch
#
# Usage: ci-status.sh <BRANCH>
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or CI check failed
#

set -eu

BRANCH="${1:-}"

if [ -z "$BRANCH" ]; then
  echo "Usage: ci-status.sh <BRANCH>" >&2
  exit 1
fi

# --- IMPLEMENT BELOW ---
echo "ci-status.sh: not implemented" >&2
exit 1
