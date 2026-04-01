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

## Provider Skills Used

| Category | Skill | Purpose |
|---|---|---|
| git-hosting | find | Search for branches and PRs matching a ticket ID |
| git-hosting | import | Clone a repository into the workspace |

## Provider Skill Resolution

To invoke a provider skill:

1. Read `workspace.json` at the workspace root
2. Look up the provider: `jq -r '.providers["<category>"]' workspace.json`
3. Construct: `{provider}:{category}-{skill}`
4. Invoke via the Skill tool

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

### Step 2: Check Provider Availability

```sh
WORKSPACE_JSON="$WORKSPACE/workspace.json"
GIT_PROVIDER=$(jq -r '.providers["git-hosting"] // empty' "$WORKSPACE_JSON")
```

If empty, inform the user that branch/PR search and cloning will not be available — they can provide a repo path or URL manually.

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

If git-hosting is configured, invoke `{git-hosting}:git-hosting-find` with the ticket ID to search for matching branches.

If git-hosting is not configured, skip to Step 7 (ask user for repo).

### Step 6: PR Search (Fallback)

If no branches found and git-hosting is configured, invoke `{git-hosting}:git-hosting-find` again, requesting a PR search for the ticket ID.

If no results from either search, inform the user and exit.

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

If the repo is not already present at `$WORKSPACE/modules/$REPO_NAME`, invoke `{git-hosting}:git-hosting-import` with the repo name and target path.

If git-hosting is not configured, ask the user for a clone URL and run:
```sh
git -C "$WORKSPACE" submodule add "<clone-url>" "modules/$REPO_NAME"
```

Then fetch and checkout the branch:

```sh
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
