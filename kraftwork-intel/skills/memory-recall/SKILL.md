---
name: memory-recall
description: Search the knowledge base for codebase learnings — architecture, patterns, debugging insights. Use when you need context about how something works or why a decision was made.
---

# Intel Query

Search the kraftwork knowledge base for relevant learnings.

## Prerequisites

- `bun` installed
- `kraftwork-intel` plugin installed and configured via `/kraft-config`

## Workflow

### Step 1: Run the search

    ~/.claude/kraftwork-intel/cli query "<search terms>"

Optional filters:

    ~/.claude/kraftwork-intel/cli query "<search terms>" --category architecture
    ~/.claude/kraftwork-intel/cli query "<search terms>" --project api

### Step 2: Present results

Format the results naturally in conversation. Each result includes:
- Content (the learning itself)
- Category and project
- When it was stored
- Relevance score

If no results found, say so clearly. Do not hallucinate answers.
