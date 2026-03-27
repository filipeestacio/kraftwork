#!/bin/sh
set -eu

DOC_ID="${1:-}"
if [ -z "$DOC_ID" ]; then
  echo "Usage: read-doc.sh <DOC_ID>" >&2
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

RESPONSE=$(curl -s \
  -H "Authorization: $TOKEN" \
  "https://api.clickup.com/api/v3/workspaces/$TEAM_ID/docs/$DOC_ID")

if echo "$RESPONSE" | jq -e '.err' >/dev/null 2>&1; then
  echo "$RESPONSE" >&2
  exit 1
fi

echo "$RESPONSE" | jq -r '.content'
