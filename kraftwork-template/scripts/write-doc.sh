#!/bin/sh
#
# write-doc.sh - Write/create a document
#
# Usage: write-doc.sh <PATH> <CONTENT>
#   PATH: Document path/identifier
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or write failed
#

set -eu

DOC_PATH="${1:-}"
CONTENT="${2:-}"

if [ -z "$DOC_PATH" ]; then
  echo "Usage: write-doc.sh <PATH> <CONTENT>" >&2
  exit 1
fi

# --- IMPLEMENT BELOW ---
echo "write-doc.sh: not implemented" >&2
exit 1
