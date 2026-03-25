---
name: kraft-start
description: Create a git worktree for a Jira ticket with automatic repository discovery. Use when starting work on a new ticket.
---

# Workspace Start - Begin Work on a Ticket

Create an isolated git worktree for a Jira ticket with automatic repository discovery.

## Prerequisites

- `git` with SSH access to GitLab
- `glab` CLI authenticated (`glab auth status`)
- `jq` for JSON parsing
- `acli` CLI for Jira (optional, for ticket summary)

## Scripts Used

| Script | Purpose |
|--------|---------|
| `find-workspace.sh` | Locate workspace root |
| `search-ticket-mrs.sh` | Search GitLab MRs for ticket |
| `search-ticket-branches.sh` | Search local branches for ticket |
| `list-repos.sh` | List available repositories |
| `create-worktree.sh` | Create the worktree |

## Config Files

| Config | Purpose |
|--------|---------|
| `config/repo-setup.json` | Repo-specific post-install commands |

## Script Paths

**IMPORTANT:** Derive the scripts and config directories from this skill file's location:
- This skill file: `kraftwork/skills/kraft-start/SKILL.md`
- Workspace plugin root: 3 directories up from this file
- Scripts directory: `<workspace-root>/scripts/`
- Config directory: `<workspace-root>/config/`

When you load this skill, note its file path and compute these directories. For example, if this skill is at `/path/to/kraftwork/skills/kraft-start/SKILL.md`, then scripts are at `/path/to/kraftwork/scripts/` and config is at `/path/to/kraftwork/config/`.

## Workflow

### Step 1: Get Ticket ID

Read `workspace.json` from the workspace root (located via `find-workspace.sh`). Extract `git.host` and `git.group` values. If either is missing, tell the user to run `/kraft-init` to configure the workspace.

If not provided as argument, ask the user:
```
What Jira ticket are you starting work on? (e.g., PROJ-1234)
```

### Step 2: Locate Workspace

```sh
WORKSPACE=$(<scripts-dir>/find-workspace.sh)
echo "Workspace: $WORKSPACE"
```

### Step 3: Check for Existing Worktree

```sh
EXISTING=$(find "$WORKSPACE/tasks" -maxdepth 1 -type d -name "${TICKET_ID}-*" 2>/dev/null | head -1)
if [ -n "$EXISTING" ]; then
  echo "Worktree already exists: $EXISTING"
fi
```

If exists, ask user: use existing or create new?

### Step 4: Auto-Discover Repository

Use a 3-step discovery strategy:

**Step 4a: Search GitLab MRs**
```sh
MR_RESULTS=$(<scripts-dir>/search-ticket-mrs.sh "$TICKET_ID")
REPO_FROM_MR=$(echo "$MR_RESULTS" | jq -r '.[0].repo // empty')

if [ -n "$REPO_FROM_MR" ]; then
  echo "Found MR in repo: $REPO_FROM_MR"
  REPO_NAME=$(basename "$REPO_FROM_MR")
fi
```

**Step 4b: Search Local Branches**
```sh
BRANCH_RESULTS=$(<scripts-dir>/search-ticket-branches.sh "$TICKET_ID")
REPO_FROM_BRANCH=$(echo "$BRANCH_RESULTS" | jq -r '.[0].repo // empty')

if [ -n "$REPO_FROM_BRANCH" ]; then
  echo "Found branch in repo: $REPO_FROM_BRANCH"
  REPO_NAME="$REPO_FROM_BRANCH"
fi
```

**Step 4c: Ask User**
If no automatic match:
```sh
REPOS=$(<scripts-dir>/list-repos.sh)
echo "Available repositories:"
echo "$REPOS"
```

Use AskUserQuestion with the list of repos.

### Step 5: Ensure Repository is Cloned

```sh
REPO_PATH="$WORKSPACE/sources/$REPO_NAME"
if [ ! -d "$REPO_PATH" ]; then
  echo "Repository not cloned. Cloning..."
  GIT_HOST=$(<scripts-dir>/read-config.sh git host)
  GIT_GROUP=$(<scripts-dir>/read-config.sh git group)
  # Clone using the appropriate command for the configured git host
  # e.g., for gitlab: glab repo clone "$GIT_GROUP/$REPO_NAME" "$REPO_PATH"
  # e.g., for github: gh repo clone "$GIT_GROUP/$REPO_NAME" "$REPO_PATH"
fi
```

### Step 6: Fetch Ticket Summary from Jira (Optional)

```sh
if command -v acli >/dev/null 2>&1; then
  TICKET_JSON=$(acli jira workitem view "$TICKET_ID" --fields summary --json 2>/dev/null || echo "{}")
  SUMMARY=$(echo "$TICKET_JSON" | jq -r '.fields.summary // empty')
fi

if [ -z "$SUMMARY" ]; then
  echo "Could not fetch ticket summary from Jira"
  # Ask user for a description
fi
```

### Step 7: Generate Branch Name

```sh
# Slugify the summary
SLUG=$(echo "$SUMMARY" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//' | cut -c1-50)
BRANCH_NAME="${TICKET_ID}-${SLUG}"
TASK_DIR="$WORKSPACE/tasks/${BRANCH_NAME}"

echo "Branch: $BRANCH_NAME"
echo "Worktree: $TASK_DIR"
```

### Step 8: Create Worktree

```sh
<scripts-dir>/create-worktree.sh "$REPO_PATH" "$BRANCH_NAME" "$TASK_DIR" main
```

### Step 8a: Run Post-Install Setup

Check for repo-specific setup commands and run them:

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
      if ! (cd "$TASK_DIR/$CWD" && eval "$RUN"); then
        echo "  Warning: Failed: $RUN (in $CWD)"
        echo "  You may need to run this manually."
      fi
    done
  fi
fi
```

The config file path is derived the same way as scripts: `<workspace-root>/config/repo-setup.json`.

### Step 9: Setup Spec Directory

```sh
SPEC_DIR="$WORKSPACE/docs/specs/$TICKET_ID"
mkdir -p "$SPEC_DIR"

# Create initial idea.md if it doesn't exist
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

### Step 10: Open Zellij Tab (if in session)

If running inside a Zellij session (`$ZELLIJ` is set), open the task directory in a new tab:

```sh
if [ -n "$ZELLIJ" ]; then
  TAB_NAME=$(basename "$TASK_DIR")
  zellij action new-tab --name "$TAB_NAME" --cwd "$TASK_DIR"
fi
```

Skip this step silently if `$ZELLIJ` is not set.

### Step 11: Output Completion

```
Worktree created for $TICKET_ID

Worktree: $TASK_DIR
Specs: $SPEC_DIR
Branch: $BRANCH_NAME

Next steps:
1. cd "$TASK_DIR"
2. Run /kraft-plan to start planning
3. Or start coding directly
```

## Error Handling

- **glab not authenticated:** Guide user to run `glab auth login`
- **acli not configured:** Continue without Jira summary, ask user for description
- **Repo not found:** Offer to clone it
- **Branch already exists:** Ask if user wants to use existing branch or create new
