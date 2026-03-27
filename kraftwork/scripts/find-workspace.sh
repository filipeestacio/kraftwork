#!/bin/sh
set -eu

START_DIR="${1:-$(pwd)}"

DIR="$START_DIR"
while [ "$DIR" != "/" ]; do
  if [ -f "$DIR/workspace.json" ]; then
    echo "$DIR"
    exit 0
  fi
  DIR=$(dirname "$DIR")
done

DIR="$START_DIR"
while [ "$DIR" != "/" ]; do
  if [ -d "$DIR/modules" ]; then
    echo "$DIR"
    exit 0
  fi
  DIR=$(dirname "$DIR")
done

DIR="$START_DIR"
while [ "$DIR" != "/" ]; do
  if [ -d "$DIR/sources" ]; then
    echo "$DIR"
    exit 0
  fi
  DIR=$(dirname "$DIR")
done

echo "Error: Workspace not found" >&2
echo "Searched from: $START_DIR" >&2
exit 1
