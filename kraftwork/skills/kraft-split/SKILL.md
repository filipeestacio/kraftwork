---
name: kraft-split
description: Split a completed branch into two stacked MRs. Reads the plan's MR Split section, validates commit boundaries, creates sub-worktrees, verifies deployability, and creates GitLab MRs. Also works as a pre-MR diff analyzer when no plan exists.
---

# Workspace Split - Split Branch Into Stacked MRs

Split a completed implementation branch into two stacked MRs based on the plan's `## MR Split` section. Also works as a standalone diff analyzer when invoked without a plan.

## Scripts Used

| Script | Purpose |
|--------|---------|
| `find-workspace.sh` | Locate workspace root |
| `safety-check.sh` | Check for uncommitted/unpushed changes |
| `stack-metadata.sh` | Read/write `.stack-metadata.json` for stacked worktrees |

## Script Paths

**IMPORTANT:** Derive the scripts directory from this skill file's location:
- This skill file: `kraftwork/skills/kraft-split/SKILL.md`
- Workspace plugin root: 3 directories up from this file
- Scripts directory: `<workspace-root>/scripts/`

## Size Thresholds

| Metric | Target | Warning |
|--------|--------|---------|
| Lines changed | < 200 | > 200 |
| Files touched | < 10 | > 10 |

These are guidelines, not hard rules. A 250-line MR that's all test code is fine. A 150-line MR that touches 15 unrelated files is not.

## Workflow

### Step 1: Validate Environment

```sh
WORKTREE_PATH=$(git rev-parse --show-toplevel 2>/dev/null)

case "$WORKTREE_PATH" in
  */tasks/*)
    ;;
  *)
    echo "Not in a worktree. Run /kraft-start first."
    exit 1
    ;;
esac

TICKET_ID=$(basename "$WORKTREE_PATH" | grep -oE '^[A-Z]+-[0-9]+')
WORKSPACE=$(<scripts-dir>/find-workspace.sh)
```

### Step 2: Safety Check

```sh
SAFETY=$(<scripts-dir>/safety-check.sh "$WORKTREE_PATH")
```

If uncommitted changes, ask user to commit or stash before proceeding.

### Step 3: Analyze Diff

```sh
BASE_BRANCH="main"

git diff --stat "$BASE_BRANCH"...HEAD

INSERTIONS=$(git diff --shortstat "$BASE_BRANCH"...HEAD | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)
DELETIONS=$(git diff --shortstat "$BASE_BRANCH"...HEAD | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo 0)
TOTAL_LINES=$((INSERTIONS + DELETIONS))
FILES_CHANGED=$(git diff --name-only "$BASE_BRANCH"...HEAD | wc -l | tr -d ' ')
COMMITS=$(git rev-list --count "$BASE_BRANCH"...HEAD)
```

Present the analysis.

**If under thresholds and no plan split section:** "This diff is MR-ready. Proceed with `/glab-mr create`." STOP.

**If over thresholds or plan has `## MR Split` section:** Continue.

### Step 4: Check for Plan-Driven Split

Look for a plan file with an `## MR Split` section:
1. Check argument: `/kraft-split [path-to-plan]`
2. Check spec directory: `$WORKSPACE/docs/specs/$TICKET_ID/plan.md`
3. Ask user for plan path

**If no plan with `## MR Split` found:** Fall back to manual split guidance (Step 5a).
**If plan with `## MR Split` found:** Proceed with automated split (Step 5b).

### Step 5a: Manual Split Guidance (No Plan)

Analyze the diff to find logical split boundaries:

```sh
git diff --name-only "$BASE_BRANCH"...HEAD | sort | awk -F/ '{print $1"/"$2}' | uniq -c | sort -rn
git log --oneline "$BASE_BRANCH"...HEAD
```

Propose a split by concern, commit boundary, or file cluster. Walk the user through manual execution via `/kraft-stack` and cherry-pick. STOP after guidance.

### Step 5b: Automated Split (Plan-Driven)

#### 5b.1: Parse the Plan

Read the `## MR Split` section. Extract:
- Split boundary (task number)
- MR1 description + file list
- MR2 description + file list

Validate that every file in the plan's file map appears in exactly one MR.

#### 5b.2: Classify Commits

For each commit in `origin/main..HEAD`:

```sh
git rev-list --reverse origin/main..HEAD
```

For each commit:
1. Get changed files: `git diff-tree --no-commit-id --name-only -r <sha>`
2. Look up which MR each file belongs to (from the plan)
3. Assign the commit to that MR

**Failure cases:**
- A commit touches files from both MRs → STOP. Report the offending commit and files. Ask user to restructure commits (e.g., interactive rebase to split the commit), then retry.
- A file isn't listed in either MR → warn, ask user which MR it belongs to, update classification.

#### 5b.3: Create MR1 Sub-Worktree

```sh
MR1_SLUG=$(slugify MR1 description from plan)
MR1_DIR="$WORKSPACE/tasks/${TICKET_ID}-MR1-${MR1_SLUG}"
MR1_BRANCH="${TICKET_ID}-MR1-${MR1_SLUG}"

# Create worktree from main
git worktree add -b "$MR1_BRANCH" "$MR1_DIR" origin/main
cd "$MR1_DIR"

# Cherry-pick MR1 commits in order
git cherry-pick <sha1> <sha2> ...

# Ensure commit messages have ticket prefix
# (cherry-pick doesn't trigger prepare-commit-msg hook)
git rebase origin/main --exec \
  'msg=$(git log --format=%s -n1); case "$msg" in '"${TICKET_ID}"'*) ;; *) git commit --amend -m "'"${TICKET_ID}"' $msg" ;; esac'
```

If cherry-pick fails: `git cherry-pick --abort`, report the conflict, ask user to restructure commits on the original branch, then retry.

#### 5b.4: Verify MR1 Deployability

```sh
cd "$MR1_DIR"
pnpm install
pnpm build
pnpm test
```

If any step fails:
- Report the failure to the user
- Suggest minimal fixes (e.g., "biome flags unused export", "missing module registration")
- Wait for user to approve fixup commits
- Re-verify after fixes

#### 5b.5: Create MR2 Sub-Worktree

Run from MR1's worktree so MR2 branches from MR1's HEAD:

```sh
MR2_SLUG=$(slugify MR2 description from plan)
MR2_DIR="$WORKSPACE/tasks/${TICKET_ID}-MR2-${MR2_SLUG}"
MR2_BRANCH="${TICKET_ID}-MR2-${MR2_SLUG}"

cd "$MR1_DIR"
git worktree add -b "$MR2_BRANCH" "$MR2_DIR"
cd "$MR2_DIR"

# Cherry-pick MR2 commits in order
git cherry-pick <sha1> <sha2> ...

# Ensure commit messages have ticket prefix
git rebase "$MR1_BRANCH" --exec \
  'msg=$(git log --format=%s -n1); case "$msg" in '"${TICKET_ID}"'*) ;; *) git commit --amend -m "'"${TICKET_ID}"' $msg" ;; esac'
```

Same cherry-pick conflict handling as 5b.3.

#### 5b.6: Verify MR2 Deployability

Same as 5b.4: `pnpm install`, `pnpm build`, `pnpm test`.

#### 5b.7: Write Stack Metadata

Write `.stack-metadata.json` in both worktrees via `stack-metadata.sh`:

```sh
# Ensure .stack-metadata.json is globally gitignored
GLOBAL_IGNORE=$(git config --global core.excludesFile 2>/dev/null || echo "$HOME/.gitignore_global")
if [ -f "$GLOBAL_IGNORE" ]; then
  grep -qxF '.stack-metadata.json' "$GLOBAL_IGNORE" || echo '.stack-metadata.json' >> "$GLOBAL_IGNORE"
else
  echo '.stack-metadata.json' > "$GLOBAL_IGNORE"
  git config --global core.excludesFile "$GLOBAL_IGNORE"
fi

# Write parent metadata (MR number filled in after MR creation)
<scripts-dir>/stack-metadata.sh write "$MR1_DIR" '{
  "role": "parent",
  "ticket": "'"$TICKET_ID"'",
  "branch": "'"$MR1_BRANCH"'",
  "mr": null,
  "targetBranch": "main",
  "sibling": {
    "branch": "'"$MR2_BRANCH"'",
    "worktree": "'"$MR2_DIR"'",
    "mr": null
  }
}'

# Write child metadata
<scripts-dir>/stack-metadata.sh write "$MR2_DIR" '{
  "role": "child",
  "ticket": "'"$TICKET_ID"'",
  "branch": "'"$MR2_BRANCH"'",
  "mr": null,
  "targetBranch": "'"$MR1_BRANCH"'",
  "sibling": {
    "branch": "'"$MR1_BRANCH"'",
    "worktree": "'"$MR1_DIR"'",
    "mr": null
  }
}'
```

#### 5b.8: Push and Create MRs

```sh
cd "$MR1_DIR" && git push -u origin "$MR1_BRANCH"
cd "$MR2_DIR" && git push -u origin "$MR2_BRANCH"

# Create MR1 targeting main
cd "$MR1_DIR"
glab mr create --title "$TICKET_ID <MR1 description>" \
  --target-branch main \
  --description "..."

# Get MR1 number from output
MR1_NUM=$(glab mr list --source-branch "$MR1_BRANCH" --json number | jq '.[0].number')

# Create MR2 targeting MR1's branch
cd "$MR2_DIR"
glab mr create --title "$TICKET_ID <MR2 description>" \
  --target-branch "$MR1_BRANCH" \
  --description "... Stacked on !$MR1_NUM. Merge !$MR1_NUM first, then promote this MR via /kraft-resume ..."

MR2_NUM=$(glab mr list --source-branch "$MR2_BRANCH" --json number | jq '.[0].number')
```

#### 5b.9: Update Metadata with MR Numbers

Update both `.stack-metadata.json` files with the MR numbers (re-read, patch, re-write via `stack-metadata.sh`).

#### 5b.10: Offer to Archive Original Worktree

The original worktree still exists with all commits. Since the sub-worktrees replace it:

```
Split complete. The original worktree at $WORKTREE_PATH is no longer needed.
Archive it with /kraft-archive? (The sub-worktrees have all the commits.)
```

If user declines, leave it as-is.

#### 5b.11: Output

```
Split complete for $TICKET_ID

  !$MR1_NUM  $MR1_BRANCH  → main
    ↳ !$MR2_NUM  $MR2_BRANCH  → !$MR1_NUM

Worktrees:
  MR1: $MR1_DIR
  MR2: $MR2_DIR

Merge order: !$MR1_NUM first, then promote !$MR2_NUM via /kraft-resume
```

## Edge Cases

- **Plan has no MR Split section** — fall back to manual split guidance (Step 5a)
- **No commits ahead of main** — nothing to split, exit with message
- **Worktree is dirty** — fail fast via `safety-check.sh`, ask user to commit or stash
- **Cherry-pick conflict** — abort, report conflicting commit and files, ask user to restructure on original branch
- **Deployability failure** — report failure, suggest minimal fixes, wait for user approval before continuing
- **MR creation fails** — report error, leave worktrees intact for manual recovery
- **Sibling worktree path invalid** — `kraft-resume` checks path exists before offering actions
- **Commit message already has ticket prefix** — rewrite step skips matching commits
- **Original worktree after split** — offer to archive via `/kraft-archive`

## Error Handling

- **Not in worktree:** Guide to `/kraft-start`
- **Workspace not found:** Guide to `/kraft-init`
- **glab not authenticated:** Guide to `glab auth login`
- **Cross-boundary commit detected:** STOP, report details, ask user to fix
