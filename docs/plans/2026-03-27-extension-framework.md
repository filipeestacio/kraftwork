# Extension Framework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a template extension and two concrete extensions (GitHub, ClickUp) to validate the provider system and make building new integrations fast.

**Architecture:** Template provides copy-and-rename scaffolding with all provider contract stubs. GitHub extension implements git-hosting via `gh` CLI. ClickUp extension implements ticket-management and document-storage via REST API with env-var-based auth.

**Tech Stack:** Shell scripts (sh), JSON, `gh` CLI, `curl`, `jq`

---

### Task 1: Create Template Extension

**Files:**
- Create: `kraftwork-template/.claude-plugin/plugin.json`
- Create: `kraftwork-template/config/workspace-config.json`
- Create: `kraftwork-template/providers.json`
- Create: `kraftwork-template/scripts/auth-check.sh`
- Create: `kraftwork-template/scripts/search-prs.sh`
- Create: `kraftwork-template/scripts/search-branches.sh`
- Create: `kraftwork-template/scripts/clone-repo.sh`
- Create: `kraftwork-template/scripts/create-pr.sh`
- Create: `kraftwork-template/scripts/fetch-pr-details.sh`
- Create: `kraftwork-template/scripts/ci-status.sh`
- Create: `kraftwork-template/scripts/fetch-ticket.sh`
- Create: `kraftwork-template/scripts/search-tickets.sh`
- Create: `kraftwork-template/scripts/transition-ticket.sh`
- Create: `kraftwork-template/scripts/write-doc.sh`
- Create: `kraftwork-template/scripts/read-doc.sh`
- Create: `kraftwork-template/scripts/list-docs.sh`
- Create: `kraftwork-template/fragments/pr-description-guide.md`
- Create: `kraftwork-template/fragments/branch-naming.md`
- Create: `kraftwork-template/fragments/ticket-id-pattern.md`
- Create: `kraftwork-template/CHECKLIST.md`

- [ ] **Step 1: Create plugin.json**

Write to `kraftwork-template/.claude-plugin/plugin.json`:

```json
{
  "name": "kraftwork-CHANGEME",
  "version": "3.0.0",
  "description": "CHANGEME provider for Kraftwork",
  "author": {
    "name": "Filipe Estacio",
    "email": "f.estacio@gmail.com"
  }
}
```

- [ ] **Step 2: Create workspace-config.json**

Write to `kraftwork-template/config/workspace-config.json`:

```json
{
  "section": "CHANGEME",
  "title": "CHANGEME Configuration",
  "description": "Settings for CHANGEME integration",
  "fields": []
}
```

- [ ] **Step 3: Create providers.json**

Write to `kraftwork-template/providers.json`:

```json
{
  "providers": [
    {
      "category": "git-hosting",
      "scripts": {
        "auth-check": "scripts/auth-check.sh",
        "search-prs": "scripts/search-prs.sh",
        "search-branches": "scripts/search-branches.sh",
        "clone-repo": "scripts/clone-repo.sh",
        "create-pr": "scripts/create-pr.sh",
        "fetch-pr-details": "scripts/fetch-pr-details.sh",
        "ci-status": "scripts/ci-status.sh"
      },
      "fragments": {
        "pr-description-guide": "fragments/pr-description-guide.md",
        "branch-naming": "fragments/branch-naming.md"
      }
    },
    {
      "category": "ticket-management",
      "scripts": {
        "fetch-ticket": "scripts/fetch-ticket.sh",
        "search-tickets": "scripts/search-tickets.sh",
        "transition-ticket": "scripts/transition-ticket.sh"
      },
      "fragments": {
        "ticket-id-pattern": "fragments/ticket-id-pattern.md"
      }
    },
    {
      "category": "document-storage",
      "scripts": {
        "write-doc": "scripts/write-doc.sh",
        "read-doc": "scripts/read-doc.sh",
        "list-docs": "scripts/list-docs.sh"
      },
      "fragments": {}
    }
  ]
}
```

- [ ] **Step 4: Create auth-check.sh with both patterns**

Write to `kraftwork-template/scripts/auth-check.sh`:

```sh
#!/bin/sh
#
# auth-check.sh - Verify authentication with the provider
#
# Usage: auth-check.sh
#
# Exit codes:
#   0 - Authenticated
#   1 - Not authenticated or tool missing
#

set -eu

# ┌─────────────────────────────────────────────────────┐
# │ PATTERN A: CLI-based (gh, glab, etc.)               │
# │ Delete this block if using API-based auth.           │
# └─────────────────────────────────────────────────────┘

# if ! command -v TOOL >/dev/null 2>&1; then
#   echo "TOOL is not installed." >&2
#   exit 1
# fi
# if ! TOOL auth status >/dev/null 2>&1; then
#   echo "TOOL is not authenticated. Run: TOOL auth login" >&2
#   exit 1
# fi
# exit 0

# ┌─────────────────────────────────────────────────────┐
# │ PATTERN B: API-based (env var token)                 │
# │ Delete this block if using CLI-based auth.           │
# │ Does NOT ping the API — just checks the env var.     │
# └─────────────────────────────────────────────────────┘

# DIR="$(pwd)"
# while [ "$DIR" != "/" ]; do
#   [ -f "$DIR/workspace.json" ] && break
#   DIR=$(dirname "$DIR")
# done
# WORKSPACE_JSON="$DIR/workspace.json"
#
# TOKEN_ENV=$(jq -r '.providers."CATEGORY".config.apiTokenEnv' "$WORKSPACE_JSON")
# TOKEN=$(eval echo "\$$TOKEN_ENV")
# if [ -z "$TOKEN" ]; then
#   echo "$TOKEN_ENV is not set" >&2
#   exit 1
# fi
# exit 0

echo "auth-check.sh: not implemented" >&2
exit 1
```

Make executable: `chmod +x kraftwork-template/scripts/auth-check.sh`

- [ ] **Step 5: Create git-hosting script stubs**

Write to `kraftwork-template/scripts/search-prs.sh`:

```sh
#!/bin/sh
#
# search-prs.sh - Search for PRs matching a ticket
#
# Usage: search-prs.sh <TICKET_ID> [ORG_OR_GROUP]
#   TICKET_ID:    Ticket identifier (e.g., PROJ-1234)
#   ORG_OR_GROUP: Organization/group to search (defaults to workspace.json config)
#
# Output: JSON array of matching PRs
#   [{"id": N, "title": "...", "url": "...", "branch": "...", "state": "...", "repo": "..."}]
#
# Exit codes:
#   0 - Success (may have 0 results)
#   1 - Missing ticket ID
#

set -eu

TICKET_ID="${1:-}"
ORG="${2:-}"

if [ -z "$TICKET_ID" ]; then
  echo "Usage: search-prs.sh <TICKET_ID> [ORG_OR_GROUP]" >&2
  exit 1
fi

if [ -z "$ORG" ]; then
  DIR="$(pwd)"
  while [ "$DIR" != "/" ]; do
    [ -f "$DIR/workspace.json" ] && break
    DIR=$(dirname "$DIR")
  done
  if [ -f "$DIR/workspace.json" ]; then
    ORG=$(jq -r '.providers."git-hosting".config.org // .providers."git-hosting".config.defaultGroup // empty' "$DIR/workspace.json")
  fi
  if [ -z "$ORG" ]; then
    echo "[]"
    exit 0
  fi
fi

# --- IMPLEMENT BELOW ---
echo "[]"
```

Write to `kraftwork-template/scripts/search-branches.sh`:

```sh
#!/bin/sh
#
# search-branches.sh - Search local and remote branches matching a ticket
#
# Usage: search-branches.sh <TICKET_ID> [WORKSPACE]
#   TICKET_ID: Ticket identifier (e.g., PROJ-1234)
#   WORKSPACE: Path to workspace root (defaults to auto-detect)
#
# Output: JSON array of matching branches
#   [{"repo": "...", "branch": "...", "location": "local|remote"}]
#
# Exit codes:
#   0 - Success (may have 0 results)
#   1 - Missing ticket ID
#   2 - Workspace not found
#

set -eu

TICKET_ID="${1:-}"
WORKSPACE="${2:-}"

if [ -z "$TICKET_ID" ]; then
  echo "Usage: search-branches.sh <TICKET_ID> [WORKSPACE]" >&2
  exit 1
fi

if [ -z "$WORKSPACE" ]; then
  DIR="$(pwd)"
  while [ "$DIR" != "/" ]; do
    [ -f "$DIR/workspace.json" ] && break
    DIR=$(dirname "$DIR")
  done
  WORKSPACE="$DIR"
fi

if [ -d "$WORKSPACE/modules" ]; then
  REPOS_DIR="$WORKSPACE/modules"
elif [ -d "$WORKSPACE/sources" ]; then
  REPOS_DIR="$WORKSPACE/sources"
else
  echo "[]"
  exit 0
fi

# --- IMPLEMENT BELOW ---
# This implementation is generic (git-based, not vendor-specific).
# You can usually copy it as-is.

for REPO_PATH in "$REPOS_DIR"/*/; do
  [ -d "$REPO_PATH/.git" ] || continue
  REPO_NAME=$(basename "$REPO_PATH")
  git -C "$REPO_PATH" fetch --quiet 2>/dev/null || true
  BRANCHES=$(git -C "$REPO_PATH" branch -a 2>/dev/null | grep -i "$TICKET_ID" || true)
  [ -z "$BRANCHES" ] && continue
  echo "$BRANCHES" | while IFS= read -r BRANCH_LINE; do
    BRANCH=$(echo "$BRANCH_LINE" | sed 's/^[* ]*//' | sed 's|remotes/origin/||')
    case "$BRANCH" in *HEAD*) continue ;; esac
    case "$BRANCH_LINE" in
      *remotes/*) LOCATION="remote" ;;
      *) LOCATION="local" ;;
    esac
    SAFE_BRANCH=$(printf '%s' "$BRANCH" | jq -sR '.')
    SAFE_REPO=$(printf '%s' "$REPO_NAME" | jq -sR '.')
    printf '{"repo": %s, "branch": %s, "location": "%s"}\n' "$SAFE_REPO" "$SAFE_BRANCH" "$LOCATION"
  done
done | jq -s '.' 2>/dev/null || echo "[]"
```

Write to `kraftwork-template/scripts/clone-repo.sh`:

```sh
#!/bin/sh
#
# clone-repo.sh - Clone a repository
#
# Usage: clone-repo.sh <ORG_OR_GROUP> <REPO> <DEST>
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or clone failed
#

set -eu

ORG="${1:-}"
REPO="${2:-}"
DEST="${3:-}"

if [ -z "$ORG" ] || [ -z "$REPO" ] || [ -z "$DEST" ]; then
  echo "Usage: clone-repo.sh <ORG_OR_GROUP> <REPO> <DEST>" >&2
  exit 1
fi

# --- IMPLEMENT BELOW ---
echo "clone-repo.sh: not implemented" >&2
exit 1
```

Write to `kraftwork-template/scripts/create-pr.sh`:

```sh
#!/bin/sh
#
# create-pr.sh - Create a pull/merge request
#
# Usage: create-pr.sh <SOURCE_BRANCH> <TARGET_BRANCH> <TITLE> [BODY]
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or creation failed
#

set -eu

SOURCE_BRANCH="${1:-}"
TARGET_BRANCH="${2:-}"
TITLE="${3:-}"
BODY="${4:-}"

if [ -z "$SOURCE_BRANCH" ] || [ -z "$TARGET_BRANCH" ] || [ -z "$TITLE" ]; then
  echo "Usage: create-pr.sh <SOURCE_BRANCH> <TARGET_BRANCH> <TITLE> [BODY]" >&2
  exit 1
fi

# --- IMPLEMENT BELOW ---
echo "create-pr.sh: not implemented" >&2
exit 1
```

Write to `kraftwork-template/scripts/fetch-pr-details.sh`:

```sh
#!/bin/sh
#
# fetch-pr-details.sh - Fetch full PR/MR details
#
# Usage: fetch-pr-details.sh <PR_NUMBER>
#   Must be run from within a git repo.
#
# Output: JSON object
#   {"details": {...}, "discussions": [...], "changes": {...}, "commits": [...]}
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or not in a git repo
#

set -eu

PR_NUMBER="${1:-}"

if [ -z "$PR_NUMBER" ]; then
  echo "Usage: fetch-pr-details.sh <PR_NUMBER>" >&2
  exit 1
fi

REMOTE_URL=$(git remote get-url origin 2>/dev/null) || {
  echo "Not inside a git repository or no origin remote" >&2
  exit 1
}

# --- IMPLEMENT BELOW ---
echo '{"details": {}, "discussions": [], "changes": {}, "commits": []}'
```

Write to `kraftwork-template/scripts/ci-status.sh`:

```sh
#!/bin/sh
#
# ci-status.sh - Check CI status for a branch
#
# Usage: ci-status.sh <BRANCH>
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or CI check failed
#

set -eu

BRANCH="${1:-}"

if [ -z "$BRANCH" ]; then
  echo "Usage: ci-status.sh <BRANCH>" >&2
  exit 1
fi

# --- IMPLEMENT BELOW ---
echo "ci-status.sh: not implemented" >&2
exit 1
```

Make all executable: `chmod +x kraftwork-template/scripts/*.sh`

- [ ] **Step 6: Create ticket-management script stubs**

Write to `kraftwork-template/scripts/fetch-ticket.sh`:

```sh
#!/bin/sh
#
# fetch-ticket.sh - Fetch ticket details
#
# Usage: fetch-ticket.sh <TICKET_ID>
#
# Output: JSON {"id": "...", "summary": "...", "status": "..."}
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or ticket not found
#

set -eu

TICKET_ID="${1:-}"

if [ -z "$TICKET_ID" ]; then
  echo "Usage: fetch-ticket.sh <TICKET_ID>" >&2
  exit 1
fi

# --- IMPLEMENT BELOW ---
echo '{"error": "not implemented"}' >&2
exit 1
```

Write to `kraftwork-template/scripts/search-tickets.sh`:

```sh
#!/bin/sh
#
# search-tickets.sh - Search tickets
#
# Usage: search-tickets.sh <QUERY>
#
# Output: JSON array of matching tickets
#
# Exit codes:
#   0 - Success (may have 0 results)
#   1 - Missing query
#

set -eu

QUERY="${1:-}"

if [ -z "$QUERY" ]; then
  echo "Usage: search-tickets.sh <QUERY>" >&2
  exit 1
fi

# --- IMPLEMENT BELOW ---
echo "[]"
```

Write to `kraftwork-template/scripts/transition-ticket.sh`:

```sh
#!/bin/sh
#
# transition-ticket.sh - Transition a ticket to a new status
#
# Usage: transition-ticket.sh <TICKET_ID> <STATUS>
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or transition failed
#

set -eu

TICKET_ID="${1:-}"
STATUS="${2:-}"

if [ -z "$TICKET_ID" ] || [ -z "$STATUS" ]; then
  echo "Usage: transition-ticket.sh <TICKET_ID> <STATUS>" >&2
  exit 1
fi

# --- IMPLEMENT BELOW ---
echo "transition-ticket.sh: not implemented" >&2
exit 1
```

Make all executable.

- [ ] **Step 7: Create document-storage script stubs**

Write to `kraftwork-template/scripts/write-doc.sh`:

```sh
#!/bin/sh
#
# write-doc.sh - Write/create a document
#
# Usage: write-doc.sh <PATH> <CONTENT>
#   PATH: Document path/identifier
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or write failed
#

set -eu

DOC_PATH="${1:-}"
CONTENT="${2:-}"

if [ -z "$DOC_PATH" ]; then
  echo "Usage: write-doc.sh <PATH> <CONTENT>" >&2
  exit 1
fi

# --- IMPLEMENT BELOW ---
echo "write-doc.sh: not implemented" >&2
exit 1
```

Write to `kraftwork-template/scripts/read-doc.sh`:

```sh
#!/bin/sh
#
# read-doc.sh - Read a document
#
# Usage: read-doc.sh <PATH>
#   PATH: Document path/identifier
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or document not found
#

set -eu

DOC_PATH="${1:-}"

if [ -z "$DOC_PATH" ]; then
  echo "Usage: read-doc.sh <PATH>" >&2
  exit 1
fi

# --- IMPLEMENT BELOW ---
echo "read-doc.sh: not implemented" >&2
exit 1
```

Write to `kraftwork-template/scripts/list-docs.sh`:

```sh
#!/bin/sh
#
# list-docs.sh - List documents
#
# Usage: list-docs.sh [PREFIX]
#   PREFIX: Optional path prefix to filter by
#
# Output: List of document paths/identifiers
#
# Exit codes:
#   0 - Success (may have 0 results)
#

set -eu

PREFIX="${1:-}"

# --- IMPLEMENT BELOW ---
echo "[]"
```

Make all executable.

- [ ] **Step 8: Create fragment stubs**

Write to `kraftwork-template/fragments/pr-description-guide.md`:

```markdown
CHANGEME: Describe how PRs should be formatted for this git host.
Include auto-closing syntax, markdown flavor, CI notes, and stacked PR conventions.
```

Write to `kraftwork-template/fragments/branch-naming.md`:

```markdown
CHANGEME: Describe the branch naming convention.
```

Write to `kraftwork-template/fragments/ticket-id-pattern.md`:

```markdown
CHANGEME: Describe the ticket ID format and regex pattern.
```

- [ ] **Step 9: Create CHECKLIST.md**

Write to `kraftwork-template/CHECKLIST.md`:

```markdown
# Extension Development Checklist

## Setup

1. Copy `kraftwork-template/` to `kraftwork-<name>/`
2. Update `.claude-plugin/plugin.json` — set name and description
3. Edit `providers.json` — delete categories you don't provide
4. Delete script stubs for removed categories
5. Delete fragment stubs for removed categories

## Configuration

6. Fill in `config/workspace-config.json` — section name, title, fields
7. For API-based auth: add an `apiTokenEnv` field (stores env var name, not the secret)
8. For CLI-based auth: no config needed (CLI handles its own auth)

## Implementation

9. Implement `scripts/auth-check.sh` — pick Pattern A (CLI) or Pattern B (API)
10. Implement each remaining script — replace `# --- IMPLEMENT BELOW ---` sections
11. Write fragment content — replace CHANGEME placeholders

## Verification

12. Run `kraft-config` — verify the new extension is discovered and offered
13. Test each script via `resolve-provider.sh`:
    - `kraftwork/scripts/resolve-provider.sh script <category> <capability>`
    - `kraftwork/scripts/resolve-provider.sh has <category> <capability>`
    - `kraftwork/scripts/resolve-provider.sh fragment <category> <fragment-name>`
```

- [ ] **Step 10: Commit**

```bash
git add kraftwork-template/
git commit -m "feat: add extension template with provider contract stubs"
```

---

### Task 2: Create kraftwork-github Extension

Built from the template. Provides git-hosting via `gh` CLI.

**Files:**
- Create: `kraftwork-github/.claude-plugin/plugin.json`
- Create: `kraftwork-github/config/workspace-config.json`
- Create: `kraftwork-github/providers.json`
- Create: `kraftwork-github/scripts/auth-check.sh`
- Create: `kraftwork-github/scripts/search-prs.sh`
- Create: `kraftwork-github/scripts/search-branches.sh`
- Create: `kraftwork-github/scripts/clone-repo.sh`
- Create: `kraftwork-github/scripts/create-pr.sh`
- Create: `kraftwork-github/scripts/fetch-pr-details.sh`
- Create: `kraftwork-github/scripts/ci-status.sh`
- Create: `kraftwork-github/fragments/pr-description-guide.md`
- Create: `kraftwork-github/fragments/branch-naming.md`

- [ ] **Step 1: Create plugin.json**

Write to `kraftwork-github/.claude-plugin/plugin.json`:

```json
{
  "name": "kraftwork-github",
  "version": "3.0.0",
  "description": "GitHub git hosting provider for Kraftwork (requires kraftwork core)",
  "author": {
    "name": "Filipe Estacio",
    "email": "f.estacio@gmail.com"
  }
}
```

- [ ] **Step 2: Create workspace-config.json**

Write to `kraftwork-github/config/workspace-config.json`:

```json
{
  "section": "github",
  "title": "GitHub Configuration",
  "description": "GitHub organization or user for API queries",
  "fields": [
    {
      "key": "org",
      "type": "string",
      "prompt": "What is your GitHub organization or username?",
      "example": "my-org",
      "required": true
    }
  ]
}
```

- [ ] **Step 3: Create providers.json**

Write to `kraftwork-github/providers.json`:

```json
{
  "providers": [
    {
      "category": "git-hosting",
      "scripts": {
        "auth-check": "scripts/auth-check.sh",
        "search-prs": "scripts/search-prs.sh",
        "search-branches": "scripts/search-branches.sh",
        "clone-repo": "scripts/clone-repo.sh",
        "create-pr": "scripts/create-pr.sh",
        "fetch-pr-details": "scripts/fetch-pr-details.sh",
        "ci-status": "scripts/ci-status.sh"
      },
      "fragments": {
        "pr-description-guide": "fragments/pr-description-guide.md",
        "branch-naming": "fragments/branch-naming.md"
      }
    }
  ]
}
```

- [ ] **Step 4: Create auth-check.sh**

Write to `kraftwork-github/scripts/auth-check.sh`:

```sh
#!/bin/sh
#
# auth-check.sh - Verify gh CLI is installed and authenticated
#
# Usage: auth-check.sh
#
# Exit codes:
#   0 - gh installed and authenticated
#   1 - gh missing or not authenticated
#

set -eu

if ! command -v gh >/dev/null 2>&1; then
  echo "gh is not installed. Install it via: brew install gh" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "gh is not authenticated. Run: gh auth login" >&2
  exit 1
fi
```

- [ ] **Step 5: Create search-prs.sh**

Write to `kraftwork-github/scripts/search-prs.sh`:

```sh
#!/bin/sh
#
# search-prs.sh - Search GitHub PRs matching a ticket
#
# Usage: search-prs.sh <TICKET_ID> [ORG]
#   TICKET_ID: Ticket identifier (e.g., PROJ-1234)
#   ORG:       GitHub org/user to search (defaults to workspace.json config)
#
# Output: JSON array of matching PRs
#   [{"id": N, "title": "...", "url": "...", "branch": "...", "state": "...", "repo": "..."}]
#
# Exit codes:
#   0 - Success (may have 0 results)
#   1 - Missing ticket ID
#

set -eu

TICKET_ID="${1:-}"
ORG="${2:-}"

if [ -z "$TICKET_ID" ]; then
  echo "Usage: search-prs.sh <TICKET_ID> [ORG]" >&2
  exit 1
fi

if [ -z "$ORG" ]; then
  DIR="$(pwd)"
  while [ "$DIR" != "/" ]; do
    [ -f "$DIR/workspace.json" ] && break
    DIR=$(dirname "$DIR")
  done
  if [ -f "$DIR/workspace.json" ]; then
    ORG=$(jq -r '.providers."git-hosting".config.org // empty' "$DIR/workspace.json")
  fi
  if [ -z "$ORG" ]; then
    echo "[]"
    exit 0
  fi
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "[]"
  exit 0
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "[]"
  exit 0
fi

RESULTS=$(gh api "search/issues?q=$(printf '%s' "$TICKET_ID" | jq -sRr @uri)+type:pr+org:$ORG&per_page=20" 2>/dev/null || echo '{"items":[]}')

echo "$RESULTS" | jq '
  [.items[] | {
    id: .number,
    title: .title,
    url: .html_url,
    branch: (.pull_request.html_url | split("/") | last // ""),
    state: .state,
    repo: (.repository_url | split("/") | .[-2:] | join("/"))
  }]
' 2>/dev/null || echo "[]"
```

- [ ] **Step 6: Create search-branches.sh**

Write to `kraftwork-github/scripts/search-branches.sh`:

This is identical to the GitLab version — it's git-based, not vendor-specific. Copy from `kraftwork-gitlab/scripts/search-branches.sh` verbatim except update the header comment to say "GitHub" instead of "GitLab".

```sh
#!/bin/sh
#
# search-branches.sh - Search local and remote branches matching a ticket
#
# Usage: search-branches.sh <TICKET_ID> [WORKSPACE]
#   TICKET_ID: Ticket identifier (e.g., PROJ-1234)
#   WORKSPACE: Path to workspace root (defaults to auto-detect)
#
# Output: JSON array of matching branches
#   [{"repo": "...", "branch": "...", "location": "local|remote"}]
#
# Exit codes:
#   0 - Success (may have 0 results)
#   1 - Missing ticket ID
#   2 - Workspace not found
#

set -eu

TICKET_ID="${1:-}"
WORKSPACE="${2:-}"

if [ -z "$TICKET_ID" ]; then
  echo "Usage: search-branches.sh <TICKET_ID> [WORKSPACE]" >&2
  exit 1
fi

if [ -z "$WORKSPACE" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  WORKSPACE=$("$SCRIPT_DIR/../../kraftwork/scripts/find-workspace.sh" "$(pwd)" 2>/dev/null) || {
    echo '{"error": "workspace not found"}' >&2
    exit 2
  }
fi

if [ -d "$WORKSPACE/modules" ]; then
  REPOS_DIR="$WORKSPACE/modules"
elif [ -d "$WORKSPACE/sources" ]; then
  REPOS_DIR="$WORKSPACE/sources"
else
  echo '{"error": "no modules or sources directory"}' >&2
  exit 2
fi

for REPO_PATH in "$REPOS_DIR"/*/; do
  [ -d "$REPO_PATH/.git" ] || continue
  REPO_NAME=$(basename "$REPO_PATH")
  git -C "$REPO_PATH" fetch --quiet 2>/dev/null || true
  BRANCHES=$(git -C "$REPO_PATH" branch -a 2>/dev/null | grep -i "$TICKET_ID" || true)
  [ -z "$BRANCHES" ] && continue
  echo "$BRANCHES" | while IFS= read -r BRANCH_LINE; do
    BRANCH=$(echo "$BRANCH_LINE" | sed 's/^[* ]*//' | sed 's|remotes/origin/||')
    case "$BRANCH" in *HEAD*) continue ;; esac
    case "$BRANCH_LINE" in
      *remotes/*) LOCATION="remote" ;;
      *) LOCATION="local" ;;
    esac
    SAFE_BRANCH=$(printf '%s' "$BRANCH" | jq -sR '.')
    SAFE_REPO=$(printf '%s' "$REPO_NAME" | jq -sR '.')
    printf '{"repo": %s, "branch": %s, "location": "%s"}\n' "$SAFE_REPO" "$SAFE_BRANCH" "$LOCATION"
  done
done | jq -s '.' 2>/dev/null || echo "[]"
```

- [ ] **Step 7: Create clone-repo.sh**

Write to `kraftwork-github/scripts/clone-repo.sh`:

```sh
#!/bin/sh
#
# clone-repo.sh - Clone a GitHub repository
#
# Usage: clone-repo.sh <ORG> <REPO> <DEST>
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or clone failed
#

set -eu

ORG="${1:-}"
REPO="${2:-}"
DEST="${3:-}"

if [ -z "$ORG" ] || [ -z "$REPO" ] || [ -z "$DEST" ]; then
  echo "Usage: clone-repo.sh <ORG> <REPO> <DEST>" >&2
  exit 1
fi

gh repo clone "$ORG/$REPO" "$DEST"
```

- [ ] **Step 8: Create create-pr.sh**

Write to `kraftwork-github/scripts/create-pr.sh`:

```sh
#!/bin/sh
#
# create-pr.sh - Create a GitHub pull request
#
# Usage: create-pr.sh <SOURCE_BRANCH> <TARGET_BRANCH> <TITLE> [BODY]
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or PR creation failed
#

set -eu

SOURCE_BRANCH="${1:-}"
TARGET_BRANCH="${2:-}"
TITLE="${3:-}"
BODY="${4:-}"

if [ -z "$SOURCE_BRANCH" ] || [ -z "$TARGET_BRANCH" ] || [ -z "$TITLE" ]; then
  echo "Usage: create-pr.sh <SOURCE_BRANCH> <TARGET_BRANCH> <TITLE> [BODY]" >&2
  exit 1
fi

git push -u origin "$SOURCE_BRANCH" 2>/dev/null

if [ -n "$BODY" ]; then
  gh pr create --base "$TARGET_BRANCH" --head "$SOURCE_BRANCH" --title "$TITLE" --body "$BODY"
else
  gh pr create --base "$TARGET_BRANCH" --head "$SOURCE_BRANCH" --title "$TITLE" --body ""
fi
```

- [ ] **Step 9: Create fetch-pr-details.sh**

Write to `kraftwork-github/scripts/fetch-pr-details.sh`:

```sh
#!/bin/sh
#
# fetch-pr-details.sh - Fetch full PR details from GitHub
#
# Usage: fetch-pr-details.sh <PR_NUMBER>
#   Must be run from within a git repo.
#
# Output: JSON object
#   {"details": {...}, "discussions": [...], "changes": {...}, "commits": [...]}
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or not in a git repo
#

set -eu

PR_NUMBER="${1:-}"

if [ -z "$PR_NUMBER" ]; then
  echo "Usage: fetch-pr-details.sh <PR_NUMBER>" >&2
  exit 1
fi

REMOTE_URL=$(git remote get-url origin 2>/dev/null) || {
  echo "Not inside a git repository or no origin remote" >&2
  exit 1
}

REPO_SLUG=$(echo "$REMOTE_URL" | sed -E 's|^https?://github\.com/||; s|^git@github\.com:||; s|\.git$||')

DETAILS=$(gh api "repos/$REPO_SLUG/pulls/$PR_NUMBER" 2>/dev/null || echo '{}')
REVIEWS=$(gh api "repos/$REPO_SLUG/pulls/$PR_NUMBER/reviews" 2>/dev/null || echo '[]')
COMMENTS=$(gh api "repos/$REPO_SLUG/pulls/$PR_NUMBER/comments" 2>/dev/null || echo '[]')
COMMITS=$(gh api "repos/$REPO_SLUG/pulls/$PR_NUMBER/commits?per_page=100" 2>/dev/null || echo '[]')
FILES=$(gh api "repos/$REPO_SLUG/pulls/$PR_NUMBER/files?per_page=100" 2>/dev/null || echo '[]')

DISCUSSIONS=$(jq -n --argjson reviews "$REVIEWS" --argjson comments "$COMMENTS" '$reviews + $comments')

jq -n \
  --argjson details "$DETAILS" \
  --argjson discussions "$DISCUSSIONS" \
  --argjson changes "$FILES" \
  --argjson commits "$COMMITS" \
  '{details: $details, discussions: $discussions, changes: $changes, commits: $commits}'
```

- [ ] **Step 10: Create ci-status.sh**

Write to `kraftwork-github/scripts/ci-status.sh`:

```sh
#!/bin/sh
#
# ci-status.sh - Check GitHub Actions status for a branch
#
# Usage: ci-status.sh <BRANCH>
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or check failed
#

set -eu

BRANCH="${1:-}"

if [ -z "$BRANCH" ]; then
  echo "Usage: ci-status.sh <BRANCH>" >&2
  exit 1
fi

gh run list --branch "$BRANCH" --json name,status,conclusion --limit 10 2>/dev/null || echo "[]"
```

- [ ] **Step 11: Create fragments**

Write to `kraftwork-github/fragments/pr-description-guide.md`:

```markdown
Include `Fixes <TICKET-ID>` in the PR description for auto-closing linked issues.
Use GitHub-flavored markdown. Check the Actions tab for CI status.
For stacked PRs, include `Stacked on #<parent-PR-number>` and note merge order.
```

Write to `kraftwork-github/fragments/branch-naming.md`:

```markdown
Branch naming convention: `<ticket-id>-<slug>` (e.g., `PROJ-123-add-login-endpoint`).
The ticket ID prefix enables automatic PR-to-issue linking.
```

- [ ] **Step 12: Make all scripts executable and commit**

```bash
chmod +x kraftwork-github/scripts/*.sh
git add kraftwork-github/
git commit -m "feat: add kraftwork-github extension (git-hosting via gh CLI)"
```

---

### Task 3: Create kraftwork-clickup Extension

Built from the template. Provides ticket-management and document-storage via ClickUp REST API v2.

**Files:**
- Create: `kraftwork-clickup/.claude-plugin/plugin.json`
- Create: `kraftwork-clickup/config/workspace-config.json`
- Create: `kraftwork-clickup/providers.json`
- Create: `kraftwork-clickup/scripts/auth-check.sh`
- Create: `kraftwork-clickup/scripts/fetch-ticket.sh`
- Create: `kraftwork-clickup/scripts/search-tickets.sh`
- Create: `kraftwork-clickup/scripts/transition-ticket.sh`
- Create: `kraftwork-clickup/scripts/write-doc.sh`
- Create: `kraftwork-clickup/scripts/read-doc.sh`
- Create: `kraftwork-clickup/scripts/list-docs.sh`
- Create: `kraftwork-clickup/fragments/ticket-id-pattern.md`

- [ ] **Step 1: Create plugin.json**

Write to `kraftwork-clickup/.claude-plugin/plugin.json`:

```json
{
  "name": "kraftwork-clickup",
  "version": "3.0.0",
  "description": "ClickUp ticket management and document storage provider for Kraftwork (requires kraftwork core)",
  "author": {
    "name": "Filipe Estacio",
    "email": "f.estacio@gmail.com"
  }
}
```

- [ ] **Step 2: Create workspace-config.json**

Write to `kraftwork-clickup/config/workspace-config.json`:

```json
{
  "section": "clickup",
  "title": "ClickUp Configuration",
  "description": "ClickUp workspace and API settings",
  "fields": [
    {
      "key": "apiTokenEnv",
      "type": "string",
      "prompt": "What environment variable holds your ClickUp API token?",
      "example": "CLICKUP_API_TOKEN",
      "required": true
    },
    {
      "key": "teamId",
      "type": "string",
      "prompt": "What is your ClickUp team/workspace ID?",
      "example": "1234567",
      "required": true
    },
    {
      "key": "spaces",
      "type": "object[]",
      "prompt": "What ClickUp spaces should be available? For each, provide an ID, name, and description.",
      "example": [
        {"id": "12345", "name": "Engineering", "description": "Backend services, APIs, infrastructure"},
        {"id": "67890", "name": "Product", "description": "Feature specs, design docs"}
      ],
      "required": true
    }
  ]
}
```

- [ ] **Step 3: Create providers.json**

Write to `kraftwork-clickup/providers.json`:

```json
{
  "providers": [
    {
      "category": "ticket-management",
      "scripts": {
        "fetch-ticket": "scripts/fetch-ticket.sh",
        "search-tickets": "scripts/search-tickets.sh",
        "transition-ticket": "scripts/transition-ticket.sh"
      },
      "fragments": {
        "ticket-id-pattern": "fragments/ticket-id-pattern.md"
      }
    },
    {
      "category": "document-storage",
      "scripts": {
        "write-doc": "scripts/write-doc.sh",
        "read-doc": "scripts/read-doc.sh",
        "list-docs": "scripts/list-docs.sh"
      },
      "fragments": {}
    }
  ]
}
```

- [ ] **Step 4: Create auth-check.sh**

Write to `kraftwork-clickup/scripts/auth-check.sh`:

```sh
#!/bin/sh
#
# auth-check.sh - Verify ClickUp API token is available
#
# Usage: auth-check.sh
#
# Exit codes:
#   0 - Token env var is set
#   1 - Token env var not found or empty
#

set -eu

DIR="$(pwd)"
while [ "$DIR" != "/" ]; do
  [ -f "$DIR/workspace.json" ] && break
  DIR=$(dirname "$DIR")
done

if [ ! -f "$DIR/workspace.json" ]; then
  echo "workspace.json not found" >&2
  exit 1
fi

TOKEN_ENV=$(jq -r '.providers."ticket-management".config.apiTokenEnv // empty' "$DIR/workspace.json")

if [ -z "$TOKEN_ENV" ]; then
  echo "apiTokenEnv not configured in workspace.json" >&2
  exit 1
fi

TOKEN=$(eval echo "\$$TOKEN_ENV" 2>/dev/null || echo "")

if [ -z "$TOKEN" ]; then
  echo "$TOKEN_ENV is not set. Export it in your shell profile." >&2
  exit 1
fi
```

- [ ] **Step 5: Create fetch-ticket.sh**

Write to `kraftwork-clickup/scripts/fetch-ticket.sh`:

```sh
#!/bin/sh
#
# fetch-ticket.sh - Fetch a ClickUp task
#
# Usage: fetch-ticket.sh <TICKET_ID>
#
# Output: JSON {"id": "...", "summary": "...", "status": "..."}
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments, auth failure, or task not found
#

set -eu

TICKET_ID="${1:-}"

if [ -z "$TICKET_ID" ]; then
  echo "Usage: fetch-ticket.sh <TICKET_ID>" >&2
  exit 1
fi

DIR="$(pwd)"
while [ "$DIR" != "/" ]; do
  [ -f "$DIR/workspace.json" ] && break
  DIR=$(dirname "$DIR")
done
WORKSPACE_JSON="$DIR/workspace.json"

TOKEN_ENV=$(jq -r '.providers."ticket-management".config.apiTokenEnv // empty' "$WORKSPACE_JSON")
TOKEN=$(eval echo "\$$TOKEN_ENV" 2>/dev/null || echo "")

if [ -z "$TOKEN" ]; then
  echo "$TOKEN_ENV is not set" >&2
  exit 1
fi

RESPONSE=$(curl -s -H "Authorization: $TOKEN" "https://api.clickup.com/api/v2/task/$TICKET_ID" 2>/dev/null)

ERROR=$(echo "$RESPONSE" | jq -r '.err // empty' 2>/dev/null)
if [ -n "$ERROR" ]; then
  echo "ClickUp API error: $ERROR" >&2
  exit 1
fi

echo "$RESPONSE" | jq '{
  id: .id,
  summary: .name,
  status: .status.status
}' 2>/dev/null || {
  echo "Failed to parse ClickUp response" >&2
  exit 1
}
```

- [ ] **Step 6: Create search-tickets.sh**

Write to `kraftwork-clickup/scripts/search-tickets.sh`:

```sh
#!/bin/sh
#
# search-tickets.sh - Search ClickUp tasks
#
# Usage: search-tickets.sh <QUERY>
#
# Output: JSON array of matching tickets
#
# Exit codes:
#   0 - Success (may have 0 results)
#   1 - Missing query
#

set -eu

QUERY="${1:-}"

if [ -z "$QUERY" ]; then
  echo "Usage: search-tickets.sh <QUERY>" >&2
  exit 1
fi

DIR="$(pwd)"
while [ "$DIR" != "/" ]; do
  [ -f "$DIR/workspace.json" ] && break
  DIR=$(dirname "$DIR")
done
WORKSPACE_JSON="$DIR/workspace.json"

TOKEN_ENV=$(jq -r '.providers."ticket-management".config.apiTokenEnv // empty' "$WORKSPACE_JSON")
TOKEN=$(eval echo "\$$TOKEN_ENV" 2>/dev/null || echo "")
TEAM_ID=$(jq -r '.providers."ticket-management".config.teamId // empty' "$WORKSPACE_JSON")

if [ -z "$TOKEN" ] || [ -z "$TEAM_ID" ]; then
  echo "[]"
  exit 0
fi

ENCODED_QUERY=$(printf '%s' "$QUERY" | jq -sRr @uri)

RESPONSE=$(curl -s -H "Authorization: $TOKEN" "https://api.clickup.com/api/v2/team/$TEAM_ID/task?query=$ENCODED_QUERY&include_closed=true" 2>/dev/null || echo '{"tasks":[]}')

echo "$RESPONSE" | jq '[.tasks[] | {id: .id, summary: .name, status: .status.status}]' 2>/dev/null || echo "[]"
```

- [ ] **Step 7: Create transition-ticket.sh**

Write to `kraftwork-clickup/scripts/transition-ticket.sh`:

```sh
#!/bin/sh
#
# transition-ticket.sh - Transition a ClickUp task status
#
# Usage: transition-ticket.sh <TICKET_ID> <STATUS>
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or transition failed
#

set -eu

TICKET_ID="${1:-}"
STATUS="${2:-}"

if [ -z "$TICKET_ID" ] || [ -z "$STATUS" ]; then
  echo "Usage: transition-ticket.sh <TICKET_ID> <STATUS>" >&2
  exit 1
fi

DIR="$(pwd)"
while [ "$DIR" != "/" ]; do
  [ -f "$DIR/workspace.json" ] && break
  DIR=$(dirname "$DIR")
done
WORKSPACE_JSON="$DIR/workspace.json"

TOKEN_ENV=$(jq -r '.providers."ticket-management".config.apiTokenEnv // empty' "$WORKSPACE_JSON")
TOKEN=$(eval echo "\$$TOKEN_ENV" 2>/dev/null || echo "")

if [ -z "$TOKEN" ]; then
  echo "$TOKEN_ENV is not set" >&2
  exit 1
fi

RESPONSE=$(curl -s -X PUT \
  -H "Authorization: $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"status\": \"$STATUS\"}" \
  "https://api.clickup.com/api/v2/task/$TICKET_ID" 2>/dev/null)

ERROR=$(echo "$RESPONSE" | jq -r '.err // empty' 2>/dev/null)
if [ -n "$ERROR" ]; then
  echo "ClickUp API error: $ERROR" >&2
  exit 1
fi

echo "Transitioned $TICKET_ID to $STATUS"
```

- [ ] **Step 8: Create write-doc.sh**

Write to `kraftwork-clickup/scripts/write-doc.sh`:

```sh
#!/bin/sh
#
# write-doc.sh - Create a ClickUp Doc
#
# Usage: write-doc.sh <TITLE> <CONTENT> [SPACE_ID]
#   TITLE:    Document title
#   CONTENT:  Document content (markdown)
#   SPACE_ID: ClickUp space ID (defaults to first configured space)
#
# Output: Doc ID
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or creation failed
#

set -eu

TITLE="${1:-}"
CONTENT="${2:-}"
SPACE_ID="${3:-}"

if [ -z "$TITLE" ]; then
  echo "Usage: write-doc.sh <TITLE> <CONTENT> [SPACE_ID]" >&2
  exit 1
fi

DIR="$(pwd)"
while [ "$DIR" != "/" ]; do
  [ -f "$DIR/workspace.json" ] && break
  DIR=$(dirname "$DIR")
done
WORKSPACE_JSON="$DIR/workspace.json"

TOKEN_ENV=$(jq -r '.providers."document-storage".config.apiTokenEnv // .providers."ticket-management".config.apiTokenEnv // empty' "$WORKSPACE_JSON")
TOKEN=$(eval echo "\$$TOKEN_ENV" 2>/dev/null || echo "")

if [ -z "$TOKEN" ]; then
  echo "$TOKEN_ENV is not set" >&2
  exit 1
fi

if [ -z "$SPACE_ID" ]; then
  SPACE_ID=$(jq -r '.providers."document-storage".config.spaces[0].id // .providers."ticket-management".config.spaces[0].id // empty' "$WORKSPACE_JSON")
fi

if [ -z "$SPACE_ID" ]; then
  echo "No space ID configured or provided" >&2
  exit 1
fi

PAYLOAD=$(jq -n --arg title "$TITLE" --arg content "$CONTENT" '{name: $title, content: $content}')

RESPONSE=$(curl -s -X POST \
  -H "Authorization: $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "https://api.clickup.com/api/v3/workspaces/$(jq -r '.providers."ticket-management".config.teamId' "$WORKSPACE_JSON")/docs" 2>/dev/null)

DOC_ID=$(echo "$RESPONSE" | jq -r '.id // empty' 2>/dev/null)
if [ -z "$DOC_ID" ]; then
  echo "Failed to create doc" >&2
  exit 1
fi

echo "$DOC_ID"
```

- [ ] **Step 9: Create read-doc.sh**

Write to `kraftwork-clickup/scripts/read-doc.sh`:

```sh
#!/bin/sh
#
# read-doc.sh - Read a ClickUp Doc
#
# Usage: read-doc.sh <DOC_ID>
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or document not found
#

set -eu

DOC_ID="${1:-}"

if [ -z "$DOC_ID" ]; then
  echo "Usage: read-doc.sh <DOC_ID>" >&2
  exit 1
fi

DIR="$(pwd)"
while [ "$DIR" != "/" ]; do
  [ -f "$DIR/workspace.json" ] && break
  DIR=$(dirname "$DIR")
done
WORKSPACE_JSON="$DIR/workspace.json"

TOKEN_ENV=$(jq -r '.providers."document-storage".config.apiTokenEnv // .providers."ticket-management".config.apiTokenEnv // empty' "$WORKSPACE_JSON")
TOKEN=$(eval echo "\$$TOKEN_ENV" 2>/dev/null || echo "")

if [ -z "$TOKEN" ]; then
  echo "$TOKEN_ENV is not set" >&2
  exit 1
fi

TEAM_ID=$(jq -r '.providers."ticket-management".config.teamId // empty' "$WORKSPACE_JSON")

RESPONSE=$(curl -s \
  -H "Authorization: $TOKEN" \
  "https://api.clickup.com/api/v3/workspaces/$TEAM_ID/docs/$DOC_ID" 2>/dev/null)

ERROR=$(echo "$RESPONSE" | jq -r '.err // empty' 2>/dev/null)
if [ -n "$ERROR" ]; then
  echo "ClickUp API error: $ERROR" >&2
  exit 1
fi

echo "$RESPONSE" | jq -r '.content // .name // empty' 2>/dev/null
```

- [ ] **Step 10: Create list-docs.sh**

Write to `kraftwork-clickup/scripts/list-docs.sh`:

```sh
#!/bin/sh
#
# list-docs.sh - List ClickUp Docs
#
# Usage: list-docs.sh [SPACE_ID]
#   SPACE_ID: ClickUp space ID (defaults to listing all configured spaces)
#
# Output: JSON array of docs
#
# Exit codes:
#   0 - Success (may have 0 results)
#

set -eu

FILTER_SPACE="${1:-}"

DIR="$(pwd)"
while [ "$DIR" != "/" ]; do
  [ -f "$DIR/workspace.json" ] && break
  DIR=$(dirname "$DIR")
done
WORKSPACE_JSON="$DIR/workspace.json"

TOKEN_ENV=$(jq -r '.providers."document-storage".config.apiTokenEnv // .providers."ticket-management".config.apiTokenEnv // empty' "$WORKSPACE_JSON")
TOKEN=$(eval echo "\$$TOKEN_ENV" 2>/dev/null || echo "")
TEAM_ID=$(jq -r '.providers."ticket-management".config.teamId // empty' "$WORKSPACE_JSON")

if [ -z "$TOKEN" ] || [ -z "$TEAM_ID" ]; then
  echo "[]"
  exit 0
fi

if [ -n "$FILTER_SPACE" ]; then
  SPACE_IDS="$FILTER_SPACE"
else
  SPACE_IDS=$(jq -r '.providers."document-storage".config.spaces // .providers."ticket-management".config.spaces // [] | .[].id' "$WORKSPACE_JSON")
fi

ALL_DOCS="["
FIRST=1

for SPACE_ID in $SPACE_IDS; do
  RESPONSE=$(curl -s \
    -H "Authorization: $TOKEN" \
    "https://api.clickup.com/api/v3/workspaces/$TEAM_ID/docs?space_id=$SPACE_ID" 2>/dev/null || echo '{"docs":[]}')

  DOCS=$(echo "$RESPONSE" | jq -c '[.docs[] | {id: .id, title: .name, space_id: "'"$SPACE_ID"'"}]' 2>/dev/null || echo "[]")

  if [ "$FIRST" = "1" ]; then
    FIRST=0
    ALL_DOCS="${ALL_DOCS}$(echo "$DOCS" | jq -c '.[]' | tr '\n' ',')"
  else
    ALL_DOCS="${ALL_DOCS}$(echo "$DOCS" | jq -c '.[]' | tr '\n' ',')"
  fi
done

ALL_DOCS=$(echo "${ALL_DOCS%,}]" | jq '.' 2>/dev/null || echo "[]")
echo "$ALL_DOCS"
```

- [ ] **Step 11: Create ticket-id-pattern fragment**

Write to `kraftwork-clickup/fragments/ticket-id-pattern.md`:

```markdown
ClickUp task IDs are alphanumeric strings (e.g., `abc123`).
If custom task IDs are enabled, they follow the workspace's configured pattern.
The regex pattern is: `[a-z0-9]+` (case-insensitive).
```

- [ ] **Step 12: Make all scripts executable and commit**

```bash
chmod +x kraftwork-clickup/scripts/*.sh
git add kraftwork-clickup/
git commit -m "feat: add kraftwork-clickup extension (tickets + docs via ClickUp API)"
```

---

### Task 4: Verify All Three Extensions

- [ ] **Step 1: Verify template structure**

```bash
ls -la kraftwork-template/scripts/*.sh
ls -la kraftwork-template/fragments/
cat kraftwork-template/providers.json | jq '.providers | length'
```

Expected: all scripts executable, 3 fragments, 3 providers.

- [ ] **Step 2: Verify kraftwork-github structure**

```bash
ls -la kraftwork-github/scripts/*.sh
cat kraftwork-github/providers.json | jq '.providers[0].category'
```

Expected: all scripts executable, category is "git-hosting".

- [ ] **Step 3: Verify kraftwork-clickup structure**

```bash
ls -la kraftwork-clickup/scripts/*.sh
cat kraftwork-clickup/providers.json | jq '.providers | length'
cat kraftwork-clickup/providers.json | jq '[.providers[].category]'
```

Expected: all scripts executable, 2 providers, categories are ["ticket-management", "document-storage"].

- [ ] **Step 4: Verify no CHANGEME left in concrete extensions**

```bash
grep -r "CHANGEME" kraftwork-github/ kraftwork-clickup/ || echo "No CHANGEME found"
```

Expected: "No CHANGEME found"

- [ ] **Step 5: Verify CHANGEME exists in template**

```bash
grep -r "CHANGEME" kraftwork-template/ | head -10
```

Expected: multiple matches (plugin.json, workspace-config.json, fragments).

- [ ] **Step 6: Commit any fixes**

```bash
git add -A && git commit -m "fix: address issues found during verification" || echo "Nothing to fix"
```
