#!/bin/sh
#
# clone-repo.sh - Clone a GitLab repository
#
# Usage: clone-repo.sh <GROUP> <REPO> <DEST>
#   GROUP: GitLab group/namespace (e.g., my-org/backend)
#   REPO:  Repository name
#   DEST:  Destination directory
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or clone failed
#

set -eu

GROUP="${1:-}"
REPO="${2:-}"
DEST="${3:-}"

if [ -z "$GROUP" ] || [ -z "$REPO" ] || [ -z "$DEST" ]; then
  echo "Usage: clone-repo.sh <GROUP> <REPO> <DEST>" >&2
  exit 1
fi

glab repo clone "$GROUP/$REPO" "$DEST"
