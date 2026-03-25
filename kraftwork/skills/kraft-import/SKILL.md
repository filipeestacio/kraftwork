---
name: kraft-import
description: Create worktrees for branches that already exist remotely, useful for continuing work started elsewhere.
---

# Workspace Import - Import Existing Branches

Create worktrees for remote branches that already exist, allowing you to continue work started elsewhere or by a teammate.

## Use Cases

- **Continue work from another machine:** Started on laptop, continuing on desktop
- **Pick up abandoned work:** Resume work on an old branch
- **Collaborate on a branch:** Join work a teammate started
- **Post-rebase recovery:** Recreate worktree after rebasing elsewhere

## Scripts Used

| Script | Purpose |
|--------|---------|
| `find-workspace.sh` | Locate workspace root |
| `search-ticket-branches.sh` | Search local/remote branches for ticket |
| `search-ticket-mrs.sh` | Search GitLab MRs (fallback) |

## Script Paths

**IMPORTANT:** Derive the scripts directory from this skill file's location:
- This skill file: `kraftwork/skills/kraft-import/SKILL.md`
- Workspace plugin root: 3 directories up from this file
- Scripts directory: `<workspace-root>/scripts/`

When you load this skill, note its file path and compute the scripts directory. For example, if this skill is at `/path/to/kraftwork/skills/kraft-import/SKILL.md`, then scripts are at `/path/to/kraftwork/scripts/`.

## Workflow

### Step 1: Locate Workspace

```sh
WORKSPACE=$(<scripts-dir>/find-workspace.sh)
if [ $? -ne 0 ]; then
  echo "Workspace not found. Run /kraft-init first."
  exit 1
fi
echo "Workspace: $WORKSPACE"
```

### Step 2: Get Ticket ID

If not provided, ask user:

```
What Jira ticket do you want to import? (e.g., PROJ-1234)
```

### Step 3: Check for Existing Worktree

```sh
EXISTING=$(find "$WORKSPACE/tasks" -maxdepth 1 -type d -name "${TICKET_ID}-*" 2>/dev/null | head -1)

if [ -n "$EXISTING" ]; then
  echo "Worktree already exists: $EXISTING"
fi
```

If exists, ask user: use existing, or remove and reimport?

### Step 4: Search for Remote Branches

```sh
echo "Searching for branches matching $TICKET_ID..."

BRANCH_RESULTS=$(<scripts-dir>/search-ticket-branches.sh "$TICKET_ID" "$WORKSPACE")
BRANCH_COUNT=$(echo "$BRANCH_RESULTS" | jq 'length')

if [ "$BRANCH_COUNT" -gt 0 ]; then
  echo "Found $BRANCH_COUNT matching branches:"
  echo "$BRANCH_RESULTS" | jq -r '.[] | "  \(.repo) → \(.branch) [\(.location)]"'
fi
```

### Step 5: GitLab MR Search (Fallback)

If no branches found:

```sh
if [ "$BRANCH_COUNT" -eq 0 ]; then
  echo "No local branches found. Searching GitLab MRs..."

  MR_RESULTS=$(<scripts-dir>/search-ticket-mrs.sh "$TICKET_ID")
  MR_COUNT=$(echo "$MR_RESULTS" | jq 'length')

  if [ "$MR_COUNT" -gt 0 ]; then
    echo "Found MRs:"
    echo "$MR_RESULTS" | jq -r '.[] | "  \(.repo) - \(.title) [\(.state)]"'
  else
    echo "No branches or MRs found for $TICKET_ID"
    exit 1
  fi
fi
```

### Step 6: Select Branch to Import

If multiple branches found, use AskUserQuestion:

```
Found branches for $TICKET_ID:

1. messaging → PROJ-1234-add-feature
2. frontend → PROJ-1234-ui-updates

Which would you like to import?
```

Options: list branches, or "All" for multi-repo tickets.

### Step 7: Create Worktree Tracking Remote

```sh
REPO_NAME="$SELECTED_REPO"
BRANCH_NAME="$SELECTED_BRANCH"
REPO_PATH="$WORKSPACE/sources/$REPO_NAME"
TASK_DIR="$WORKSPACE/tasks/$BRANCH_NAME"

cd "$REPO_PATH"

# Ensure branch is fetched
git fetch origin "$BRANCH_NAME"

# Create worktree tracking the remote branch
git worktree add --track -b "$BRANCH_NAME" "$TASK_DIR" "origin/$BRANCH_NAME"

echo "Created worktree: $TASK_DIR"
echo "Tracking: origin/$BRANCH_NAME"
```

### Step 8: Setup Spec Directory

```sh
SPEC_DIR="$WORKSPACE/docs/specs/$TICKET_ID"

if [ ! -d "$SPEC_DIR" ]; then
  mkdir -p "$SPEC_DIR"

  cat > "$SPEC_DIR/idea.md" << EOF
# $TICKET_ID

**Imported from:** $BRANCH_NAME

## Context

This worktree was imported from an existing remote branch.

## Notes

_Add notes about the work in progress._
EOF

  echo "Created spec directory: $SPEC_DIR"
else
  echo "Spec directory already exists: $SPEC_DIR"
fi
```

### Step 9: Output Completion

```
Imported worktree for $TICKET_ID

Worktree: $TASK_DIR
Branch: $BRANCH_NAME (tracking origin/$BRANCH_NAME)
Specs: $SPEC_DIR

Branch status:
$(git -C "$TASK_DIR" log --oneline -5)

Next steps:
1. cd "$TASK_DIR"
2. Review current state: git log --oneline -10
3. Continue development or run /kraft-plan if starting fresh
```

## Error Handling

- **No branches found:** Offer GitLab MR search
- **Branch already exists locally:** Ask if user wants to reset to remote
- **Worktree exists:** Offer to use existing or reimport
- **Fetch failed:** Check network/auth, suggest `glab auth status`

## Notes

- Import creates a tracking branch (upstream set to origin)
- Local changes can be pushed with `git push`
- If branch was rebased remotely, may need `git pull --rebase`
