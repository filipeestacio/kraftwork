#!/bin/sh
#
# fetch-pr-details.sh - Fetch full PR/MR details
#
# Usage: fetch-pr-details.sh <PR_NUMBER>
#   Must be run from within a git repo.
#
# Output: JSON object
#   {"details": {...}, "discussions": [...], "changes": {...}, "commits": [...]}
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or not in a git repo
#

set -eu

PR_NUMBER="${1:-}"

if [ -z "$PR_NUMBER" ]; then
  echo "Usage: fetch-pr-details.sh <PR_NUMBER>" >&2
  exit 1
fi

REMOTE_URL=$(git remote get-url origin 2>/dev/null) || {
  echo "Not inside a git repository or no origin remote" >&2
  exit 1
}

# --- IMPLEMENT BELOW ---
echo '{"details": {}, "discussions": [], "changes": {}, "commits": []}'
