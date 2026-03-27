#!/bin/sh
set -eu

DIR="$(pwd)"
while [ "$DIR" != "/" ]; do
  [ -f "$DIR/workspace.json" ] && break
  DIR=$(dirname "$DIR")
done
WORKSPACE_JSON="$DIR/workspace.json"

TOKEN_ENV=$(jq -r '.providers."ticket-management".config.apiTokenEnv // empty' "$WORKSPACE_JSON")
if [ -z "$TOKEN_ENV" ]; then
  TOKEN_ENV=$(jq -r '.providers."document-storage".config.apiTokenEnv // empty' "$WORKSPACE_JSON")
fi

if [ -z "$TOKEN_ENV" ]; then
  echo "apiTokenEnv not configured in workspace.json" >&2
  exit 1
fi

TOKEN=$(eval echo "\$$TOKEN_ENV" 2>/dev/null || echo "")
if [ -z "$TOKEN" ]; then
  echo "$TOKEN_ENV is not set" >&2
  exit 1
fi

exit 0
