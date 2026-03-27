---
name: kraft-archive
description: Clean up a completed worktree with safety checks to prevent data loss. Use when done with a ticket.
---

# Workspace Archive - Clean Up Completed Work

Safely remove a git worktree for a completed ticket, with checks to prevent accidental data loss.

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

### Step 1: Locate Workspace

```sh
WORKSPACE=$(<scripts-dir>/find-workspace.sh)
```

### Step 2: Determine Target Worktree

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

### Step 3: Safety Checks

Run safety check on the worktree:
```sh
SAFETY=$(<scripts-dir>/safety-check.sh "$WORKTREE_PATH")
echo "$SAFETY" | jq .
```

Parse results:
```sh
HAS_UNCOMMITTED=$(echo "$SAFETY" | jq -r '.uncommitted.has_changes')
HAS_UNPUSHED=$(echo "$SAFETY" | jq -r '.unpushed.has_commits')
HAS_OPEN_PR=$(echo "$SAFETY" | jq -r '.open_pr.exists')
PR_URL=$(echo "$SAFETY" | jq -r '.open_pr.url')
```

### Step 4: Confirm with User

If any warnings were raised, use AskUserQuestion:

```
Safety checks found potential issues:
- Uncommitted changes: [count] files modified
- Unpushed commits: [count] commits
- Open PR: [url]

Are you sure you want to archive this worktree?
```

Options:
- **Yes, archive anyway** - Proceed with removal
- **No, let me push first** - Abort so user can push
- **No, cancel** - Abort completely

### Step 5: Navigate Away from Worktree

If currently inside the worktree:
```sh
cd "$WORKSPACE"
echo "Moved to: $(pwd)"
```

### Step 6: Remove Worktree

```sh
BRANCH=$(git -C "$WORKTREE_PATH" branch --show-current)

# Find the source repo
GIT_DIR=$(git -C "$WORKTREE_PATH" rev-parse --git-dir)
SOURCE_REPO=$(echo "$GIT_DIR" | sed 's|/\.git/worktrees/.*|/.git|' | xargs dirname)

# Remove the worktree
git -C "$SOURCE_REPO" worktree remove "$WORKTREE_PATH"

echo "Worktree removed: $WORKTREE_PATH"
```

### Step 7: Prune Worktree References

```sh
git -C "$SOURCE_REPO" worktree prune
```

### Step 8: Handle Spec Directory

Ask user what to do with specs using AskUserQuestion:

```
What should happen to the spec files at $WORKSPACE/docs/specs/$TICKET_ID?
```

Options:
- **Keep** (default) - Leave specs in place
- **Archive** - Move to `$WORKSPACE/docs/specs/.archive/$TICKET_ID`
- **Delete** - Remove specs entirely

```sh
SPEC_DIR="$WORKSPACE/docs/specs/$TICKET_ID"

case "$CHOICE" in
  archive)
    mkdir -p "$WORKSPACE/docs/specs/.archive"
    mv "$SPEC_DIR" "$WORKSPACE/docs/specs/.archive/"
    echo "Specs archived to: $WORKSPACE/docs/specs/.archive/$TICKET_ID"
    ;;
  delete)
    rm -rf "$SPEC_DIR"
    echo "Specs deleted"
    ;;
  *)
    echo "Specs kept at: $SPEC_DIR"
    ;;
esac
```

### Step 9: Output Completion

```
Archived worktree for $TICKET_ID

Removed:
- Worktree: $WORKTREE_PATH
- Branch: $BRANCH (still exists locally and on remote)

Kept:
- Specs: $WORKSPACE/docs/specs/$TICKET_ID

Note: The branch still exists. To delete it:
  git branch -d $BRANCH           # Delete local
  git push origin --delete $BRANCH  # Delete remote
```

## Safety Principles

1. **Never force-remove with uncommitted changes** without explicit user confirmation
2. **Always check for unpushed commits** before removing
3. **Warn about open PRs** - user might lose context
4. **Keep specs by default** - they might be needed later
5. **Navigate away first** - prevents "cannot remove current directory" errors
