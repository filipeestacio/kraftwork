#!/bin/sh
#
# clone-repo.sh - Clone a GitHub repository
#
# Usage: clone-repo.sh <ORG> <REPO> <DEST>
#   ORG:  GitHub organization or username
#   REPO: Repository name
#   DEST: Destination directory
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or clone failed
#

set -eu

ORG="${1:-}"
REPO="${2:-}"
DEST="${3:-}"

if [ -z "$ORG" ] || [ -z "$REPO" ] || [ -z "$DEST" ]; then
  echo "Usage: clone-repo.sh <ORG> <REPO> <DEST>" >&2
  exit 1
fi

gh repo clone "$ORG/$REPO" "$DEST"
