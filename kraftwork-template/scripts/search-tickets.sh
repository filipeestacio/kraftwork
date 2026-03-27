#!/bin/sh
#
# search-tickets.sh - Search tickets
#
# Usage: search-tickets.sh <QUERY>
#
# Output: JSON array of matching tickets
#
# Exit codes:
#   0 - Success (may have 0 results)
#   1 - Missing query
#

set -eu

QUERY="${1:-}"

if [ -z "$QUERY" ]; then
  echo "Usage: search-tickets.sh <QUERY>" >&2
  exit 1
fi

# --- IMPLEMENT BELOW ---
echo "[]"
