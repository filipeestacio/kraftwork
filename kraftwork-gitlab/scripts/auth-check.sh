#!/bin/sh
#
# auth-check.sh - Verify glab is installed and authenticated
#
# Usage: auth-check.sh
#
# Exit codes:
#   0 - glab installed and authenticated
#   1 - glab missing or not authenticated
#

set -eu

if ! command -v glab >/dev/null 2>&1; then
  echo "glab is not installed. Install it via: brew install glab" >&2
  exit 1
fi

if ! glab auth status >/dev/null 2>&1; then
  echo "glab is not authenticated. Run: glab auth login" >&2
  exit 1
fi
