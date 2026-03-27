---
name: kraft-import
description: Onboard a new repository as a workspace submodule with automatic codebase scanning.
---

# Workspace Import - Onboard a Repository as a Submodule

Add a new repository to the workspace as a git submodule, scan its codebase for documentation, and configure the workspace accordingly.

## Use Cases

- **Onboard a new service:** Add a repo you'll be working on to the workspace
- **Continue work from another machine:** Started on laptop, continuing on desktop
- **Pick up abandoned work:** Resume work on an old branch
- **Collaborate on a branch:** Join work a teammate started
- **Post-rebase recovery:** Recreate worktree after rebasing elsewhere

## Scripts Used

| Script | Purpose |
|--------|---------|
| `find-workspace.sh` | Locate workspace root |
| `resolve-provider.sh` | Resolve provider-specific scripts |

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
  echo "Workspace not found. Run /kraft-config first."
  exit 1
fi
echo "Workspace: $WORKSPACE"
```

### Step 2: Resolve Provider Scripts

```sh
SEARCH_PRS=$(<scripts-dir>/resolve-provider.sh script git-hosting search-prs 2>/dev/null || echo "")
SEARCH_BRANCHES=$(<scripts-dir>/resolve-provider.sh script git-hosting search-branches 2>/dev/null || echo "")
CLONE_REPO=$(<scripts-dir>/resolve-provider.sh script git-hosting clone-repo 2>/dev/null || echo "")
```

### Step 3: Get Ticket or Repository Identifier

If not provided, ask user:

```
What ticket or repository identifier do you want to import? (e.g., PROJ-1234 or a repo URL/name)
```

### Step 4: Check for Existing Module

```sh
EXISTING=$(find "$WORKSPACE/modules" -maxdepth 1 -type d -name "${TICKET_ID}-*" 2>/dev/null | head -1)

if [ -n "$EXISTING" ]; then
  echo "Module already exists: $EXISTING"
fi
```

If exists, ask user: use existing, or remove and reimport?

### Step 5: Search for Remote Branches

```sh
echo "Searching for branches matching $TICKET_ID..."

BRANCH_RESULTS=$($SEARCH_BRANCHES "$TICKET_ID" "$WORKSPACE" 2>/dev/null)
BRANCH_COUNT=$(echo "$BRANCH_RESULTS" | jq 'length' 2>/dev/null || echo "0")

if [ "$BRANCH_COUNT" -gt 0 ]; then
  echo "Found $BRANCH_COUNT matching branches:"
  echo "$BRANCH_RESULTS" | jq -r '.[] | "  \(.repo) → \(.branch) [\(.location)]"'
fi
```

### Step 6: PR Search (Fallback)

If no branches found:

```sh
if [ "$BRANCH_COUNT" -eq 0 ] && [ -n "$SEARCH_PRS" ]; then
  echo "No local branches found. Searching PRs..."

  PR_RESULTS=$($SEARCH_PRS "$TICKET_ID" 2>/dev/null)
  PR_COUNT=$(echo "$PR_RESULTS" | jq 'length' 2>/dev/null || echo "0")

  if [ "$PR_COUNT" -gt 0 ]; then
    echo "Found PRs:"
    echo "$PR_RESULTS" | jq -r '.[] | "  \(.repo) - \(.title) [\(.state)]"'
  else
    echo "No branches or PRs found for $TICKET_ID"
    exit 1
  fi
fi
```

### Step 7: Select Branch to Import

If multiple branches found, use AskUserQuestion:

```
Found branches for $TICKET_ID:

1. messaging → PROJ-1234-add-feature
2. frontend → PROJ-1234-ui-updates

Which would you like to import?
```

Options: list branches, or "All" for multi-repo tickets.

### Step 8: Clone and Add as Submodule

```sh
REPO_NAME="$SELECTED_REPO"
BRANCH_NAME="$SELECTED_BRANCH"
MODULE_DIR="$WORKSPACE/modules/$REPO_NAME"

# Clone repo if not already present
if [ ! -d "$MODULE_DIR" ]; then
  git -C "$WORKSPACE" submodule add <url> "modules/$REPO_NAME"
  echo "Added submodule: modules/$REPO_NAME"
fi

# Fetch and checkout the branch
git -C "$MODULE_DIR" fetch origin "$BRANCH_NAME"
git -C "$MODULE_DIR" checkout --track "origin/$BRANCH_NAME"

echo "Checked out: $BRANCH_NAME"
```

### Step 9: Create Worktree

```sh
TREE_DIR="$WORKSPACE/trees/$BRANCH_NAME"

git -C "$MODULE_DIR" worktree add --track -b "$BRANCH_NAME" "$TREE_DIR" "origin/$BRANCH_NAME"

echo "Created worktree: $TREE_DIR"
echo "Tracking: origin/$BRANCH_NAME"
```

### Step 10: Scan Repository Documentation

Scan the newly added module for documentation and project context:

```sh
DOCS_FOUND=""

for doc in README.md docs/ CLAUDE.md AGENTS.md; do
  if [ -e "$MODULE_DIR/$doc" ]; then
    DOCS_FOUND="$DOCS_FOUND $doc"
    echo "Found: $doc"
  fi
done
```

Read any found documentation files and summarise their content. Then suggest additions to `$WORKSPACE/CLAUDE.md` based on what was found — for example: repo-specific conventions, tech stack notes, local dev setup commands, or key architectural patterns.

Ask the user whether to apply the suggested additions before writing anything.

### Step 11: Setup Spec Directory

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

### Step 12: Output Completion

```
Imported $REPO_NAME for $TICKET_ID

Submodule: modules/$REPO_NAME
Worktree: $TREE_DIR
Branch: $BRANCH_NAME (tracking origin/$BRANCH_NAME)
Specs: $SPEC_DIR

Branch status:
$(git -C "$TREE_DIR" log --oneline -5)

Next steps:
1. cd "$TREE_DIR"
2. Review current state: git log --oneline -10
3. Continue development or run /kraft-work if starting fresh
```

## Error Handling

- **No branches found:** Try PR search via resolved provider script
- **Branch already exists locally:** Ask if user wants to reset to remote
- **Worktree exists:** Offer to use existing or reimport
- **Fetch failed:** Check network and authentication with your git hosting provider; run /kraft-config to reconfigure if needed

## Notes

- Import adds the repo as a git submodule under `modules/`
- The worktree is created under `trees/` tracking the remote branch
- Local changes can be pushed with `git push`
- If branch was rebased remotely, may need `git pull --rebase`
