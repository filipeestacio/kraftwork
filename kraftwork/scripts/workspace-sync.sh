#!/bin/sh
#
# workspace-sync.sh - Synchronize all repositories in workspace with remote origins
#
# Usage: workspace-sync.sh [WORKSPACE]
#   WORKSPACE: Path to workspace root (defaults to auto-detected workspace)
#
# Exit codes:
#   0 - Success
#   1 - Workspace not found
#

set -eu

# Determine workspace
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="${1:-$("$SCRIPT_DIR/find-workspace.sh")}"

MODULES_DIR="$WORKSPACE/modules"
if [ ! -d "$MODULES_DIR" ]; then
  MODULES_DIR="$WORKSPACE/sources"
fi

if [ ! -d "$MODULES_DIR" ]; then
  echo "Error: Workspace not found at $WORKSPACE"
  echo "Run kraft-init first or provide workspace path as argument."
  exit 1
fi

MODULES_NAME=$(basename "$MODULES_DIR")

echo "Syncing repositories in $MODULES_DIR..."
echo ""

# Use a temporary file to track counts across subshell
TMPFILE=$(mktemp)
echo "0 0 0 0" > "$TMPFILE"

# Process each repository
find "$MODULES_DIR" -maxdepth 1 -type d ! -name "$MODULES_NAME" | sort | while read -r REPO_PATH; do
  REPO_NAME=$(basename "$REPO_PATH")

  # Skip if not a git repo
  if [ ! -d "$REPO_PATH/.git" ]; then
    echo "⏭️  $REPO_NAME - Not a git repo"
    continue
  fi

  cd "$REPO_PATH"

  # Check for uncommitted changes
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "⏭️  $REPO_NAME - Uncommitted changes"
    continue
  fi

  # Check if on main branch
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
  if [ "$CURRENT_BRANCH" != "main" ] && [ "$CURRENT_BRANCH" != "master" ]; then
    echo "⏭️  $REPO_NAME - Not on main/master ($CURRENT_BRANCH)"
    continue
  fi

  # Fetch from origin
  if ! git fetch origin --quiet 2>/dev/null; then
    echo "❌ $REPO_NAME - Fetch failed"
    continue
  fi

  # Check if behind
  LOCAL=$(git rev-parse HEAD)
  REMOTE=$(git rev-parse "origin/$CURRENT_BRANCH" 2>/dev/null || echo "")

  if [ -z "$REMOTE" ]; then
    echo "❌ $REPO_NAME - No remote branch"
    continue
  fi

  if [ "$LOCAL" = "$REMOTE" ]; then
    echo "✓  $REPO_NAME - Up to date"
    continue
  fi

  # Fast-forward merge
  COMMITS_BEHIND=$(git rev-list --count "HEAD..origin/$CURRENT_BRANCH")
  if git merge --ff-only "origin/$CURRENT_BRANCH" --quiet 2>/dev/null; then
    echo "✅ $REPO_NAME - Pulled $COMMITS_BEHIND commits"
  else
    echo "❌ $REPO_NAME - Merge failed (diverged?)"
  fi
done

# Sync specs directory if it's a git repo
if [ -d "$WORKSPACE/docs/specs/.git" ]; then
  cd "$WORKSPACE/docs/specs"
  if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
    if git fetch origin --quiet 2>/dev/null && git merge --ff-only origin/main --quiet 2>/dev/null; then
      echo "✅ docs/specs/ - Synced"
    fi
  else
    echo "⏭️  docs/specs/ - Uncommitted changes"
  fi
fi

# Count total repos
TOTAL=$(find "$MODULES_DIR" -maxdepth 1 -type d ! -name "$MODULES_NAME" | wc -l | tr -d ' ')

# Clean up
rm -f "$TMPFILE"

echo ""
echo "📊 Sync Complete - $TOTAL repositories processed"
