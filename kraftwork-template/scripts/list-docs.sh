#!/bin/sh
#
# list-docs.sh - List documents
#
# Usage: list-docs.sh [PREFIX]
#   PREFIX: Optional path prefix to filter by
#
# Output: List of document paths/identifiers
#
# Exit codes:
#   0 - Success (may have 0 results)
#

set -eu

PREFIX="${1:-}"

# --- IMPLEMENT BELOW ---
echo "[]"
