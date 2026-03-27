#!/bin/sh
#
# fetch-pr-details.sh - Fetch full details of a GitHub pull request
#
# Usage: fetch-pr-details.sh <PR_NUMBER>
#   PR_NUMBER: Pull request number (must be run from within a git repo)
#
# Output: JSON object with details, discussions, changes, and commits
#   {"details": {...}, "discussions": [...], "changes": {...}, "commits": [...]}
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or not in a git repo
#

set -eu

PR_NUMBER="${1:-}"

if [ -z "$PR_NUMBER" ]; then
  echo "Usage: fetch-pr-details.sh <PR_NUMBER>" >&2
  exit 1
fi

REMOTE_URL=$(git remote get-url origin 2>/dev/null) || {
  echo "Not inside a git repository or no origin remote" >&2
  exit 1
}

REPO_SLUG=$(echo "$REMOTE_URL" | sed -E 's|^https://github\.com/||; s|^git@github\.com:||; s|\.git$||')

DETAILS=$(gh api "repos/${REPO_SLUG}/pulls/${PR_NUMBER}" 2>/dev/null || echo '{}')
REVIEWS=$(gh api "repos/${REPO_SLUG}/pulls/${PR_NUMBER}/reviews" 2>/dev/null || echo '[]')
COMMENTS=$(gh api "repos/${REPO_SLUG}/pulls/${PR_NUMBER}/comments" 2>/dev/null || echo '[]')
COMMITS=$(gh api "repos/${REPO_SLUG}/pulls/${PR_NUMBER}/commits?per_page=100" 2>/dev/null || echo '[]')
FILES=$(gh api "repos/${REPO_SLUG}/pulls/${PR_NUMBER}/files?per_page=100" 2>/dev/null || echo '[]')

DISCUSSIONS=$(jq -n --argjson reviews "$REVIEWS" --argjson comments "$COMMENTS" '$reviews + $comments')

jq -n \
  --argjson details "$DETAILS" \
  --argjson discussions "$DISCUSSIONS" \
  --argjson changes "$FILES" \
  --argjson commits "$COMMITS" \
  '{details: $details, discussions: $discussions, changes: $changes, commits: $commits}'
