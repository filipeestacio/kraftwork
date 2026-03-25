#!/bin/sh
# worktree-status.sh - Get detailed status for worktrees
# Usage: worktree-status.sh <workspace> [worktree-name]
# If worktree-name provided, show status for that worktree only
# Otherwise show status for all worktrees

set -eu

WORKSPACE="${1:-}"
FILTER_NAME="${2:-}"

if [ -z "$WORKSPACE" ]; then
  echo "Usage: worktree-status.sh <workspace> [worktree-name]" >&2
  exit 1
fi

TASKS_DIR="$WORKSPACE/tasks"
SPECS_DIR="$WORKSPACE/docs/specs"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "$TASKS_DIR" ]; then
  echo "No tasks directory found at $TASKS_DIR" >&2
  exit 1
fi

# Get list of worktrees
if [ -n "$FILTER_NAME" ]; then
  # Single worktree mode
  if [ -d "$TASKS_DIR/$FILTER_NAME" ]; then
    WORKTREES="$TASKS_DIR/$FILTER_NAME"
  else
    # Try to find by ticket ID prefix
    WORKTREES=$(find "$TASKS_DIR" -maxdepth 1 -type d -name "${FILTER_NAME}*" 2>/dev/null | head -1)
    if [ -z "$WORKTREES" ]; then
      echo "Worktree not found: $FILTER_NAME" >&2
      exit 1
    fi
  fi
else
  # All worktrees mode
  WORKTREES=$(find "$TASKS_DIR" -maxdepth 1 -type d ! -name "tasks" 2>/dev/null | sort)
fi

# Output format: JSON array
echo "["
FIRST=true

for WT_PATH in $WORKTREES; do
  [ -d "$WT_PATH" ] || continue
  [ "$WT_PATH" = "$TASKS_DIR" ] && continue

  WT_NAME=$(basename "$WT_PATH")
  TICKET_ID=$(echo "$WT_NAME" | grep -oE '^[A-Z]+-[0-9]+' || echo "unknown")
  SPEC_DIR="$SPECS_DIR/$TICKET_ID"

  # Get safety status
  if [ -x "$SCRIPT_DIR/safety-check.sh" ]; then
    SAFETY=$("$SCRIPT_DIR/safety-check.sh" "$WT_PATH" 2>/dev/null || echo '{"clean":true}')
    HAS_UNCOMMITTED=$(echo "$SAFETY" | grep -o '"has_changes":[^,}]*' | head -1 | sed 's/.*://' | tr -d ' ')
    HAS_UNPUSHED=$(echo "$SAFETY" | grep -o '"has_commits":[^,}]*' | head -1 | sed 's/.*://' | tr -d ' ')
  else
    HAS_UNCOMMITTED="unknown"
    HAS_UNPUSHED="unknown"
  fi

  # Default values
  [ -z "$HAS_UNCOMMITTED" ] && HAS_UNCOMMITTED="false"
  [ -z "$HAS_UNPUSHED" ] && HAS_UNPUSHED="false"

  # Determine planning state
  if [ -f "$SPEC_DIR/tasks.md" ]; then
    TOTAL=$(grep -c '^\- \[' "$SPEC_DIR/tasks.md" 2>/dev/null || echo 0)
    COMPLETE=$(grep -c '^\- \[x\]' "$SPEC_DIR/tasks.md" 2>/dev/null || echo 0)
    PHASE="implementing"
    PROGRESS="$COMPLETE/$TOTAL tasks"
  elif [ -f "$SPEC_DIR/spec.md" ]; then
    PHASE="spec_ready"
    PROGRESS="ready for tasks"
  elif [ -f "$SPEC_DIR/idea.md" ]; then
    PHASE="planning"
    PROGRESS="idea captured"
  else
    PHASE="new"
    PROGRESS="no specs yet"
  fi

  # Check for pending changes
  CHANGES_INDEX="$SPEC_DIR/changes/index.md"
  if [ -f "$CHANGES_INDEX" ]; then
    PENDING=$(grep -c '| pending |' "$CHANGES_INDEX" 2>/dev/null || echo 0)
  else
    PENDING=0
  fi

  # Get repo name from git
  if cd "$WT_PATH" 2>/dev/null; then
    REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
    BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
  else
    REPO="unknown"
    BRANCH="unknown"
  fi

  # Output JSON object
  if [ "$FIRST" = "true" ]; then
    FIRST=false
  else
    echo ","
  fi

  cat << EOF
  {
    "name": "$WT_NAME",
    "path": "$WT_PATH",
    "ticket": "$TICKET_ID",
    "repo": "$REPO",
    "branch": "$BRANCH",
    "phase": "$PHASE",
    "progress": "$PROGRESS",
    "uncommitted": $HAS_UNCOMMITTED,
    "unpushed": $HAS_UNPUSHED,
    "pending_changes": $PENDING,
    "spec_dir": "$SPEC_DIR"
  }
EOF
done

echo ""
echo "]"
