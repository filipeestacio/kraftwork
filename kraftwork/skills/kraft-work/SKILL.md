---
name: kraft-work
description: Start, resume, or stack work on a ticket. Unified entry point that routes to the right flow based on context — use instead of kraft-start, kraft-resume, or kraft-stack.
---

# Workspace Work - Start, Resume, or Stack

Unified entry point for all worktree-based work. Routes to the right flow based on the current context and provided arguments.

## Scripts Used

| Script | Purpose |
|--------|---------|
| `find-workspace.sh` | Locate workspace root |
| `worktree-status.sh` | Get detailed status for all worktrees (JSON) |
| `create-worktree.sh` | Create the worktree |
| `list-repos.sh` | List available repositories |
| `stack-metadata.sh` | Read stack metadata for split worktrees |
| `safety-check.sh` | Check for uncommitted changes |

## Provider Skills Used

This skill invokes provider skills via workspace.json resolution. See Provider Skill Resolution below.

| Category | Skill | Purpose |
|---|---|---|
| git-hosting | find | Search for existing PRs and branches by ticket ID |
| git-hosting | import | Clone a repository into the workspace |
| ticket-management | describe | Fetch ticket details (summary, description) |

## Provider Skill Resolution

To invoke a provider skill:

1. Read `workspace.json` at the workspace root
2. Look up the provider for the needed category: `jq -r '.providers["<category>"]' workspace.json`
   - If the category is not configured, inform the user and suggest `/kraft-config`
   - Handle both string format (`"kraftwork-gitlab"`) and legacy object format (`{"plugin": "kraftwork-gitlab"}`)
3. Construct the qualified skill name: `{provider}:{category}-{skill}`
4. Invoke via the Skill tool

Example: to find PRs, read `providers["git-hosting"]` → `kraftwork-gitlab` → invoke `kraftwork-gitlab:git-hosting-find`

## Config Files

| Config | Purpose |
|--------|---------|
| `config/repo-setup.json` | Repo-specific post-install commands |

## Script Paths

**IMPORTANT:** Derive the scripts and config directories from this skill file's location:
- This skill file: `kraftwork/skills/kraft-work/SKILL.md`
- Workspace plugin root: 3 directories up from this file
- Scripts directory: `<workspace-root>/scripts/`
- Config directory: `<workspace-root>/config/`

When you load this skill, note its file path and compute these directories. For example, if this skill is at `/path/to/kraftwork/skills/kraft-work/SKILL.md`, then scripts are at `/path/to/kraftwork/scripts/` and config is at `/path/to/kraftwork/config/`.

## Routing Logic

```sh
# 1. Locate workspace — if this fails, guide to /kraft-config
WORKSPACE=$(<scripts-dir>/find-workspace.sh) || exit 1

# 2. Detect current worktree context
CURRENT_WORKTREE=$(git rev-parse --show-toplevel 2>/dev/null)
case "$CURRENT_WORKTREE" in
  */trees/*) IN_WORKTREE=true ;;
  *) IN_WORKTREE=false ;;
esac
```

**Route decision:**

| Condition | Flow |
|-----------|------|
| Argument provided + existing worktree matches | Resume flow (Step R) |
| Argument provided + no match + not in worktree | Create flow (Step C) |
| Argument provided + in a worktree | Stack prompt (Step S) |
| No argument + in a worktree | Show current status (Step R, skip selection) |
| No argument + worktrees exist | List and let user pick (Step R) |
| No argument + no worktrees | Prompt for ticket ID, then Create flow (Step C) |

---

## Step C: Create Flow

Use this when starting work on a new ticket.

### C1: Get Ticket ID

If not provided as argument, ask the user:

```
What ticket are you starting work on? (e.g., PROJ-1234)
```

### C2: Check for Existing Worktree

```sh
EXISTING=$(find "$WORKSPACE/trees" -maxdepth 1 -type d -name "${TICKET_ID}-*" 2>/dev/null | head -1)
if [ -n "$EXISTING" ]; then
  echo "Worktree already exists: $EXISTING"
fi
```

If found, ask user: use existing (resume flow) or create new?

### C3: Auto-Discover Repository

Use a 3-step strategy:

**C3a: Search for existing MRs/PRs via provider**

Resolve the git-hosting provider from workspace.json. If configured, invoke `{git-hosting}:git-hosting-find` with the ticket ID to search for existing PRs/MRs. The skill returns matching PRs with repo information.

If git-hosting is not configured in workspace.json, skip this step.

**C3b: Search for existing branches via provider**

If C3a didn't find a match, invoke `{git-hosting}:git-hosting-find` again, requesting a branch search for the ticket ID. The find skill handles both PR and branch searches.

If git-hosting is not configured, skip this step.

**C3c: Ask user**

If neither step found a match:

```sh
REPOS=$(<scripts-dir>/list-repos.sh)
echo "Available repositories:"
echo "$REPOS"
```

Use AskUserQuestion with the list of repos.

### C4: Ensure Repository is Cloned

```sh
REPO_PATH="$WORKSPACE/modules/$REPO_NAME"
```

If the repo directory doesn't exist and git-hosting is configured, invoke `{git-hosting}:git-hosting-import` with the repo name and target path `$WORKSPACE/modules/$REPO_NAME`.

If git-hosting is not configured:
```
ERROR: Repository not found and no git hosting provider configured. Run /kraft-config to set up, or clone manually into modules/.
```

### C5: Fetch Ticket Details

If ticket-management is configured in workspace.json, invoke `{ticket-management}:ticket-management-describe` with the ticket ID to fetch the summary and description.

If ticket-management is not configured or the skill returns no data:

```
Could not fetch ticket summary. Please provide a short description:
```

### C6: Generate Branch Name

```sh
SLUG=$(echo "$SUMMARY" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//' | cut -c1-50)
BRANCH_NAME="${TICKET_ID}-${SLUG}"
TREE_DIR="$WORKSPACE/trees/${BRANCH_NAME}"

echo "Branch: $BRANCH_NAME"
echo "Worktree: $TREE_DIR"
```

### C7: Create Worktree

```sh
<scripts-dir>/create-worktree.sh "$REPO_PATH" "$BRANCH_NAME" "$TREE_DIR" main
```

### C8: Run Post-Install Setup

```sh
CONFIG_FILE="<workspace-root>/config/repo-setup.json"

if [ -f "$CONFIG_FILE" ]; then
  COMMANDS=$(jq -r ".repos.\"$REPO_NAME\".post_install // empty" "$CONFIG_FILE")

  if [ -n "$COMMANDS" ] && [ "$COMMANDS" != "null" ]; then
    echo "Running post-install setup for $REPO_NAME..."

    echo "$COMMANDS" | jq -c '.[]' | while read -r item; do
      CWD=$(echo "$item" | jq -r '.cwd')
      RUN=$(echo "$item" | jq -r '.run')
      DESC=$(echo "$item" | jq -r '.description // empty')

      [ -n "$DESC" ] && echo "  → $DESC"
      if ! (cd "$TREE_DIR/$CWD" && eval "$RUN"); then
        echo "  Warning: Failed: $RUN (in $CWD)"
        echo "  You may need to run this manually."
      fi
    done
  fi
fi
```

### C9: Setup Spec Directory

```sh
SPEC_DIR="$WORKSPACE/docs/specs/$TICKET_ID"
mkdir -p "$SPEC_DIR"

if [ ! -f "$SPEC_DIR/idea.md" ]; then
  cat > "$SPEC_DIR/idea.md" << EOF
# $TICKET_ID

**Summary:** $SUMMARY

## Initial Notes

_Add your initial thoughts and requirements here._
EOF
fi

echo "Spec directory: $SPEC_DIR"
```

### C10: Open Zellij Tab (if in session)

```sh
if [ -n "$ZELLIJ" ]; then
  TAB_NAME=$(basename "$TREE_DIR")
  zellij action new-tab --name "$TAB_NAME" --cwd "$TREE_DIR"
fi
```

Skip silently if `$ZELLIJ` is not set.

### C11: Output Completion

```
Worktree created for $TICKET_ID

Worktree: $TREE_DIR
Specs:    $SPEC_DIR
Branch:   $BRANCH_NAME

Next steps:
1. cd "$TREE_DIR"
2. Run /kraft-plan to start planning
```

---

## Step R: Resume Flow

Use this when returning to existing work.

### R1: Get Worktree Status

```sh
<scripts-dir>/worktree-status.sh "$WORKSPACE"
```

The script outputs JSON:

```json
[
  {
    "name": "PROJ-1234-add-authentication",
    "path": "/path/to/trees/PROJ-1234-add-authentication",
    "ticket": "PROJ-1234",
    "repo": "frontend",
    "branch": "PROJ-1234-add-authentication",
    "phase": "implementing",
    "progress": "3/7 tasks",
    "uncommitted": true,
    "unpushed": false,
    "pending_changes": 0,
    "spec_dir": "/path/to/docs/specs/PROJ-1234"
  }
]
```

### R2: Detect Stacked Worktrees

For each worktree, check for stack metadata:

```sh
<scripts-dir>/stack-metadata.sh read "$WORKTREE_PATH"
```

If the result is non-empty (not `{}`), the worktree is part of a split stack. Collect the metadata to annotate the display.

### R3: Present Worktree Summary

Format the JSON as a readable list. Group parent and child worktrees together:

```
Active Worktrees
================

1. PROJ-1234-add-authentication
   Repo: frontend
   Phase: implementing (3/7 tasks)
   Status: uncommitted changes
   Pending changes: 0

2. PROJ-5678-fix-validation
   Repo: messaging
   Phase: planning (idea captured)
   Status: clean
   Pending changes: 1

3. PROJ-3782-MR1-persistence  !233 (open)
   Repo: my-service
   Phase: implementing
     ↳ PROJ-3782-MR2-controller  !234 (stacked on !233)
```

If the array is empty, tell the user no active worktrees were found and offer to start one.

### R4: Select Worktree

Skip this step if:
- A ticket ID was provided and matched exactly one worktree
- Currently inside a worktree (use current)

Otherwise, use AskUserQuestion to let user select.

### R5: Show Detailed Status

```sh
# Git status
git -C "$SELECTED_PATH" status --short

# Recent commits
git -C "$SELECTED_PATH" log --oneline -5

# Spec files
ls "$SPEC_DIR/" 2>/dev/null
```

### R6: Suggest Next Action

Based on the `phase` field from the JSON:

| Phase | Suggestion |
|-------|------------|
| `new` | `/kraft-plan` (start planning) |
| `planning` | `/kraft-plan` (continue planning) |
| `spec_ready` | `/kraft-plan` (create task list) or `/kraft-implement` |
| `implementing` | `/kraft-implement` (continue with tasks) |

If `pending_changes > 0`, suggest reviewing pending changes first with `/kraft-implement`.

#### Stack-Aware Actions

If the selected worktree has stack metadata, detect the stack state and offer actions:

| Situation | Detection | Action |
|-----------|-----------|--------|
| MR1 changed, MR2 stale | MR1 HEAD differs from MR2's merge base (`git merge-base <MR1-branch> <MR2-branch>` vs MR1 HEAD) | "MR1 has new commits. Rebase MR2?" → `cd <MR2> && git rebase <MR1-branch> && git push --force-with-lease` |
| MR1 merged | PR status check via `{git-hosting}:git-hosting-describe` returns merged state | "MR1 merged. Promote MR2 to target main?" → `cd <MR2> && git fetch origin && git rebase --onto origin/main <MR1-branch> && git push --force-with-lease`, then update MR target branch via provider, then update metadata |
| Both merged | Both PRs show merged state | "Stack complete. Archive worktrees?" → suggest `/kraft-archive` for both |
| MR1 has review feedback | MR1 open with unresolved discussions | "MR1 has review feedback" → suggest resuming MR1 |

Check PR status via provider:

Invoke `{git-hosting}:git-hosting-find` to check PR status for the stack's branches.

After sync or promote operations, update `.stack-metadata.json` via:

```sh
<scripts-dir>/stack-metadata.sh write "$WORKTREE_PATH" "$UPDATED_METADATA_JSON"
```

### R7: Output Completion

```
Resuming work on $TICKET_ID
===========================

Worktree: $SELECTED_PATH
Specs:    $SPEC_DIR
Branch:   $BRANCH

Current state:
- Phase: $PHASE ($PROGRESS)
- Uncommitted changes: $UNCOMMITTED
- Unpushed commits: $UNPUSHED
- Pending spec changes: $PENDING

Suggested next step:
  $SUGGESTION

To navigate:
  cd "$SELECTED_PATH"
```

---

## Step S: Stack Flow

Use this when inside a worktree and a new ticket ID is provided.

### S1: Confirm Stacking Intent

Present the user with a choice:

```
You're currently in worktree: $CURRENT_WORKTREE ($CURRENT_BRANCH)

How do you want to start $NEW_TICKET_ID?
1. Stack on current worktree (branch from $CURRENT_BRANCH)
2. Start fresh from main
```

If the user chooses option 2, proceed with Create flow (Step C) using the new ticket ID, ignoring the current worktree context.

If the user chooses option 1, continue below.

### S2: Check for Existing Worktree

```sh
EXISTING=$(find "$WORKSPACE/trees" -maxdepth 1 -type d -name "${NEW_TICKET_ID}-*" 2>/dev/null | head -1)
if [ -n "$EXISTING" ]; then
  echo "Worktree already exists for $NEW_TICKET_ID: $EXISTING"
  exit 1
fi
```

### S3: Safety Check

```sh
SAFETY=$(<scripts-dir>/safety-check.sh "$CURRENT_WORKTREE")
HAS_UNCOMMITTED=$(echo "$SAFETY" | jq -r '.uncommitted.has_changes')

if [ "$HAS_UNCOMMITTED" = "true" ]; then
  echo "WARNING: Current worktree has uncommitted changes"
  echo "$SAFETY" | jq -r '.uncommitted'
fi
```

If uncommitted changes, use AskUserQuestion:
- **Commit first** — stop and let user commit
- **Stash** — stash changes before continuing
- **Continue anyway** — proceed (not recommended)

### S4: Fetch Ticket Details

If ticket-management is configured in workspace.json, invoke `{ticket-management}:ticket-management-describe` with the ticket ID to fetch the summary and description.

If ticket-management is not configured or the skill returns no data:

```
Could not fetch ticket summary. Please provide a short description:
```

### S5: Generate Branch Name

```sh
SLUG=$(echo "$SUMMARY" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//' | cut -c1-50)
NEW_BRANCH="${NEW_TICKET_ID}-${SLUG}"
NEW_TREE_DIR="$WORKSPACE/trees/${NEW_BRANCH}"

PARENT_TICKET=$(basename "$CURRENT_WORKTREE" | grep -oE '^[A-Z]+-[0-9]+' || echo "")
PARENT_BRANCH=$(git -C "$CURRENT_WORKTREE" branch --show-current)
```

### S6: Create Stacked Worktree

```sh
# Branch from current HEAD, not from main
git -C "$CURRENT_WORKTREE" worktree add -b "$NEW_BRANCH" "$NEW_TREE_DIR"
```

### S7: Setup Spec Directory with Stack Context

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
- **Parent worktree:** $CURRENT_WORKTREE

## Dependencies

This work depends on $PARENT_TICKET being completed/merged first.

## Initial Notes

_Add your initial thoughts and requirements here._
EOF
```

### S8: Output Completion

```
Created stacked worktree for $NEW_TICKET_ID

Stack Structure:
  $PARENT_TICKET ($PARENT_BRANCH)
    └── $NEW_TICKET_ID ($NEW_BRANCH)

Worktrees:
  Parent: $CURRENT_WORKTREE
  Child:  $NEW_TREE_DIR

Specs:
  Parent: $WORKSPACE/docs/specs/$PARENT_TICKET/
  Child:  $NEW_SPEC_DIR/

Next steps:
1. cd "$NEW_TREE_DIR"
2. Run /kraft-plan to start planning

Remember:
- Merge parent PR before child PR
- After parent merges, rebase child: git fetch origin && git rebase origin/main
```

---

## Error Handling

- **No workspace found**: Guide user to run `/kraft-config`
- **Ticket provider unavailable**: Prompt user for branch name / description directly
- **Git hosting unavailable**: Skip PR/branch search, search locally only
- **Existing worktree**: Ask to use existing (resume) or create new
- **Repo not found / not cloned**: Attempt clone via provider; if provider unavailable, error with guidance
- **Uncommitted changes when stacking**: Offer commit, stash, or continue anyway
- **Corrupted worktree**: Suggest manual cleanup or `/kraft-archive`
