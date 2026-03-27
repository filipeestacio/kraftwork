#!/bin/sh
#
# auth-check.sh - Verify gh is installed and authenticated
#
# Usage: auth-check.sh
#
# Exit codes:
#   0 - gh installed and authenticated
#   1 - gh missing or not authenticated
#

set -eu

if ! command -v gh >/dev/null 2>&1; then
  echo "gh is not installed. Install it via: brew install gh" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "gh is not authenticated. Run: gh auth login" >&2
  exit 1
fi
