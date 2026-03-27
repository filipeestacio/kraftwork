#!/bin/sh
set -eu

TICKET_ID="${1:-}"
if [ -z "$TICKET_ID" ]; then
  echo "Usage: fetch-ticket.sh <TICKET_ID>" >&2
  exit 1
fi

DIR="$(pwd)"
while [ "$DIR" != "/" ]; do
  [ -f "$DIR/workspace.json" ] && break
  DIR=$(dirname "$DIR")
done
WORKSPACE_JSON="$DIR/workspace.json"

TOKEN_ENV=$(jq -r '.providers."ticket-management".config.apiTokenEnv // empty' "$WORKSPACE_JSON")
TOKEN=$(eval echo "\$$TOKEN_ENV" 2>/dev/null || echo "")

RESPONSE=$(curl -s -H "Authorization: $TOKEN" "https://api.clickup.com/api/v2/task/$TICKET_ID")

if echo "$RESPONSE" | jq -e '.err' >/dev/null 2>&1; then
  echo "$RESPONSE" >&2
  exit 1
fi

echo "$RESPONSE" | jq '{"id": .id, "summary": .name, "status": .status.status}'
