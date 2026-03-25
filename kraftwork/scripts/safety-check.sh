#!/bin/sh
#
# safety-check.sh - Check a git directory for uncommitted/unpushed changes
#
# Usage: safety-check.sh [PATH]
#   PATH: Git directory to check (defaults to pwd)
#
# Exit codes:
#   0 - Clean (no issues)
#   1 - Not a git repository
#   2 - Has uncommitted changes
#   3 - Has unpushed commits
#   4 - Has both uncommitted and unpushed
#
# Output: JSON object with check results
#

set -eu

TARGET="${1:-$(pwd)}"

# Verify it's a git repo
if ! git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
  echo '{"error": "not a git repository", "path": "'"$TARGET"'"}'
  exit 1
fi

cd "$TARGET"

# Initialize results
HAS_UNCOMMITTED=0
HAS_UNPUSHED=0
UNCOMMITTED_FILES=""
UNPUSHED_COMMITS=""
BRANCH=$(git branch --show-current 2>/dev/null || echo "HEAD")

# Check for uncommitted changes
PORCELAIN=$(git status --porcelain 2>/dev/null)
if [ -n "$PORCELAIN" ]; then
  HAS_UNCOMMITTED=1
  UNCOMMITTED_COUNT=$(echo "$PORCELAIN" | wc -l | tr -d ' ')
  # Get first few files
  UNCOMMITTED_FILES=$(echo "$PORCELAIN" | head -5 | while read -r line; do
    printf '%s\\n' "$line"
  done)
fi

# Check for unpushed commits
if git rev-parse "origin/$BRANCH" >/dev/null 2>&1; then
  UNPUSHED=$(git log "origin/$BRANCH..$BRANCH" --oneline 2>/dev/null || echo "")
  if [ -n "$UNPUSHED" ]; then
    HAS_UNPUSHED=1
    UNPUSHED_COUNT=$(echo "$UNPUSHED" | wc -l | tr -d ' ')
    UNPUSHED_COMMITS=$(echo "$UNPUSHED" | head -5 | while read -r line; do
      printf '%s\\n' "$line"
    done)
  fi
fi

# Check for open MR (requires glab)
HAS_OPEN_MR=0
MR_URL=""
if command -v glab >/dev/null 2>&1; then
  MR_INFO=$(glab mr view "$BRANCH" --json state,webUrl 2>/dev/null || echo "")
  if [ -n "$MR_INFO" ]; then
    MR_STATE=$(echo "$MR_INFO" | grep -o '"state":"[^"]*"' | cut -d'"' -f4 || echo "")
    if [ "$MR_STATE" = "opened" ]; then
      HAS_OPEN_MR=1
      MR_URL=$(echo "$MR_INFO" | grep -o '"webUrl":"[^"]*"' | cut -d'"' -f4 || echo "")
    fi
  fi
fi

# Output JSON
cat <<EOF
{
  "path": "$TARGET",
  "branch": "$BRANCH",
  "clean": $([ "$HAS_UNCOMMITTED" = "0" ] && [ "$HAS_UNPUSHED" = "0" ] && echo "true" || echo "false"),
  "uncommitted": {
    "has_changes": $([ "$HAS_UNCOMMITTED" = "1" ] && echo "true" || echo "false"),
    "count": ${UNCOMMITTED_COUNT:-0}
  },
  "unpushed": {
    "has_commits": $([ "$HAS_UNPUSHED" = "1" ] && echo "true" || echo "false"),
    "count": ${UNPUSHED_COUNT:-0}
  },
  "open_mr": {
    "exists": $([ "$HAS_OPEN_MR" = "1" ] && echo "true" || echo "false"),
    "url": "$MR_URL"
  }
}
EOF

# Set exit code
if [ "$HAS_UNCOMMITTED" = "1" ] && [ "$HAS_UNPUSHED" = "1" ]; then
  exit 4
elif [ "$HAS_UNPUSHED" = "1" ]; then
  exit 3
elif [ "$HAS_UNCOMMITTED" = "1" ]; then
  exit 2
else
  exit 0
fi
