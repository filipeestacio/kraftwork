#!/bin/sh
#
# create-worktree.sh - Create a git worktree for a feature branch
#
# Usage: create-worktree.sh <REPO_PATH> <BRANCH_NAME> <WORKTREE_PATH> [BASE_BRANCH]
#   REPO_PATH: Path to the source repository
#   BRANCH_NAME: Name for the new branch
#   WORKTREE_PATH: Path where worktree will be created
#   BASE_BRANCH: Branch to base off (defaults to "main")
#
# Exit codes:
#   0 - Success
#   1 - Invalid arguments
#   2 - Repository not found
#   3 - Worktree path already exists
#   4 - Branch already exists
#   5 - Git operation failed
#

set -eu

REPO_PATH="${1:-}"
BRANCH_NAME="${2:-}"
WORKTREE_PATH="${3:-}"
BASE_BRANCH="${4:-main}"

# Validate arguments
if [ -z "$REPO_PATH" ] || [ -z "$BRANCH_NAME" ] || [ -z "$WORKTREE_PATH" ]; then
  echo "Usage: create-worktree.sh <REPO_PATH> <BRANCH_NAME> <WORKTREE_PATH> [BASE_BRANCH]" >&2
  exit 1
fi

# Check repo exists
if [ ! -d "$REPO_PATH/.git" ]; then
  echo "Error: Repository not found at $REPO_PATH" >&2
  exit 2
fi

# Check worktree path doesn't exist
if [ -e "$WORKTREE_PATH" ]; then
  echo "Error: Path already exists: $WORKTREE_PATH" >&2
  exit 3
fi

# Check branch doesn't already exist
if git -C "$REPO_PATH" show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
  echo "Error: Branch already exists: $BRANCH_NAME" >&2
  echo "Use 'git worktree add' directly to create worktree from existing branch" >&2
  exit 4
fi

# Fetch latest from origin
echo "Fetching latest from origin..."
if ! git -C "$REPO_PATH" fetch origin --quiet 2>/dev/null; then
  echo "Warning: Could not fetch from origin" >&2
fi

# Try to fast-forward base branch if we're on it
CURRENT_BRANCH=$(git -C "$REPO_PATH" branch --show-current 2>/dev/null || echo "")
if [ "$CURRENT_BRANCH" = "$BASE_BRANCH" ]; then
  git -C "$REPO_PATH" merge --ff-only "origin/$BASE_BRANCH" --quiet 2>/dev/null || true
fi

# Verify base branch exists
if ! git -C "$REPO_PATH" show-ref --verify --quiet "refs/heads/$BASE_BRANCH" 2>/dev/null; then
  # Try remote
  if ! git -C "$REPO_PATH" show-ref --verify --quiet "refs/remotes/origin/$BASE_BRANCH" 2>/dev/null; then
    echo "Error: Base branch not found: $BASE_BRANCH" >&2
    exit 5
  fi
  # Use remote as base
  BASE_REF="origin/$BASE_BRANCH"
else
  BASE_REF="$BASE_BRANCH"
fi

# Create parent directory if needed
PARENT_DIR=$(dirname "$WORKTREE_PATH")
if [ ! -d "$PARENT_DIR" ]; then
  mkdir -p "$PARENT_DIR"
fi

# Create the worktree with new branch
echo "Creating worktree..."
if ! git -C "$REPO_PATH" worktree add -b "$BRANCH_NAME" "$WORKTREE_PATH" "$BASE_REF" 2>&1; then
  echo "Error: Failed to create worktree" >&2
  exit 5
fi

# Output success info as JSON
REPO_NAME=$(basename "$REPO_PATH")
cat <<EOF
{
  "success": true,
  "worktree": "$WORKTREE_PATH",
  "branch": "$BRANCH_NAME",
  "base": "$BASE_REF",
  "repo": "$REPO_NAME"
}
EOF
