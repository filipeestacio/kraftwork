#!/bin/sh
set -eu

SPACE_ID="${1:-}"

DIR="$(pwd)"
while [ "$DIR" != "/" ]; do
  [ -f "$DIR/workspace.json" ] && break
  DIR=$(dirname "$DIR")
done
WORKSPACE_JSON="$DIR/workspace.json"

TOKEN_ENV=$(jq -r '.providers."document-storage".config.apiTokenEnv // .providers."ticket-management".config.apiTokenEnv // empty' "$WORKSPACE_JSON")
TOKEN=$(eval echo "\$$TOKEN_ENV" 2>/dev/null || echo "")
TEAM_ID=$(jq -r '.providers."document-storage".config.teamId // .providers."ticket-management".config.teamId // empty' "$WORKSPACE_JSON")

fetch_docs_for_space() {
  SID="$1"
  curl -s \
    -H "Authorization: $TOKEN" \
    "https://api.clickup.com/api/v3/workspaces/$TEAM_ID/docs?space_id=$SID" \
    | jq --arg sid "$SID" '[.docs[] | {id, title: .name, space_id: $sid}]' 2>/dev/null || echo '[]'
}

if [ -n "$SPACE_ID" ]; then
  fetch_docs_for_space "$SPACE_ID"
else
  SPACES=$(jq -r '(.providers."document-storage".config.spaces // .providers."ticket-management".config.spaces // []) | .[].id' "$WORKSPACE_JSON")
  RESULT='[]'
  for SID in $SPACES; do
    DOCS=$(fetch_docs_for_space "$SID")
    RESULT=$(printf '%s\n%s' "$RESULT" "$DOCS" | jq -s 'add // []')
  done
  echo "$RESULT"
fi
