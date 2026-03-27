#!/bin/sh
set -eu

QUERY="${1:-}"
if [ -z "$QUERY" ]; then
  echo "Usage: search-tickets.sh <QUERY>" >&2
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
TEAM_ID=$(jq -r '.providers."ticket-management".config.teamId // empty' "$WORKSPACE_JSON")

if [ -z "$TOKEN" ] || [ -z "$TEAM_ID" ]; then
  echo '[]'
  exit 0
fi

ENCODED_QUERY=$(printf '%s' "$QUERY" | jq -sRr @uri)
RESPONSE=$(curl -s -H "Authorization: $TOKEN" "https://api.clickup.com/api/v2/team/$TEAM_ID/task?query=$ENCODED_QUERY&include_closed=true")

echo "$RESPONSE" | jq '[.tasks[] | {id, summary: .name, status: .status.status}]' 2>/dev/null || echo '[]'
