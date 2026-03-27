#!/bin/sh
#
# transition-ticket.sh - Transition a ticket to a new status
#
# Usage: transition-ticket.sh <TICKET_ID> <STATUS>
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or transition failed
#

set -eu

TICKET_ID="${1:-}"
STATUS="${2:-}"

if [ -z "$TICKET_ID" ] || [ -z "$STATUS" ]; then
  echo "Usage: transition-ticket.sh <TICKET_ID> <STATUS>" >&2
  exit 1
fi

# --- IMPLEMENT BELOW ---
echo "transition-ticket.sh: not implemented" >&2
exit 1
