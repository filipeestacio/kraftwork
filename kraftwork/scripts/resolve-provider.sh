#!/bin/sh
# Usage:
#   resolve-provider.sh script <category> <capability>
#     → prints absolute path to the script (exit 0) or exit 1 if unavailable
#
#   resolve-provider.sh fragment <category> <fragment-name>
#     → prints fragment file content (exit 0) or empty string and exit 1
#
#   resolve-provider.sh has <category> <capability>
#     → exit 0 if capability exists, exit 1 if not
set -eu

MODE="${1:-}"
CATEGORY="${2:-}"
CAPABILITY="${3:-}"

if [ -z "$MODE" ] || [ -z "$CATEGORY" ] || [ -z "$CAPABILITY" ]; then
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

WORKSPACE_ROOT=$("$SCRIPT_DIR/find-workspace.sh" "$(pwd)") || exit 1

WORKSPACE_JSON="$WORKSPACE_ROOT/workspace.json"
if [ ! -f "$WORKSPACE_JSON" ]; then
  exit 1
fi

PLUGIN_NAME=$(jq -r --arg cat "$CATEGORY" '
  .providers[$cat] |
  if type == "string" then .
  elif type == "object" then .plugin // empty
  else empty end
' "$WORKSPACE_JSON")
if [ -z "$PLUGIN_NAME" ]; then
  exit 1
fi

resolve_plugin_root() {
  if [ "$PLUGIN_NAME" = "kraftwork-local" ]; then
    echo "$PLUGIN_ROOT/providers/local"
    return 0
  fi

  SETTINGS="$HOME/.claude/settings.json"
  CACHE_BASE="$HOME/.claude/plugins/cache"

  if [ -f "$SETTINGS" ]; then
    MARKETPLACE=$(jq -r --arg name "$PLUGIN_NAME" '
      .enabledPlugins // {} | keys[] | select(startswith($name + "@")) | split("@")[1] // empty
    ' "$SETTINGS" | head -1)

    if [ -n "$MARKETPLACE" ]; then
      PLUGIN_DIR="$CACHE_BASE/$MARKETPLACE/$PLUGIN_NAME"
      if [ -d "$PLUGIN_DIR" ]; then
        VERSION_DIR=$(ls -1 "$PLUGIN_DIR" | head -1)
        if [ -n "$VERSION_DIR" ] && [ -d "$PLUGIN_DIR/$VERSION_DIR" ]; then
          echo "$PLUGIN_DIR/$VERSION_DIR"
          return 0
        fi
      fi
    fi
  fi

  for MARKETPLACE_DIR in "$CACHE_BASE"/*/; do
    PLUGIN_DIR="${MARKETPLACE_DIR}${PLUGIN_NAME}"
    if [ -d "$PLUGIN_DIR" ]; then
      VERSION_DIR=$(ls -1 "$PLUGIN_DIR" | head -1)
      if [ -n "$VERSION_DIR" ] && [ -d "$PLUGIN_DIR/$VERSION_DIR" ]; then
        echo "$PLUGIN_DIR/$VERSION_DIR"
        return 0
      fi
    fi
  done

  return 1
}

PROVIDER_ROOT=$(resolve_plugin_root) || exit 1

PROVIDERS_JSON="$PROVIDER_ROOT/providers.json"
if [ ! -f "$PROVIDERS_JSON" ]; then
  exit 1
fi

find_capability() {
  local type="$1"
  jq -r --arg cat "$CATEGORY" --arg cap "$CAPABILITY" --arg type "$type" '
    .providers[] | select(.category == $cat) | .[$type][$cap] // empty
  ' "$PROVIDERS_JSON"
}

case "$MODE" in
  script)
    REL_PATH=$(find_capability "scripts")
    if [ -z "$REL_PATH" ]; then
      exit 1
    fi
    ABS_PATH="$PROVIDER_ROOT/$REL_PATH"
    if [ ! -x "$ABS_PATH" ]; then
      exit 1
    fi
    echo "$ABS_PATH"
    ;;

  fragment)
    REL_PATH=$(find_capability "fragments")
    if [ -z "$REL_PATH" ]; then
      exit 1
    fi
    ABS_PATH="$PROVIDER_ROOT/$REL_PATH"
    if [ ! -f "$ABS_PATH" ]; then
      exit 1
    fi
    cat "$ABS_PATH"
    ;;

  has)
    SCRIPT_PATH=$(find_capability "scripts")
    FRAGMENT_PATH=$(find_capability "fragments")
    if [ -n "$SCRIPT_PATH" ] || [ -n "$FRAGMENT_PATH" ]; then
      exit 0
    fi
    exit 1
    ;;

  *)
    exit 1
    ;;
esac
