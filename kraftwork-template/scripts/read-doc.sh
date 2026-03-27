#!/bin/sh
#
# read-doc.sh - Read a document
#
# Usage: read-doc.sh <PATH>
#   PATH: Document path/identifier
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or document not found
#

set -eu

DOC_PATH="${1:-}"

if [ -z "$DOC_PATH" ]; then
  echo "Usage: read-doc.sh <PATH>" >&2
  exit 1
fi

# --- IMPLEMENT BELOW ---
echo "read-doc.sh: not implemented" >&2
exit 1
