#!/bin/sh
#
# auth-check.sh - Verify authentication with the provider
#
# Usage: auth-check.sh
#
# Exit codes:
#   0 - Authenticated
#   1 - Not authenticated or tool missing
#

set -eu

# ┌─────────────────────────────────────────────────────┐
# │ PATTERN A: CLI-based (gh, glab, etc.)               │
# │ Delete this block if using API-based auth.           │
# └─────────────────────────────────────────────────────┘

# if ! command -v TOOL >/dev/null 2>&1; then
#   echo "TOOL is not installed." >&2
#   exit 1
# fi
# if ! TOOL auth status >/dev/null 2>&1; then
#   echo "TOOL is not authenticated. Run: TOOL auth login" >&2
#   exit 1
# fi
# exit 0

# ┌─────────────────────────────────────────────────────┐
# │ PATTERN B: API-based (env var token)                 │
# │ Delete this block if using CLI-based auth.           │
# │ Does NOT ping the API — just checks the env var.     │
# └─────────────────────────────────────────────────────┘

# DIR="$(pwd)"
# while [ "$DIR" != "/" ]; do
#   [ -f "$DIR/workspace.json" ] && break
#   DIR=$(dirname "$DIR")
# done
# WORKSPACE_JSON="$DIR/workspace.json"
#
# TOKEN_ENV=$(jq -r '.providers."CATEGORY".config.apiTokenEnv' "$WORKSPACE_JSON")
# TOKEN=$(eval echo "\$$TOKEN_ENV")
# if [ -z "$TOKEN" ]; then
#   echo "$TOKEN_ENV is not set" >&2
#   exit 1
# fi
# exit 0

echo "auth-check.sh: not implemented — pick Pattern A or B above" >&2
exit 1
