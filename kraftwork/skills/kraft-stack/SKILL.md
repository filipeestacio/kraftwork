---
name: kraft-stack
description: Create a new worktree branching from the current worktree, useful for dependent features or stacked diffs.
---

# Workspace Stack - Create Dependent Worktree

Create a new worktree that branches off an existing worktree's HEAD, useful for dependent features or stacked PRs.

## Use Cases

- **Stacked PRs:** Build feature B on top of feature A before A is merged
- **Dependent features:** Create a follow-up ticket that depends on current work
- **Incremental reviews:** Split large changes into reviewable chunks

## Scripts Used

| Script | Purpose |
|--------|---------|
| `find-workspace.sh` | Locate workspace root |
| `safety-check.sh` | Check for uncommitted changes |

## Script Paths

**IMPORTANT:** Derive the scripts directory from this skill file's location:
- This skill file: `kraftwork/skills/kraft-stack/SKILL.md`
- Workspace plugin root: 3 directories up from this file
- Scripts directory: `<workspace-root>/scripts/`

When you load this skill, note its file path and compute the scripts directory. For example, if this skill is at `/path/to/kraftwork/skills/kraft-stack/SKILL.md`, then scripts are at `/path/to/kraftwork/scripts/`.

## Workflow

### Step 1: Validate Current Worktree

```sh
WORKTREE_PATH=$(git rev-parse --show-toplevel 2>/dev/null)

# Check if in a tasks directory
case "$WORKTREE_PATH" in
  */tasks/*)
    ;;
  *)
    echo "Not in a worktree. Run /kraft-start first."
    exit 1
    ;;
esac

PARENT_TICKET=$(basename "$WORKTREE_PATH" | grep -oE '^[A-Z]+-[0-9]+' || echo "")
PARENT_BRANCH=$(git branch --show-current)
WORKSPACE=$(dirname "$(dirname "$WORKTREE_PATH")")

echo "Current worktree: $WORKTREE_PATH"
echo "Parent ticket: $PARENT_TICKET"
echo "Parent branch: $PARENT_BRANCH"
```

### Step 2: Get New Ticket ID

Ask user for the new ticket:

```
What Jira ticket is the stacked work for? (e.g., PROJ-5678)
```

### Step 3: Validate No Conflicts

```sh
EXISTING=$(find "$WORKSPACE/tasks" -maxdepth 1 -type d -name "${NEW_TICKET_ID}-*" 2>/dev/null | head -1)

if [ -n "$EXISTING" ]; then
  echo "Worktree already exists for $NEW_TICKET_ID: $EXISTING"
  exit 1
fi
```

### Step 4: Check for Uncommitted Changes

```sh
SAFETY=$(<scripts-dir>/safety-check.sh "$WORKTREE_PATH")
HAS_UNCOMMITTED=$(echo "$SAFETY" | jq -r '.uncommitted.has_changes')

if [ "$HAS_UNCOMMITTED" = "true" ]; then
  echo "WARNING: Parent worktree has uncommitted changes"
  echo "$SAFETY" | jq -r '.uncommitted'
fi
```

If uncommitted changes, use AskUserQuestion:
- **Commit first** - Stop and let user commit
- **Stash** - Stash changes before continuing
- **Continue anyway** - Proceed (not recommended)

### Step 5: Fetch Ticket Summary (Optional)

```sh
if command -v acli >/dev/null 2>&1; then
  TICKET_JSON=$(acli jira workitem view "$NEW_TICKET_ID" --fields summary --json 2>/dev/null || echo "{}")
  SUMMARY=$(echo "$TICKET_JSON" | jq -r '.fields.summary // empty')
fi

if [ -z "$SUMMARY" ]; then
  echo "Could not fetch ticket summary. Please provide a description:"
  # Ask user for description
fi
```

### Step 6: Generate Branch Name

```sh
SLUG=$(echo "$SUMMARY" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//' | cut -c1-50)
NEW_BRANCH="${NEW_TICKET_ID}-${SLUG}"
NEW_TASK_DIR="$WORKSPACE/tasks/${NEW_BRANCH}"

echo "New branch: $NEW_BRANCH"
echo "New worktree: $NEW_TASK_DIR"
```

### Step 7: Create Stacked Worktree

```sh
cd "$WORKTREE_PATH"

# Create worktree from current HEAD (not from main)
git worktree add -b "$NEW_BRANCH" "$NEW_TASK_DIR"

echo "Created stacked worktree at: $NEW_TASK_DIR"
echo "Base: $PARENT_BRANCH @ $(git rev-parse --short HEAD)"
```

### Step 8: Setup Spec Directory with Stack Context

```sh
NEW_SPEC_DIR="$WORKSPACE/docs/specs/$NEW_TICKET_ID"
mkdir -p "$NEW_SPEC_DIR"

cat > "$NEW_SPEC_DIR/idea.md" << EOF
# $NEW_TICKET_ID

**Summary:** $SUMMARY

## Stack Context

This ticket is stacked on top of:
- **Parent ticket:** $PARENT_TICKET
- **Parent branch:** $PARENT_BRANCH
- **Parent worktree:** $WORKTREE_PATH

## Dependencies

This work depends on $PARENT_TICKET being completed/merged first.

## Initial Notes

_Add your initial thoughts and requirements here._
EOF

echo "Created spec directory: $NEW_SPEC_DIR"
```

### Step 9: Output Completion

```
Created stacked worktree for $NEW_TICKET_ID

Stack Structure:
  $PARENT_TICKET ($PARENT_BRANCH)
    └── $NEW_TICKET_ID ($NEW_BRANCH)

Worktrees:
  Parent: $WORKTREE_PATH
  Child:  $NEW_TASK_DIR

Specs:
  Parent: $WORKSPACE/docs/specs/$PARENT_TICKET/
  Child:  $NEW_SPEC_DIR/

Next steps:
1. cd "$NEW_TASK_DIR"
2. Continue building on parent's work
3. When parent is merged, rebase: git rebase main

Remember:
- Merge parent PR before child PR
- After parent merges, rebase child onto main:
  git fetch origin && git rebase origin/main
```

## Rebase Instructions

When the parent branch gets merged to main:

```sh
cd "$NEW_TASK_DIR"

# Fetch latest main
git fetch origin

# Rebase onto main (removes parent commits that are now in main)
git rebase origin/main

# Force push if already pushed (with lease for safety)
git push --force-with-lease
```

## Error Handling

- **Not in worktree:** Guide to `/kraft-start`
- **Worktree exists:** Suggest using existing or `/kraft-archive` first
- **Uncommitted changes:** Recommend commit or stash
- **Branch name conflict:** Suggest alternative naming

## Stack Management Tips

1. **Keep stacks shallow** - 2-3 levels max
2. **Merge from bottom up** - Parent first, then children
3. **Rebase after parent merge** - Keep history clean
4. **Communicate dependencies** - Note in PR descriptions
