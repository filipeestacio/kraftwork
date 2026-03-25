---
name: kraft-resume
description: Resume work on an existing worktree. Lists active worktrees, shows their status, and guides you to the appropriate next action.
---

# Workspace Resume - Continue Work on Existing Worktree

Find and resume work on an existing worktree, with status information to help you pick up where you left off.

## Scripts Used

| Script | Purpose |
|--------|---------|
| `find-workspace.sh` | Locate workspace root |
| `worktree-status.sh` | Get detailed status for all worktrees (JSON output) |
| `stack-metadata.sh` | Read stack metadata for split worktrees (JSON output) |

## Script Paths

**IMPORTANT:** Derive the scripts directory from this skill file's location:
- This skill file: `kraftwork/skills/kraft-resume/SKILL.md`
- Workspace plugin root: 3 directories up from this file
- Scripts directory: `<workspace-root>/scripts/`

When you load this skill, note its file path and compute the scripts directory. For example, if this skill is at `/path/to/kraftwork/skills/kraft-resume/SKILL.md`, then scripts are at `/path/to/kraftwork/scripts/`.

## Workflow

### Step 1: Locate Workspace and Get Status

Run `find-workspace.sh` from the scripts directory to get the workspace path, then run `worktree-status.sh`:

```sh
# First, run find-workspace.sh
<scripts-dir>/find-workspace.sh

# Then, with the workspace path from above:
<scripts-dir>/worktree-status.sh "$WORKSPACE"
```

The `worktree-status.sh` script outputs JSON with all worktree details:

```json
[
  {
    "name": "PROJ-1234-add-authentication",
    "path": "/path/to/tasks/PROJ-1234-add-authentication",
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

### Step 2: Handle No Worktrees

If the JSON array is empty, inform the user:

```
No active worktrees found.
Run /kraft-start to begin work on a new ticket.
```

### Step 2.5: Detect Stacked Worktrees

For each worktree from Step 1, check for stack metadata:

```sh
<scripts-dir>/stack-metadata.sh read "$WORKTREE_PATH"
```

If the result is non-empty (not `{}`), the worktree is part of a split stack. Collect the metadata to annotate the display and inform action suggestions.

### Step 3: Present Worktree Summary

Format the JSON output as a readable summary. For stacked worktrees, show the parent-child relationship:

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

Group parent and child worktrees together. Show the MR number and stacking relationship.

### Step 4: Select Worktree

Use AskUserQuestion to let user select:

```
Which worktree do you want to resume?
```

Options should list each worktree with ticket ID and brief status.

### Step 5: Show Detailed Status for Selected Worktree

For the selected worktree, run additional git commands:

```sh
# Show git status
git -C "$SELECTED_PATH" status --short

# Show recent commits
git -C "$SELECTED_PATH" log --oneline -5

# List spec files
ls "$SPEC_DIR/" 2>/dev/null
```

### Step 6: Suggest Next Action

Based on the worktree phase from the JSON:

| Phase | Suggestion |
|-------|------------|
| `new` | `/kraft-plan` (start planning) |
| `planning` | `/kraft-plan` (continue planning) |
| `spec_ready` | `/kraft-plan` (create task list) or `/kraft-implement` |
| `implementing` | `/kraft-implement` (continue with tasks) |

If `pending_changes > 0`, suggest reviewing pending changes first with `/kraft-implement`.

#### Stack-Aware Actions

If the selected worktree has stack metadata, detect the current stack state and offer additional actions:

| Situation | Detection | Action |
|-----------|-----------|--------|
| MR1 changed, MR2 stale | MR1 HEAD differs from MR2's merge base (`git merge-base <MR1-branch> <MR2-branch>` vs MR1 HEAD) | "MR1 has new commits. Rebase MR2?" → `cd <MR2> && git rebase <MR1-branch> && git push --force-with-lease` |
| MR1 merged | `glab mr view <MR1-num> --json state` returns `merged` | "MR1 merged. Promote MR2 to target main?" → `cd <MR2> && git fetch origin && git rebase --onto origin/main <MR1-branch> && git push --force-with-lease` + `glab mr update <MR2-num> --target-branch main` + update metadata |
| Both merged | Both MRs show `merged` state | "Stack complete. Archive worktrees?" → suggest `/kraft-archive` for both |
| MR1 has review feedback | MR1 open with unresolved discussions | "MR1 has review feedback" → suggest resuming MR1 |

After sync or promote operations, update `.stack-metadata.json` via `stack-metadata.sh write`:
- After promote: change child's `targetBranch` to `main`
- After both merged: no update needed (archive will clean up)

### Step 7: Output Completion

```
Resuming work on $TICKET_ID
===========================

Worktree: $SELECTED_PATH
Specs: $SPEC_DIR
Branch: $BRANCH

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

## Quick Resume (With Argument)

If invoked with a ticket ID (e.g., `/kraft-resume PROJ-1234`):

```sh
WORKSPACE=$(<scripts-dir>/find-workspace.sh)
<scripts-dir>/worktree-status.sh "$WORKSPACE" "PROJ-1234"
```

The script accepts an optional second argument to filter to a specific worktree.
Skip directly to Step 5 (show detailed status) with the result.

## Error Handling

- **No worktrees:** Suggest `/kraft-start`
- **Ticket not found:** Show available worktrees from `worktree-status.sh`
- **Workspace not found:** Suggest `/kraft-init`
- **Corrupted worktree:** Suggest manual cleanup or `/kraft-archive`

## Integration with Other Skills

After resuming, the user typically runs:
- `/kraft-plan` - Continue or modify planning
- `/kraft-implement` - Continue implementation
- `/kraft-archive` - Clean up if done
- `/kraft-split` - Split branch into stacked MRs (if diff is too large)

For stacked worktrees (created by `/kraft-split`), resume handles the sync/promote lifecycle inline — no separate skill needed.
