---
name: kraft-sync
description: Pull the latest changes from origin for all repositories in your workspace.
---

# Workspace Sync - Update All Repositories

Synchronize all repositories in the workspace with their remote origins.

## Script Paths

**IMPORTANT:** Derive the scripts directory from this skill file's location:
- This skill file: `kraftwork/skills/kraft-sync/SKILL.md`
- Workspace plugin root: 3 directories up from this file
- Scripts directory: `<workspace-root>/scripts/`

When you load this skill, note its file path and compute the scripts directory. For example, if this skill is at `/path/to/kraftwork/skills/kraft-sync/SKILL.md`, then scripts are at `/path/to/kraftwork/scripts/`.

## Execution

Run the sync script from the scripts directory:

```
<scripts-dir>/workspace-sync.sh [WORKSPACE_PATH]
```

**Arguments:**
- `WORKSPACE_PATH` (optional): Path to workspace root. Defaults to the result of `find-workspace.sh`

**Example:**
```bash
<scripts-dir>/workspace-sync.sh
<scripts-dir>/workspace-sync.sh ~/Developer/myworkspace
```

## What It Does

1. Locates all git repositories in `$WORKSPACE/sources/`
2. For each repo on main/master with no uncommitted changes:
   - Fetches from origin
   - Fast-forward merges if behind
3. Also syncs `$WORKSPACE/docs/specs/` if it's a git repo
4. Reports summary of results

## Output Legend

- `✅` - Successfully pulled new commits
- `✓` - Already up to date
- `⏭️` - Skipped (uncommitted changes or not on main branch)
- `❌` - Failed (fetch error or merge conflict)

## Safety

- Only performs fast-forward merges (no force)
- Never overwrites uncommitted changes
- Skips repos not on main/master branch
- Non-destructive - safe to run anytime

## Troubleshooting

- **Fetch failed**: Check SSH keys and network connection
- **Merge failed (diverged)**: Branch has diverged, needs manual intervention
- **Uncommitted changes**: Commit or stash changes first
