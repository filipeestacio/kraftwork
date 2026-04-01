#!/bin/sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INTERFACES_DIR="$PLUGIN_ROOT/interfaces"

PROVIDER_ROOT="${1:-}"
if [ -z "$PROVIDER_ROOT" ] || [ ! -d "$PROVIDER_ROOT" ]; then
  echo "Usage: validate-provider.sh <path-to-extension-root>" >&2
  exit 1
fi

PROVIDERS_JSON="$PROVIDER_ROOT/providers.json"
if [ ! -f "$PROVIDERS_JSON" ]; then
  echo "FAIL: No providers.json found at $PROVIDER_ROOT" >&2
  exit 1
fi

PLUGIN_NAME=$(basename "$PROVIDER_ROOT")
EXIT_CODE=0

CATEGORIES=$(jq -r '.providers[].category' "$PROVIDERS_JSON")

for CATEGORY in $CATEGORIES; do
  INTERFACE_FILE="$INTERFACES_DIR/$CATEGORY.json"
  if [ ! -f "$INTERFACE_FILE" ]; then
    echo "WARN: $PLUGIN_NAME declares unknown category '$CATEGORY' — no interface definition found"
    continue
  fi

  REQUIRED_SKILLS=$(jq -r '.skills.required[]' "$INTERFACE_FILE")
  DECLARED_SKILLS=$(jq -r --arg cat "$CATEGORY" '.providers[] | select(.category == $cat) | .skills // [] | .[]' "$PROVIDERS_JSON")

  for SKILL in $REQUIRED_SKILLS; do
    DECLARED=$(echo "$DECLARED_SKILLS" | grep -qx "$SKILL" && echo "yes" || echo "no")
    SKILL_DIR="$PROVIDER_ROOT/skills/${CATEGORY}-${SKILL}"
    SKILL_FILE="$SKILL_DIR/SKILL.md"

    if [ "$DECLARED" = "no" ]; then
      echo "MISSING: $PLUGIN_NAME does not declare '$CATEGORY/$SKILL' (required by interface)"
      EXIT_CODE=1
      continue
    fi

    if [ ! -f "$SKILL_FILE" ]; then
      echo "DECLARED BUT ABSENT: $PLUGIN_NAME declares '$CATEGORY/$SKILL' but $SKILL_FILE does not exist"
      EXIT_CODE=1
      continue
    fi

    IS_STUB=$(head -10 "$SKILL_FILE" | grep -c "^stub: true" || true)
    if [ "$IS_STUB" -gt 0 ]; then
      echo "STUB: $PLUGIN_NAME/$CATEGORY-$SKILL is a stub"
    else
      echo "OK: $PLUGIN_NAME/$CATEGORY-$SKILL"
    fi
  done

  for SKILL in $DECLARED_SKILLS; do
    REQUIRED=$(echo "$REQUIRED_SKILLS" | grep -qx "$SKILL" && echo "yes" || echo "no")
    if [ "$REQUIRED" = "no" ]; then
      echo "EXTRA: $PLUGIN_NAME declares '$CATEGORY/$SKILL' which is not in the interface (allowed but unusual)"
    fi
  done
done

exit $EXIT_CODE
