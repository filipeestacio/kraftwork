#!/bin/sh
set -eu

TITLE="${1:-}"
CONTENT="${2:-}"
SPACE_ID="${3:-}"

if [ -z "$TITLE" ] || [ -z "$CONTENT" ]; then
  echo "Usage: write-doc.sh <TITLE> <CONTENT> [SPACE_ID]" >&2
  exit 1
fi

DIR="$(pwd)"
while [ "$DIR" != "/" ]; do
  [ -f "$DIR/workspace.json" ] && break
  DIR=$(dirname "$DIR")
done
WORKSPACE_JSON="$DIR/workspace.json"

TOKEN_ENV=$(jq -r '.providers."document-storage".config.apiTokenEnv // .providers."ticket-management".config.apiTokenEnv // empty' "$WORKSPACE_JSON")
TOKEN=$(eval echo "\$$TOKEN_ENV" 2>/dev/null || echo "")
TEAM_ID=$(jq -r '.providers."document-storage".config.teamId // .providers."ticket-management".config.teamId // empty' "$WORKSPACE_JSON")

if [ -z "$SPACE_ID" ]; then
  SPACE_ID=$(jq -r '.providers."document-storage".config.spaces[0].id // .providers."ticket-management".config.spaces[0].id // empty' "$WORKSPACE_JSON")
fi

RESPONSE=$(curl -s -X POST \
  -H "Authorization: $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"name\": $(printf '%s' "$TITLE" | jq -Rs .), \"content\": $(printf '%s' "$CONTENT" | jq -Rs .)}" \
  "https://api.clickup.com/api/v3/workspaces/$TEAM_ID/docs")

if echo "$RESPONSE" | jq -e '.err' >/dev/null 2>&1; then
  echo "$RESPONSE" >&2
  exit 1
fi

echo "$RESPONSE" | jq -r '.id'
