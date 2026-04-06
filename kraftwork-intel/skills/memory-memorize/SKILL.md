---
name: memory-memorize
description: Store a learning about the codebase — architecture decisions, patterns, debugging insights, conventions. Use when you discover something worth remembering across sessions.
---

# Intel Store

Save a codebase learning to the knowledge store for retrieval in future sessions.

## Prerequisites

- `bun` installed
- `kraftwork-intel` plugin installed and configured via `/kraft-config`

## Workflow

### Step 1: Identify what to store

Determine:
- **Content**: The actual knowledge (1-3 sentences, precise)
- **Category**: `architecture`, `pattern`, `debugging`, or `convention`
- **Project**: Which repo or area this relates to (e.g., `api`, `frontend`)
- **Supersedes** (optional): If this replaces a previous learning, find its ID first

### Step 2: Store the learning

    ~/.claude/kraftwork-intel/cli store \
      --category "<category>" \
      --project "<project>" \
      --content "<the learning>"

If superseding a previous learning:

    ~/.claude/kraftwork-intel/cli store \
      --category "<category>" \
      --project "<project>" \
      --supersedes "<previous-learning-id>" \
      --content "<the updated learning>"

### Step 3: Confirm storage

The CLI outputs the new learning's ID. Confirm to the user what was stored.
