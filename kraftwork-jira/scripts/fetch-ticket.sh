#!/bin/sh
#
# fetch-ticket.sh - Fetch a Jira ticket via acli
#
# Usage: fetch-ticket.sh <TICKET_ID>
#
# Output: JSON {"id": "...", "summary": "...", "status": "..."}
#
# Exit codes:
#   0 - Success
#   1 - acli not installed, missing arguments, or ticket not found
#

set -eu

TICKET_ID="${1:-}"

if [ -z "$TICKET_ID" ]; then
  echo "Usage: fetch-ticket.sh <TICKET_ID>" >&2
  exit 1
fi

if ! command -v acli >/dev/null 2>&1; then
  echo '{"error": "acli not installed"}' >&2
  exit 1
fi

TICKET_JSON=$(acli jira workitem view "$TICKET_ID" --fields summary,status --json 2>/dev/null || echo "{}")
SUMMARY=$(echo "$TICKET_JSON" | jq -r '.fields.summary // empty')
STATUS=$(echo "$TICKET_JSON" | jq -r '.fields.status.name // empty')

if [ -z "$SUMMARY" ]; then
  echo '{"error": "ticket not found or acli not configured"}' >&2
  exit 1
fi

printf '{"id": "%s", "summary": "%s", "status": "%s"}\n' "$TICKET_ID" "$SUMMARY" "$STATUS"
