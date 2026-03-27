#!/bin/sh
#
# transition-ticket.sh - Transition a Jira ticket's status via acli
#
# Usage: transition-ticket.sh <TICKET_ID> <STATUS>
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or acli not installed
#

set -eu

TICKET_ID="${1:-}"
STATUS="${2:-}"

if [ -z "$TICKET_ID" ] || [ -z "$STATUS" ]; then
  echo "Usage: transition-ticket.sh <TICKET_ID> <STATUS>" >&2
  exit 1
fi

if ! command -v acli >/dev/null 2>&1; then
  echo "acli not installed" >&2
  exit 1
fi

acli jira workitem transition "$TICKET_ID" "$STATUS"
