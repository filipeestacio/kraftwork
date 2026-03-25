#!/bin/sh
set -eu

if [ $# -lt 2 ]; then
  echo "Usage: read-config.sh <section> <key>" >&2
  exit 1
fi

SECTION="$1"
KEY="$2"
START_DIR="${3:-$(pwd)}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_ROOT=$("$SCRIPT_DIR/find-workspace.sh" "$START_DIR")

CONFIG="$WORKSPACE_ROOT/workspace.json"
if [ ! -f "$CONFIG" ]; then
  echo "Error: workspace.json not found at $WORKSPACE_ROOT" >&2
  echo "Run /kraft-init to configure." >&2
  exit 1
fi

VALUE=$(jq -r --arg s "$SECTION" --arg k "$KEY" '.[$s][$k] // empty' "$CONFIG")

if [ -z "$VALUE" ]; then
  echo "Error: Missing config key '$SECTION.$KEY'" >&2
  echo "Run /kraft-init to configure." >&2
  exit 1
fi

echo "$VALUE"
