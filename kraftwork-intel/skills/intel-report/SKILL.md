---
name: intel-report
description: Show skill usage metrics and session statistics. Use when the user asks about skill usage patterns, workflow stats, or wants to see what's been happening.
---

# Intel Report

Show usage metrics from the kraftwork intelligence layer.

## Prerequisites

- `bun` installed
- `~/.claude/kraftwork-intel/` initialized (run `bun install` in that directory if needed)

## Workflow

### Step 1: Determine what the user wants to see

Options:
- **General overview** — all skill usage stats
- **Specific skill** — detailed history for one skill
- **Time-filtered** — last N days of activity

### Step 2: Run the report

For general overview:

    bun run ~/.claude/kraftwork-intel/src/cli.ts report

For a specific skill:

    bun run ~/.claude/kraftwork-intel/src/cli.ts report --skill "<skill-name>"

For time-filtered:

    bun run ~/.claude/kraftwork-intel/src/cli.ts report --days <N>

### Step 3: Present results

Format the JSON output as a readable summary. Include:
- Skill name, usage count, success rate
- Average duration if available
- Last used timestamp
- Highlight any skills with low success rates (below 0.7)
