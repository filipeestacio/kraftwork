#!/bin/sh
#
# search-tickets.sh - Search Jira tickets via acli
#
# Usage: search-tickets.sh <QUERY>
#
# Output: JSON array of matching tickets
#
# Exit codes:
#   0 - Success (may return empty array if acli unavailable)
#   1 - Missing query
#

set -eu

QUERY="${1:-}"

if [ -z "$QUERY" ]; then
  echo "Usage: search-tickets.sh <QUERY>" >&2
  exit 1
fi

if ! command -v acli >/dev/null 2>&1; then
  echo '[]'
  exit 0
fi

acli jira workitem list --jql "text ~ \"$QUERY\"" --json 2>/dev/null || echo "[]"
