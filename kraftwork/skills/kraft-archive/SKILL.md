---
name: kraft-archive
description: Archive a completed worktree — generates a searchable summary, moves specs to deep storage, and removes the worktree. Use when done with a ticket.
---

# Workspace Archive - Clean Up Completed Work

Safely archive a completed ticket: generate a searchable summary, move specs to deep storage, and remove the git worktree.

## Scripts Used

| Script | Purpose |
|--------|---------|
| `find-workspace.sh` | Locate workspace root |
| `list-worktrees.sh` | List active worktrees |
| `safety-check.sh` | Check for uncommitted/unpushed changes |

## Script Paths

**IMPORTANT:** Derive the scripts directory from this skill file's location:
- This skill file: `kraftwork/skills/kraft-archive/SKILL.md`
- Workspace plugin root: 3 directories up from this file
- Scripts directory: `<workspace-root>/scripts/`

When you load this skill, note its file path and compute the scripts directory. For example, if this skill is at `/path/to/kraftwork/skills/kraft-archive/SKILL.md`, then scripts are at `/path/to/kraftwork/scripts/`.

## Workflow

### Step 1: Locate Workspace & Target Worktree

```sh
WORKSPACE=$(<scripts-dir>/find-workspace.sh)
```

If user is currently in a worktree:
```sh
WORKTREE_PATH=$(git rev-parse --show-toplevel 2>/dev/null)
TICKET_ID=$(basename "$WORKTREE_PATH" | grep -oE '^[A-Z]+-[0-9]+' || echo "")

if [ -n "$TICKET_ID" ]; then
  echo "Current worktree: $WORKTREE_PATH"
  echo "Ticket: $TICKET_ID"
fi
```

If not in a worktree or ticket ID provided as argument:
```sh
WORKTREE_PATH=$(find "$WORKSPACE/trees" -maxdepth 1 -type d -name "${TICKET_ID}-*" | head -1)
```

If no ticket specified, list active worktrees:
```sh
echo "Active worktrees:"
FORMAT=detail <scripts-dir>/list-worktrees.sh "$WORKSPACE"
```

Then ask user which to archive using AskUserQuestion.

### Step 2: Safety Checks

Run safety check on the worktree:
```sh
SAFETY=$(<scripts-dir>/safety-check.sh "$WORKTREE_PATH" || true)
echo "$SAFETY" | jq .
```

Parse results:
```sh
HAS_UNCOMMITTED=$(echo "$SAFETY" | jq -r '.uncommitted.has_changes')
HAS_UNPUSHED=$(echo "$SAFETY" | jq -r '.unpushed.has_commits')
HAS_OPEN_PR=$(echo "$SAFETY" | jq -r '.open_pr.exists')
PR_URL=$(echo "$SAFETY" | jq -r '.open_pr.url')
```

If any warnings were raised, use AskUserQuestion:

```
Safety checks found potential issues:
- Uncommitted changes: [count] files modified
- Unpushed commits: [count] commits
- Open MR: [url]

Are you sure you want to archive this worktree?
```

Options:
- **Yes, archive anyway** - Proceed with removal
- **No, let me push first** - Abort so user can push
- **No, cancel** - Abort completely

### Step 3: Retro Nudge

Check if a retrospective has been run:
```sh
RETRO_FILE="$WORKSPACE/docs/lessons/${TICKET_ID}-retro.md"
if [ ! -f "$RETRO_FILE" ]; then
  echo "No retrospective found for $TICKET_ID."
fi
```

If no retro file exists, use AskUserQuestion:

```
No retrospective found for $TICKET_ID. Want to run kraft-retro before archiving?
```

Options:
- **Yes, run retro first** - Hand off to kraft-retro, then resume archive from Step 4
- **No, skip retro** - Continue archiving without a retro

### Step 4: Generate Summary

Read available inputs to synthesize a summary. If no spec directory exists (e.g., quick fix or hotfix), generate the summary from the git log and retro only.

1. `$WORKSPACE/docs/specs/$TICKET_ID/spec.md` for intent, requirements, decisions (if exists)
2. `$WORKSPACE/docs/specs/$TICKET_ID/tasks.md` for planned scope (if exists)
3. `$WORKSPACE/docs/specs/$TICKET_ID/changes/` for mid-implementation pivots (if directory exists)
4. `$WORKSPACE/docs/lessons/${TICKET_ID}-retro.md` for lessons and outcome (if file exists)
5. Git log for the branch:
```sh
BRANCH=$(git -C "$WORKTREE_PATH" branch --show-current)
git -C "$WORKTREE_PATH" log --oneline main..$BRANCH
```

Tone: factual, compressed, skimmable in 10 seconds.

Synthesize into a summary following this format:

```markdown
# TICKET_ID: Short title from spec

## What changed
Brief description of the work delivered (2-4 sentences).

## Key decisions
- Decision and rationale
- Rejected alternative and why

## Areas touched
- `path/to/module/` — what was changed
- `path/to/other/` — what was changed

## Outcome
Merged via MR !number on YYYY-MM-DD. (Or: abandoned, split, etc.)

---
Archived specs: `docs/archive/TICKET_ID/`
```

Show the draft summary to the user before writing. If the user requests changes, revise and re-present until approved.

Write the approved summary:
```sh
mkdir -p "$WORKSPACE/docs/summaries"
```
Then use the Write tool to create `$WORKSPACE/docs/summaries/$TICKET_ID.md`.

### Step 5: Archive Specs

Move the spec directory to deep storage (skip if no spec directory exists):
```sh
if [ -d "$WORKSPACE/docs/specs/$TICKET_ID" ]; then
  mkdir -p "$WORKSPACE/docs/archive"
  mv "$WORKSPACE/docs/specs/$TICKET_ID" "$WORKSPACE/docs/archive/$TICKET_ID"
  echo "Specs archived to: $WORKSPACE/docs/archive/$TICKET_ID/"
fi
```

### Step 6: Remove Worktree

If currently inside the worktree, navigate away first:
```sh
cd "$WORKSPACE"
echo "Moved to: $(pwd)"
```

Remove the worktree:
```sh
BRANCH=$(git -C "$WORKTREE_PATH" branch --show-current)

GIT_DIR=$(git -C "$WORKTREE_PATH" rev-parse --git-dir)
SOURCE_REPO=$(echo "$GIT_DIR" | sed 's|/\.git/worktrees/.*|/.git|' | xargs dirname)

git -C "$SOURCE_REPO" worktree remove "$WORKTREE_PATH"
git -C "$SOURCE_REPO" worktree prune

echo "Worktree removed: $WORKTREE_PATH"
```

### Step 7: Completion Output

```
Archived TICKET_ID

  Summary:  docs/summaries/TICKET_ID.md
  Specs:    docs/archive/TICKET_ID/
  Worktree: removed
  Branch:   still exists (local + remote)
```

## Safety Principles

1. **Never force-remove with uncommitted changes** without explicit user confirmation
2. **Always check for unpushed commits** before removing
3. **Warn about open MRs** - user might lose context
4. **Navigate away first** - prevents "cannot remove current directory" errors
5. **Always generate a summary before archiving specs** - completed work must leave a searchable trace
