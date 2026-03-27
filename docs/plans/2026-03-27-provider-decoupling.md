# Provider Decoupling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decouple kraftwork core from vendor-specific extensions so it orchestrates workflows through provider abstractions, not hardcoded vendor CLIs.

**Architecture:** Three provider categories (git-hosting, ticket-management, document-storage) with a manifest + script + fragment system. Extensions declare capabilities via `providers.json`. Core resolves providers from `workspace.json` at runtime. A built-in `kraftwork-local` provider handles fallback for local-only workflows.

**Tech Stack:** Shell scripts (sh), Markdown (SKILL.md), JSON (providers.json, workspace.json)

---

### Task 1: Create kraftwork-local Provider

The built-in fallback provider, bundled inside core. This is the foundation — all other tasks depend on being able to resolve a provider, and this one always exists.

**Files:**
- Create: `kraftwork/providers/local/providers.json`
- Create: `kraftwork/providers/local/scripts/auth-check.sh`
- Create: `kraftwork/providers/local/scripts/search-branches.sh`
- Create: `kraftwork/providers/local/scripts/write-doc.sh`
- Create: `kraftwork/providers/local/scripts/read-doc.sh`
- Create: `kraftwork/providers/local/scripts/list-docs.sh`
- Create: `kraftwork/providers/local/scripts/fetch-ticket.sh`
- Create: `kraftwork/providers/local/scripts/search-tickets.sh`
- Create: `kraftwork/providers/local/scripts/transition-ticket.sh`
- Create: `kraftwork/providers/local/fragments/ticket-id-pattern.md`

- [ ] **Step 1: Create providers.json manifest**

```json
{
  "providers": [
    {
      "category": "git-hosting",
      "scripts": {
        "auth-check": "scripts/auth-check.sh",
        "search-branches": "scripts/search-branches.sh"
      },
      "fragments": {}
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

Write to `kraftwork/providers/local/providers.json`.

- [ ] **Step 2: Create git-hosting scripts**

`kraftwork/providers/local/scripts/auth-check.sh`:
```sh
#!/bin/sh
# Local git — always authenticated
exit 0
```

`kraftwork/providers/local/scripts/search-branches.sh`:
```sh
#!/bin/sh
# Search local branches only (no remote)
# Usage: search-branches.sh <TICKET_ID> [WORKSPACE]
# Output: JSON array of matching branches
set -eu

TICKET_ID="${1:-}"
WORKSPACE="${2:-}"

if [ -z "$TICKET_ID" ]; then
  echo "Usage: search-branches.sh <TICKET_ID> [WORKSPACE]" >&2
  exit 1
fi

SCRIPT_DIR=$(dirname "$0")
PROVIDER_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
PLUGIN_ROOT=$(cd "$PROVIDER_ROOT/../.." && pwd)

if [ -z "$WORKSPACE" ]; then
  WORKSPACE=$("$PLUGIN_ROOT/scripts/find-workspace.sh" 2>/dev/null) || {
    echo '{"error": "workspace not found"}' >&2
    exit 2
  }
fi

if [ ! -d "$WORKSPACE/modules" ]; then
  echo "[]"
  exit 0
fi

RESULTS="["
FIRST=1

for REPO_PATH in "$WORKSPACE/modules"/*/; do
  [ -d "$REPO_PATH/.git" ] || continue
  REPO_NAME=$(basename "$REPO_PATH")

  BRANCHES=$(git -C "$REPO_PATH" branch 2>/dev/null | grep -i "$TICKET_ID" || true)
  if [ -n "$BRANCHES" ]; then
    echo "$BRANCHES" | while read -r BRANCH_LINE; do
      BRANCH=$(echo "$BRANCH_LINE" | sed 's/^[* ]*//')
      case "$BRANCH" in *HEAD*) continue ;; esac

      if [ "$FIRST" = "1" ]; then
        FIRST=0
        printf '  {"repo": "%s", "branch": "%s", "location": "local"}' "$REPO_NAME" "$BRANCH"
      else
        printf ',\n  {"repo": "%s", "branch": "%s", "location": "local"}' "$REPO_NAME" "$BRANCH"
      fi
    done
  fi
done

echo ""
echo "]"
```

Make both executable: `chmod +x kraftwork/providers/local/scripts/auth-check.sh kraftwork/providers/local/scripts/search-branches.sh`

- [ ] **Step 3: Create document-storage scripts**

`kraftwork/providers/local/scripts/write-doc.sh`:
```sh
#!/bin/sh
# Write a document to local filesystem
# Usage: write-doc.sh <PATH> <CONTENT>
# PATH is relative to workspace docs/ directory
set -eu

DOC_PATH="${1:-}"
CONTENT="${2:-}"

if [ -z "$DOC_PATH" ]; then
  echo "Usage: write-doc.sh <PATH> <CONTENT>" >&2
  exit 1
fi

SCRIPT_DIR=$(dirname "$0")
PROVIDER_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
PLUGIN_ROOT=$(cd "$PROVIDER_ROOT/../.." && pwd)
WORKSPACE=$("$PLUGIN_ROOT/scripts/find-workspace.sh" 2>/dev/null) || exit 2

FULL_PATH="$WORKSPACE/docs/$DOC_PATH"
mkdir -p "$(dirname "$FULL_PATH")"
printf '%s' "$CONTENT" > "$FULL_PATH"
echo "$FULL_PATH"
```

`kraftwork/providers/local/scripts/read-doc.sh`:
```sh
#!/bin/sh
# Read a document from local filesystem
# Usage: read-doc.sh <PATH>
set -eu

DOC_PATH="${1:-}"

if [ -z "$DOC_PATH" ]; then
  echo "Usage: read-doc.sh <PATH>" >&2
  exit 1
fi

SCRIPT_DIR=$(dirname "$0")
PROVIDER_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
PLUGIN_ROOT=$(cd "$PROVIDER_ROOT/../.." && pwd)
WORKSPACE=$("$PLUGIN_ROOT/scripts/find-workspace.sh" 2>/dev/null) || exit 2

FULL_PATH="$WORKSPACE/docs/$DOC_PATH"
if [ ! -f "$FULL_PATH" ]; then
  echo "Document not found: $FULL_PATH" >&2
  exit 1
fi
cat "$FULL_PATH"
```

`kraftwork/providers/local/scripts/list-docs.sh`:
```sh
#!/bin/sh
# List documents under a prefix
# Usage: list-docs.sh [PREFIX]
set -eu

PREFIX="${1:-}"

SCRIPT_DIR=$(dirname "$0")
PROVIDER_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
PLUGIN_ROOT=$(cd "$PROVIDER_ROOT/../.." && pwd)
WORKSPACE=$("$PLUGIN_ROOT/scripts/find-workspace.sh" 2>/dev/null) || exit 2

DOCS_DIR="$WORKSPACE/docs"
if [ ! -d "$DOCS_DIR/$PREFIX" ]; then
  echo "[]"
  exit 0
fi

find "$DOCS_DIR/$PREFIX" -type f | sort | while read -r f; do
  echo "${f#$DOCS_DIR/}"
done
```

Make all executable.

- [ ] **Step 4: Create ticket-management scripts**

`kraftwork/providers/local/scripts/fetch-ticket.sh`:
```sh
#!/bin/sh
# Fetch a ticket from local tasks/ directory
# Usage: fetch-ticket.sh <TICKET_ID>
# Output: JSON with summary and status, or exit 1 if not found
set -eu

TICKET_ID="${1:-}"

if [ -z "$TICKET_ID" ]; then
  echo "Usage: fetch-ticket.sh <TICKET_ID>" >&2
  exit 1
fi

SCRIPT_DIR=$(dirname "$0")
PROVIDER_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
PLUGIN_ROOT=$(cd "$PROVIDER_ROOT/../.." && pwd)
WORKSPACE=$("$PLUGIN_ROOT/scripts/find-workspace.sh" 2>/dev/null) || exit 2

TASK_FILE="$WORKSPACE/tasks/${TICKET_ID}.md"
if [ ! -f "$TASK_FILE" ]; then
  echo '{"error": "ticket not found"}' >&2
  exit 1
fi

SUMMARY=$(head -1 "$TASK_FILE" | sed 's/^#* *//')
STATUS=$(grep -oE '\[(todo|in-progress|done)\]' "$TASK_FILE" | head -1 | tr -d '[]' || echo "unknown")

printf '{"id": "%s", "summary": "%s", "status": "%s"}\n' "$TICKET_ID" "$SUMMARY" "$STATUS"
```

`kraftwork/providers/local/scripts/search-tickets.sh`:
```sh
#!/bin/sh
# Search local tasks/ directory
# Usage: search-tickets.sh <QUERY>
set -eu

QUERY="${1:-}"

SCRIPT_DIR=$(dirname "$0")
PROVIDER_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
PLUGIN_ROOT=$(cd "$PROVIDER_ROOT/../.." && pwd)
WORKSPACE=$("$PLUGIN_ROOT/scripts/find-workspace.sh" 2>/dev/null) || exit 2

TASKS_DIR="$WORKSPACE/tasks"
if [ ! -d "$TASKS_DIR" ]; then
  echo "[]"
  exit 0
fi

echo "["
FIRST=1
for f in "$TASKS_DIR"/*.md; do
  [ -f "$f" ] || continue
  if [ -z "$QUERY" ] || grep -qi "$QUERY" "$f" 2>/dev/null; then
    ID=$(basename "$f" .md)
    SUMMARY=$(head -1 "$f" | sed 's/^#* *//')
    if [ "$FIRST" = "1" ]; then
      FIRST=0
      printf '  {"id": "%s", "summary": "%s"}' "$ID" "$SUMMARY"
    else
      printf ',\n  {"id": "%s", "summary": "%s"}' "$ID" "$SUMMARY"
    fi
  fi
done
echo ""
echo "]"
```

`kraftwork/providers/local/scripts/transition-ticket.sh`:
```sh
#!/bin/sh
# Transition a local ticket's status
# Usage: transition-ticket.sh <TICKET_ID> <STATUS>
set -eu

TICKET_ID="${1:-}"
NEW_STATUS="${2:-}"

if [ -z "$TICKET_ID" ] || [ -z "$NEW_STATUS" ]; then
  echo "Usage: transition-ticket.sh <TICKET_ID> <STATUS>" >&2
  exit 1
fi

SCRIPT_DIR=$(dirname "$0")
PROVIDER_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
PLUGIN_ROOT=$(cd "$PROVIDER_ROOT/../.." && pwd)
WORKSPACE=$("$PLUGIN_ROOT/scripts/find-workspace.sh" 2>/dev/null) || exit 2

TASK_FILE="$WORKSPACE/tasks/${TICKET_ID}.md"
if [ ! -f "$TASK_FILE" ]; then
  echo "Ticket not found: $TICKET_ID" >&2
  exit 1
fi

sed -i '' "s/\[todo\]/[$NEW_STATUS]/g; s/\[in-progress\]/[$NEW_STATUS]/g; s/\[done\]/[$NEW_STATUS]/g" "$TASK_FILE"
echo "Transitioned $TICKET_ID to $NEW_STATUS"
```

Make all executable.

- [ ] **Step 5: Create ticket-id-pattern fragment**

`kraftwork/providers/local/fragments/ticket-id-pattern.md`:
```markdown
Local ticket IDs use the format: filename without extension from the `tasks/` directory. Any string is valid as a ticket ID (e.g., `fix-login-bug`, `TASK-001`).
```

- [ ] **Step 6: Commit**

```bash
git add kraftwork/providers/local/
git commit -m "feat: add kraftwork-local built-in provider

Provides fallback implementations for all three provider categories:
- git-hosting: auth-check (always passes), local branch search
- ticket-management: file-based tasks in workspace/tasks/
- document-storage: local filesystem under workspace/docs/"
```

---

### Task 2: Create Provider Resolution Script

A single script that core skills call to resolve provider paths at runtime. This is the bridge between `workspace.json` config and the actual provider scripts/fragments.

**Files:**
- Create: `kraftwork/scripts/resolve-provider.sh`

- [ ] **Step 1: Write the resolve-provider script**

`kraftwork/scripts/resolve-provider.sh`:
```sh
#!/bin/sh
# Resolve a provider capability to an executable path or fragment content
#
# Usage:
#   resolve-provider.sh script <category> <capability>
#     → prints absolute path to the script (exit 0) or exit 1 if unavailable
#
#   resolve-provider.sh fragment <category> <fragment-name>
#     → prints fragment file content (exit 0) or empty string (exit 1)
#
#   resolve-provider.sh has <category> <capability>
#     → exit 0 if capability exists, exit 1 if not
#
# Reads workspace.json to determine which plugin provides the category,
# then reads that plugin's providers.json to find the capability.

set -eu

MODE="${1:-}"
CATEGORY="${2:-}"
CAPABILITY="${3:-}"

if [ -z "$MODE" ] || [ -z "$CATEGORY" ] || [ -z "$CAPABILITY" ]; then
  echo "Usage: resolve-provider.sh <script|fragment|has> <category> <capability>" >&2
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PLUGIN_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

WORKSPACE=$("$SCRIPT_DIR/find-workspace.sh" 2>/dev/null) || {
  echo "Workspace not found" >&2
  exit 1
}

WORKSPACE_JSON="$WORKSPACE/workspace.json"
if [ ! -f "$WORKSPACE_JSON" ]; then
  echo "No workspace.json found" >&2
  exit 1
fi

PLUGIN_NAME=$(jq -r ".providers.\"$CATEGORY\".plugin // empty" "$WORKSPACE_JSON")

if [ -z "$PLUGIN_NAME" ]; then
  exit 1
fi

if [ "$PLUGIN_NAME" = "kraftwork-local" ]; then
  PROVIDER_ROOT="$PLUGIN_ROOT/providers/local"
else
  CACHE_DIR="$HOME/.claude/plugins/cache"
  SETTINGS="$HOME/.claude/settings.json"

  MARKETPLACE=""
  if [ -f "$SETTINGS" ]; then
    MARKETPLACE=$(jq -r ".enabledPlugins // {} | to_entries[] | select(.key | startswith(\"$PLUGIN_NAME@\")) | .key | split(\"@\")[1]" "$SETTINGS" | head -1)
  fi

  if [ -z "$MARKETPLACE" ]; then
    for DIR in "$CACHE_DIR"/*/; do
      if [ -d "$DIR/$PLUGIN_NAME" ]; then
        MARKETPLACE=$(basename "$DIR")
        break
      fi
    done
  fi

  if [ -z "$MARKETPLACE" ]; then
    exit 1
  fi

  PLUGIN_DIR="$CACHE_DIR/$MARKETPLACE/$PLUGIN_NAME"
  VERSION_DIR=$(ls -1 "$PLUGIN_DIR" 2>/dev/null | head -1)
  PROVIDER_ROOT="$PLUGIN_DIR/$VERSION_DIR"
fi

PROVIDERS_JSON="$PROVIDER_ROOT/providers.json"
if [ ! -f "$PROVIDERS_JSON" ]; then
  exit 1
fi

TYPE_KEY=""
case "$MODE" in
  script) TYPE_KEY="scripts" ;;
  fragment) TYPE_KEY="fragments" ;;
  has) TYPE_KEY="scripts" ;;
esac

RELATIVE_PATH=$(jq -r ".providers[] | select(.category == \"$CATEGORY\") | .${TYPE_KEY}.\"$CAPABILITY\" // empty" "$PROVIDERS_JSON")

if [ "$MODE" = "has" ] && [ -z "$RELATIVE_PATH" ]; then
  RELATIVE_PATH=$(jq -r ".providers[] | select(.category == \"$CATEGORY\") | .fragments.\"$CAPABILITY\" // empty" "$PROVIDERS_JSON")
fi

if [ -z "$RELATIVE_PATH" ]; then
  exit 1
fi

FULL_PATH="$PROVIDER_ROOT/$RELATIVE_PATH"

case "$MODE" in
  script)
    if [ ! -x "$FULL_PATH" ]; then
      echo "Provider script not executable: $FULL_PATH" >&2
      exit 1
    fi
    echo "$FULL_PATH"
    ;;
  fragment)
    if [ -f "$FULL_PATH" ]; then
      cat "$FULL_PATH"
    fi
    ;;
  has)
    [ -e "$FULL_PATH" ]
    ;;
esac
```

Make executable.

- [ ] **Step 2: Commit**

```bash
git add kraftwork/scripts/resolve-provider.sh
git commit -m "feat: add provider resolution script

Central dispatch for resolving provider capabilities to executable
paths or fragment content. Reads workspace.json for provider config,
then the provider's providers.json for capability mapping."
```

---

### Task 3: Add providers.json to kraftwork-gitlab

Move GitLab-specific scripts from core into the extension and declare provider capabilities.

**Files:**
- Create: `kraftwork-gitlab/providers.json`
- Create: `kraftwork-gitlab/scripts/auth-check.sh`
- Create: `kraftwork-gitlab/scripts/search-prs.sh`
- Create: `kraftwork-gitlab/scripts/search-branches.sh`
- Create: `kraftwork-gitlab/scripts/clone-repo.sh`
- Create: `kraftwork-gitlab/scripts/create-pr.sh`
- Create: `kraftwork-gitlab/scripts/fetch-pr-details.sh`
- Create: `kraftwork-gitlab/scripts/ci-status.sh`
- Create: `kraftwork-gitlab/fragments/pr-description-guide.md`
- Create: `kraftwork-gitlab/fragments/branch-naming.md`

- [ ] **Step 1: Create providers.json**

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

- [ ] **Step 2: Create auth-check.sh**

```sh
#!/bin/sh
# Check glab CLI is installed and authenticated
set -eu

if ! command -v glab >/dev/null 2>&1; then
  echo "glab CLI not installed. Install: https://gitlab.com/gitlab-org/cli" >&2
  exit 1
fi

if ! glab auth status >/dev/null 2>&1; then
  echo "glab not authenticated. Run: glab auth login" >&2
  exit 1
fi

exit 0
```

- [ ] **Step 3: Create search-prs.sh**

This is the current `search-ticket-mrs.sh` from core, adapted to the provider interface:

```sh
#!/bin/sh
# Search GitLab MRs for a ticket
# Usage: search-prs.sh <TICKET_ID> [GITLAB_GROUP]
# Output: JSON array of matching PRs
set -eu

TICKET_ID="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -z "$TICKET_ID" ]; then
  echo "Usage: search-prs.sh <TICKET_ID> [GITLAB_GROUP]" >&2
  exit 1
fi

if ! command -v glab >/dev/null 2>&1; then
  echo '[]'
  exit 0
fi

if ! glab auth status >/dev/null 2>&1; then
  echo '[]'
  exit 0
fi

# Read group from argument or workspace.json
if [ -n "${2:-}" ]; then
  GITLAB_GROUP="$2"
else
  PROVIDER_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
  # Try to find workspace.json for config
  WORKSPACE_JSON=""
  DIR="$(pwd)"
  while [ "$DIR" != "/" ]; do
    if [ -f "$DIR/workspace.json" ]; then
      WORKSPACE_JSON="$DIR/workspace.json"
      break
    fi
    DIR=$(dirname "$DIR")
  done
  if [ -n "$WORKSPACE_JSON" ]; then
    GITLAB_GROUP=$(jq -r '.providers."git-hosting".config.defaultGroup // .git.group // empty' "$WORKSPACE_JSON")
  else
    echo '[]'
    exit 0
  fi
fi

MRS=$(glab api "groups/${GITLAB_GROUP}/merge_requests?search=${TICKET_ID}&state=all&per_page=20" 2>/dev/null || echo "[]")

if [ -z "$MRS" ] || [ "$MRS" = "null" ]; then
  echo "[]"
  exit 0
fi

echo "$MRS" | jq -r '
  if type == "array" then
    [.[] | {
      id: .iid,
      title: .title,
      url: .web_url,
      branch: .source_branch,
      state: .state,
      repo: (.references.full | split("!")[0])
    }]
  else
    []
  end
' 2>/dev/null || echo "[]"
```

- [ ] **Step 4: Create search-branches.sh**

```sh
#!/bin/sh
# Search local and remote branches for a ticket
# Usage: search-branches.sh <TICKET_ID> [WORKSPACE]
# Output: JSON array of matching branches
set -eu

SCRIPT_DIR=$(dirname "$0")
TICKET_ID="${1:-}"
WORKSPACE="${2:-}"

if [ -z "$TICKET_ID" ]; then
  echo "Usage: search-branches.sh <TICKET_ID> [WORKSPACE]" >&2
  exit 1
fi

if [ -z "$WORKSPACE" ]; then
  DIR="$(pwd)"
  while [ "$DIR" != "/" ]; do
    if [ -f "$DIR/workspace.json" ]; then
      WORKSPACE="$DIR"
      break
    fi
    DIR=$(dirname "$DIR")
  done
fi

MODULES_DIR="$WORKSPACE/modules"
if [ ! -d "$MODULES_DIR" ]; then
  # Fallback to legacy layout
  MODULES_DIR="$WORKSPACE/sources"
fi

if [ ! -d "$MODULES_DIR" ]; then
  echo "[]"
  exit 0
fi

echo "["
FIRST=1
find "$MODULES_DIR" -maxdepth 1 -type d ! -name "$(basename "$MODULES_DIR")" | sort | while read -r REPO_PATH; do
  [ -d "$REPO_PATH/.git" ] || continue
  REPO_NAME=$(basename "$REPO_PATH")

  git -C "$REPO_PATH" fetch --quiet 2>/dev/null || true
  BRANCHES=$(git -C "$REPO_PATH" branch -a 2>/dev/null | grep -i "$TICKET_ID" || true)

  if [ -n "$BRANCHES" ]; then
    echo "$BRANCHES" | while read -r BRANCH_LINE; do
      BRANCH=$(echo "$BRANCH_LINE" | sed 's/^[* ]*//' | sed 's|remotes/origin/||')
      case "$BRANCH" in *HEAD*) continue ;; esac
      case "$BRANCH_LINE" in
        *remotes/*) LOCATION="remote" ;;
        *) LOCATION="local" ;;
      esac

      if [ "$FIRST" = "1" ]; then
        FIRST=0
        printf '  {"repo": "%s", "branch": "%s", "location": "%s"}' "$REPO_NAME" "$BRANCH" "$LOCATION"
      else
        printf ',\n  {"repo": "%s", "branch": "%s", "location": "%s"}' "$REPO_NAME" "$BRANCH" "$LOCATION"
      fi
    done
  fi
done
echo ""
echo "]"
```

- [ ] **Step 5: Create clone-repo.sh**

```sh
#!/bin/sh
# Clone a repo using glab
# Usage: clone-repo.sh <GROUP> <REPO> <DEST>
set -eu

GROUP="${1:-}"
REPO="${2:-}"
DEST="${3:-}"

if [ -z "$GROUP" ] || [ -z "$REPO" ] || [ -z "$DEST" ]; then
  echo "Usage: clone-repo.sh <GROUP> <REPO> <DEST>" >&2
  exit 1
fi

glab repo clone "$GROUP/$REPO" "$DEST"
```

- [ ] **Step 6: Create create-pr.sh**

```sh
#!/bin/sh
# Create a GitLab merge request
# Usage: create-pr.sh <SOURCE_BRANCH> <TARGET_BRANCH> <TITLE> <BODY>
# Output: MR URL
set -eu

SOURCE="${1:-}"
TARGET="${2:-}"
TITLE="${3:-}"
BODY="${4:-}"

if [ -z "$SOURCE" ] || [ -z "$TARGET" ] || [ -z "$TITLE" ]; then
  echo "Usage: create-pr.sh <SOURCE> <TARGET> <TITLE> [BODY]" >&2
  exit 1
fi

git push -u origin "$SOURCE" 2>/dev/null || true

if [ -n "$BODY" ]; then
  glab mr create --source-branch "$SOURCE" --target-branch "$TARGET" --title "$TITLE" --description "$BODY" --yes
else
  glab mr create --source-branch "$SOURCE" --target-branch "$TARGET" --title "$TITLE" --yes
fi
```

- [ ] **Step 7: Create fetch-pr-details.sh**

```sh
#!/bin/sh
# Fetch PR/MR details including discussions and changes
# Usage: fetch-pr-details.sh <MR_IID>
# Must be run from within a git repo
# Output: JSON object with details, discussions, changes, commits
set -eu

MR_IID="${1:-}"

if [ -z "$MR_IID" ]; then
  echo "Usage: fetch-pr-details.sh <MR_IID>" >&2
  exit 1
fi

REMOTE_URL=$(git remote get-url origin 2>/dev/null)
REPO=$(echo "$REMOTE_URL" | sed -E 's|.*:(.*)\.git$|\1|; s|https?://[^/]+/||')
ENCODED_REPO=$(echo "$REPO" | sed 's|/|%2F|g')

DETAILS=$(glab api "projects/$ENCODED_REPO/merge_requests/$MR_IID" 2>/dev/null || echo "{}")
DISCUSSIONS=$(glab api "projects/$ENCODED_REPO/merge_requests/$MR_IID/discussions" 2>/dev/null || echo "[]")
CHANGES=$(glab api "projects/$ENCODED_REPO/merge_requests/$MR_IID/changes" 2>/dev/null || echo "{}")
COMMITS=$(glab api "projects/$ENCODED_REPO/merge_requests/$MR_IID/commits" 2>/dev/null || echo "[]")

printf '{"details": %s, "discussions": %s, "changes": %s, "commits": %s}\n' \
  "$DETAILS" "$DISCUSSIONS" "$CHANGES" "$COMMITS"
```

- [ ] **Step 8: Create ci-status.sh**

```sh
#!/bin/sh
# Get CI pipeline status for a branch
# Usage: ci-status.sh <BRANCH>
# Output: JSON with pipeline status
set -eu

BRANCH="${1:-}"

if [ -z "$BRANCH" ]; then
  echo "Usage: ci-status.sh <BRANCH>" >&2
  exit 1
fi

glab ci status --branch "$BRANCH" 2>/dev/null || echo '{"status": "unavailable"}'
```

- [ ] **Step 9: Create fragments**

`kraftwork-gitlab/fragments/pr-description-guide.md`:
```markdown
Include `Closes <TICKET-ID>` in the MR description for auto-closing the linked issue.
Use GitLab-flavored markdown. CI pipeline runs automatically on push.
For stacked MRs, include `Stacked on !<parent-MR-number>` and note merge order.
```

`kraftwork-gitlab/fragments/branch-naming.md`:
```markdown
Branch naming convention: `<ticket-id>-<slug>` (e.g., `PROJ-123-add-login-endpoint`).
The ticket ID prefix enables automatic MR-to-ticket linking.
```

- [ ] **Step 10: Make all scripts executable and commit**

```bash
chmod +x kraftwork-gitlab/scripts/*.sh
git add kraftwork-gitlab/providers.json kraftwork-gitlab/scripts/ kraftwork-gitlab/fragments/
git commit -m "feat: add provider manifest and scripts to kraftwork-gitlab

Declares git-hosting category with all capabilities:
auth-check, search-prs, search-branches, clone-repo,
create-pr, fetch-pr-details, ci-status.
Plus pr-description-guide and branch-naming fragments."
```

---

### Task 4: Add providers.json to kraftwork-jira

**Files:**
- Create: `kraftwork-jira/providers.json`
- Create: `kraftwork-jira/scripts/fetch-ticket.sh`
- Create: `kraftwork-jira/scripts/search-tickets.sh`
- Create: `kraftwork-jira/scripts/transition-ticket.sh`
- Create: `kraftwork-jira/fragments/ticket-id-pattern.md`

- [ ] **Step 1: Create providers.json**

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
    }
  ]
}
```

- [ ] **Step 2: Create fetch-ticket.sh**

```sh
#!/bin/sh
# Fetch a Jira ticket's details
# Usage: fetch-ticket.sh <TICKET_ID>
# Output: JSON with id, summary, status
set -eu

TICKET_ID="${1:-}"

if [ -z "$TICKET_ID" ]; then
  echo "Usage: fetch-ticket.sh <TICKET_ID>" >&2
  exit 1
fi

if ! command -v acli >/dev/null 2>&1; then
  echo '{"error": "acli not installed"}' >&2
  exit 1
fi

TICKET_JSON=$(acli jira workitem view "$TICKET_ID" --fields summary,status --json 2>/dev/null || echo "{}")
SUMMARY=$(echo "$TICKET_JSON" | jq -r '.fields.summary // empty')
STATUS=$(echo "$TICKET_JSON" | jq -r '.fields.status.name // empty')

if [ -z "$SUMMARY" ]; then
  echo '{"error": "ticket not found or acli not configured"}' >&2
  exit 1
fi

printf '{"id": "%s", "summary": "%s", "status": "%s"}\n' "$TICKET_ID" "$SUMMARY" "$STATUS"
```

- [ ] **Step 3: Create search-tickets.sh**

```sh
#!/bin/sh
# Search Jira tickets
# Usage: search-tickets.sh <QUERY>
# Output: JSON array of matching tickets
set -eu

QUERY="${1:-}"

if ! command -v acli >/dev/null 2>&1; then
  echo '[]'
  exit 0
fi

acli jira workitem list --jql "text ~ \"$QUERY\"" --json 2>/dev/null || echo "[]"
```

- [ ] **Step 4: Create transition-ticket.sh**

```sh
#!/bin/sh
# Transition a Jira ticket
# Usage: transition-ticket.sh <TICKET_ID> <STATUS>
set -eu

TICKET_ID="${1:-}"
STATUS="${2:-}"

if [ -z "$TICKET_ID" ] || [ -z "$STATUS" ]; then
  echo "Usage: transition-ticket.sh <TICKET_ID> <STATUS>" >&2
  exit 1
fi

if ! command -v acli >/dev/null 2>&1; then
  echo "acli not installed" >&2
  exit 1
fi

acli jira workitem transition "$TICKET_ID" "$STATUS"
```

- [ ] **Step 5: Create ticket-id-pattern fragment**

`kraftwork-jira/fragments/ticket-id-pattern.md`:
```markdown
Jira ticket IDs follow the pattern `<PROJECT>-<NUMBER>` (e.g., `PROJ-1234`, `ENG-567`).
The regex pattern is: `[A-Z]+-[0-9]+`
```

- [ ] **Step 6: Make executable and commit**

```bash
chmod +x kraftwork-jira/scripts/*.sh
git add kraftwork-jira/providers.json kraftwork-jira/scripts/ kraftwork-jira/fragments/
git commit -m "feat: add provider manifest and scripts to kraftwork-jira

Declares ticket-management category with fetch-ticket,
search-tickets, transition-ticket capabilities."
```

---

### Task 5: Update workspace.json Schema and kraft-config Skill

Rewrite `kraft-init` as `kraft-config` with provider discovery, per-category selection, and the new workspace layout.

**Files:**
- Modify: `kraftwork/config/workspace-config.json`
- Modify: `kraftwork/skills/kraft-init/SKILL.md` (rename to kraft-config)
- Create: `kraftwork/skills/kraft-config/SKILL.md`
- Delete: `kraftwork/skills/kraft-init/SKILL.md`

- [ ] **Step 1: Update workspace-config.json**

Replace the `git` section with a streamlined version. The host-specific details now come from the git-hosting provider.

```json
[
  {
    "section": "workspace",
    "title": "Workspace Configuration",
    "description": "Core workspace settings — name and path",
    "fields": [
      {
        "key": "name",
        "type": "string",
        "prompt": "What would you like to name this workspace?",
        "example": "my-project",
        "required": true
      },
      {
        "key": "path",
        "type": "string",
        "prompt": "Where is the workspace root directory?",
        "example": "~/Developer/my-project",
        "required": true
      }
    ]
  }
]
```

The `git` section is removed — git host/group/repos are now part of the git-hosting provider's config, collected during provider selection.

- [ ] **Step 2: Create kraft-config SKILL.md**

Write the complete skill to `kraftwork/skills/kraft-config/SKILL.md`. This is the full rewrite of kraft-init. Key changes:

1. **Provider discovery phase** — scans `kraftwork-*` plugins for `providers.json`, groups by category, presents per-category choices
2. **New workspace layout** — `modules/` (submodules), `trees/` (gitignored), lazy `tasks/` and `docs/`
3. **Workspace is a git repo** — `git init` on first run, modules added as submodules
4. **Idempotent** — re-run detects new plugins, missing config, prompts only for deltas
5. **Provider-specific config** — each provider's `workspace-config.json` fields are collected after selection

The skill content is substantial (250+ lines). Write it referencing the spec at `docs/specs/2026-03-27-provider-decoupling-design.md` for the provider discovery flow, workspace layout, and config structure. The skill must:

- Read `~/.claude/plugins/cache/` to find installed kraftwork-* plugins with `providers.json`
- Group providers by category
- For each category: auto-select if one, ask if multiple, default to `kraftwork-local` if none
- Write the `providers` section to `workspace.json` in the format from the spec
- Collect provider-specific config (from their `workspace-config.json`) after selection
- Create `modules/`, `trees/`, `.gitignore` (trees/)
- `git init` the workspace if not already a repo
- Clone repos as submodules via the git-hosting provider's `clone-repo` script (if available)
- Generate CLAUDE.md

- [ ] **Step 3: Remove old kraft-init**

```bash
rm -rf kraftwork/skills/kraft-init
```

- [ ] **Step 4: Commit**

```bash
git add kraftwork/config/workspace-config.json kraftwork/skills/kraft-config/ kraftwork/skills/kraft-init
git commit -m "feat: replace kraft-init with kraft-config

Provider-aware workspace configuration with:
- Discovery of installed kraftwork-* provider plugins
- Per-category provider selection
- New workspace layout (modules/, trees/)
- Workspace as git repo with submodules
- Idempotent re-run with delta detection"
```

---

### Task 6: Create kraft-work Skill (Merge start + resume + stack)

**Files:**
- Create: `kraftwork/skills/kraft-work/SKILL.md`
- Delete: `kraftwork/skills/kraft-start/SKILL.md`
- Delete: `kraftwork/skills/kraft-resume/SKILL.md`
- Delete: `kraftwork/skills/kraft-stack/SKILL.md`

- [ ] **Step 1: Write kraft-work SKILL.md**

The unified skill that replaces kraft-start, kraft-resume, and kraft-stack. Write to `kraftwork/skills/kraft-work/SKILL.md`.

**Context-aware routing logic:**

```
Input: /kraft-work [TICKET_ID_OR_BRANCH]

1. If TICKET_ID provided:
   a. Search for existing worktree matching ID in workspace/trees/
   b. If found → resume flow (show status, suggest next action)
   c. If not found → create flow (fetch ticket, create worktree)

2. If no argument provided:
   a. If currently inside a worktree → show status of current worktree
   b. If active worktrees exist → list them, let user pick
   c. If no worktrees → prompt for ticket ID or branch name

3. If inside a worktree AND argument provided:
   a. Offer: "Stack on current worktree, or start fresh from main?"
```

**Provider delegation:**

- Ticket details: call `resolve-provider.sh script ticket-management fetch-ticket` — if exit 1, prompt user for description directly
- PR/branch search: call `resolve-provider.sh script git-hosting search-prs` — if exit 1, skip
- Branch search: call `resolve-provider.sh script git-hosting search-branches` — if exit 1, search local only
- Repo cloning: call `resolve-provider.sh script git-hosting clone-repo` — if exit 1, error with guidance

**Directory references:**
- `workspace/trees/` (not tasks/)
- `workspace/modules/` (not sources/)
- `workspace/docs/specs/` for spec directory

**Stack-aware resume features** (from kraft-resume):
- Detect `.stack-metadata.json` via `stack-metadata.sh read`
- Show parent-child relationships
- Offer rebase/promote actions for stacked PRs

- [ ] **Step 2: Remove old skills**

```bash
rm -rf kraftwork/skills/kraft-start
rm -rf kraftwork/skills/kraft-resume
rm -rf kraftwork/skills/kraft-stack
```

- [ ] **Step 3: Commit**

```bash
git add kraftwork/skills/kraft-work/ kraftwork/skills/kraft-start kraftwork/skills/kraft-resume kraftwork/skills/kraft-stack
git commit -m "feat: merge kraft-start/resume/stack into kraft-work

Context-aware unified skill:
- Argument + no worktree → create (was kraft-start)
- Argument + existing worktree → resume (was kraft-resume)
- No argument → list and pick (was kraft-resume)
- Inside worktree + argument → offer stack (was kraft-stack)

All vendor references replaced with provider delegation."
```

---

### Task 7: Update kraft-plan to Use Provider Delegation

**Files:**
- Modify: `kraftwork/skills/kraft-plan/SKILL.md`

- [ ] **Step 1: Update directory references**

Replace all references in kraft-plan:
- `[WORKSPACE]/tasks/TICKET-123/` → `[WORKSPACE]/trees/TICKET-123/`
- `[WORKSPACE]/sources/` → `[WORKSPACE]/modules/`
- `*/tasks/*` path checks → `*/trees/*`
- `/kraft-start` suggestions → `/kraft-work`

- [ ] **Step 2: Update ticket ID extraction**

The hardcoded `grep -oE '^[A-Z]+-[0-9]+'` assumes Jira-format IDs. Replace with a provider-aware pattern:

```sh
TICKET_PATTERN=$(<scripts-dir>/resolve-provider.sh fragment ticket-management ticket-id-pattern 2>/dev/null || echo "")
```

If the fragment is empty, fall back to extracting the directory basename as the ticket ID.

- [ ] **Step 3: Commit**

```bash
git add kraftwork/skills/kraft-plan/SKILL.md
git commit -m "fix: update kraft-plan for new workspace layout and provider delegation

- trees/ instead of tasks/ for worktrees
- modules/ instead of sources/ for repos
- Provider-aware ticket ID pattern extraction"
```

---

### Task 8: Update kraft-implement to Use New Layout

**Files:**
- Modify: `kraftwork/skills/kraft-implement/SKILL.md`

- [ ] **Step 1: Update directory references**

Replace:
- `*/tasks/*` → `*/trees/*`
- `sources/` references → `modules/`
- `/kraft-start` → `/kraft-work`
- `/kraft-init` → `/kraft-config`

- [ ] **Step 2: Commit**

```bash
git add kraftwork/skills/kraft-implement/SKILL.md
git commit -m "fix: update kraft-implement for new workspace layout

- trees/ instead of tasks/ for worktrees
- modules/ instead of sources/ for repos"
```

---

### Task 9: Update kraft-split to Use Provider Delegation

**Files:**
- Modify: `kraftwork/skills/kraft-split/SKILL.md`

- [ ] **Step 1: Replace glab references with provider delegation**

The key changes:
- Replace `glab mr create` (lines 246-257) with provider delegation:
  ```sh
  CREATE_PR=$(<scripts-dir>/resolve-provider.sh script git-hosting create-pr)
  "$CREATE_PR" "$MR1_BRANCH" "main" "$TICKET_ID <MR1 description>" "$BODY"
  ```
- Add a hard gate: if `resolve-provider.sh has git-hosting create-pr` exits 1, error with "kraft-split requires a git hosting provider with PR creation capability."
- Replace `glab mr list` with a search-prs call to get MR numbers after creation

- [ ] **Step 2: Update directory references**

- `*/tasks/*` → `*/trees/*`
- `$WORKSPACE/tasks/` → `$WORKSPACE/trees/`
- `/kraft-start` → `/kraft-work`
- Remove `pnpm` hardcoding from deployability checks — instead read build/test commands from `workspace.json` or `repo-setup.json`
- Description references: `glab mr create` → generic "create PR via provider"

- [ ] **Step 3: Add PR description fragment injection**

Where the skill constructs MR descriptions, inject the provider fragment:

```
{{git-hosting:pr-description-guide}}
```

- [ ] **Step 4: Commit**

```bash
git add kraftwork/skills/kraft-split/SKILL.md
git commit -m "fix: update kraft-split for provider delegation

- PR creation via git-hosting provider instead of glab
- trees/ instead of tasks/
- Fragment injection for PR description conventions
- Removed hardcoded pnpm commands"
```

---

### Task 10: Update kraft-retro to Use Provider Delegation

**Files:**
- Modify: `kraftwork/skills/kraft-retro/SKILL.md`

- [ ] **Step 1: Replace glab API calls with provider delegation**

The major coupling is in Steps 3-4 where `glab api` is called directly. Replace with:

```sh
FETCH_PR=$(<scripts-dir>/resolve-provider.sh script git-hosting fetch-pr-details 2>/dev/null || echo "")
if [ -n "$FETCH_PR" ]; then
  PR_DATA=$("$FETCH_PR" "$IID")
  MR_DETAILS=$(echo "$PR_DATA" | jq '.details')
  MR_DISCUSSIONS=$(echo "$PR_DATA" | jq '.discussions')
  MR_CHANGES=$(echo "$PR_DATA" | jq '.changes')
  MR_COMMITS=$(echo "$PR_DATA" | jq '.commits')
fi
```

Replace the PR search (Step 3) with:

```sh
SEARCH_PRS=$(<scripts-dir>/resolve-provider.sh script git-hosting search-prs 2>/dev/null || echo "")
if [ -n "$SEARCH_PRS" ]; then
  MRS=$("$SEARCH_PRS" "$TICKET_ID")
fi
```

If no git-hosting provider or search-prs unavailable, proceed with local artifacts only.

- [ ] **Step 2: Replace hardcoded ticket ID validation**

The `grep -qE '^[A-Z]+-[0-9]+$'` on line 39 assumes Jira format. Use provider fragment or accept any non-empty string.

- [ ] **Step 3: Update directory references**

- `$WORKSPACE/docs/specs/` stays (unchanged)
- `sources/` references → `modules/`
- `/kraft-init` → `/kraft-config`

- [ ] **Step 4: Commit**

```bash
git add kraftwork/skills/kraft-retro/SKILL.md
git commit -m "fix: update kraft-retro for provider delegation

- PR search and detail fetching via git-hosting provider
- Graceful degradation when no git hosting configured
- Provider-aware ticket ID format"
```

---

### Task 11: Update kraft-archive and kraft-import

**Files:**
- Modify: `kraftwork/skills/kraft-archive/SKILL.md`
- Modify: `kraftwork/skills/kraft-import/SKILL.md`

- [ ] **Step 1: Update kraft-archive**

- `$WORKSPACE/tasks` → `$WORKSPACE/trees`
- `*/tasks/*` path check → `*/trees/*`
- `/kraft-start` → `/kraft-work`
- `/kraft-init` → `/kraft-config`
- `safety-check.sh` has a `glab mr view` call (line 63) — this needs to delegate to the git-hosting provider. Either update safety-check.sh itself (Task 12) or note that the open MR check is provider-dependent.

- [ ] **Step 2: Update kraft-import**

Rewrite to match the new purpose: onboarding a new repo as a submodule with codebase analysis.

- Replace "Search GitLab MRs (fallback)" with provider delegation
- `$WORKSPACE/sources/` → `$WORKSPACE/modules/`
- `$WORKSPACE/tasks/` → `$WORKSPACE/trees/`
- `search-ticket-mrs.sh` → `resolve-provider.sh script git-hosting search-prs`
- `search-ticket-branches.sh` → `resolve-provider.sh script git-hosting search-branches`
- Add: after cloning, scan the repo for documentation (README, docs/, CLAUDE.md) and suggest additions to workspace CLAUDE.md/AGENTS.md
- Clone via: `resolve-provider.sh script git-hosting clone-repo` then `git submodule add`
- Remove "Jira ticket" language — use generic "ticket" or "identifier"

- [ ] **Step 3: Commit**

```bash
git add kraftwork/skills/kraft-archive/SKILL.md kraftwork/skills/kraft-import/SKILL.md
git commit -m "fix: update kraft-archive and kraft-import for new layout and providers

- trees/ instead of tasks/ for worktrees
- modules/ instead of sources/ for repos
- kraft-import now onboards repos as submodules with codebase scan
- Provider delegation for PR search and repo cloning"
```

---

### Task 12: Update Core Scripts for New Layout

**Files:**
- Modify: `kraftwork/scripts/find-workspace.sh`
- Modify: `kraftwork/scripts/safety-check.sh`
- Modify: `kraftwork/scripts/list-repos.sh`
- Modify: `kraftwork/scripts/worktree-status.sh`
- Modify: `kraftwork/scripts/list-worktrees.sh`
- Modify: `kraftwork/scripts/workspace-sync.sh`
- Delete: `kraftwork/scripts/search-ticket-mrs.sh`
- Delete: `kraftwork/scripts/search-ticket-branches.sh`

- [ ] **Step 1: Update find-workspace.sh**

Add `modules/` as a fallback alongside `sources/`:

```sh
#!/bin/sh
set -eu

START_DIR="${1:-$(pwd)}"

DIR="$START_DIR"
while [ "$DIR" != "/" ]; do
  if [ -f "$DIR/workspace.json" ]; then
    echo "$DIR"
    exit 0
  fi
  DIR=$(dirname "$DIR")
done

DIR="$START_DIR"
while [ "$DIR" != "/" ]; do
  if [ -d "$DIR/modules" ]; then
    echo "$DIR"
    exit 0
  fi
  DIR=$(dirname "$DIR")
done

DIR="$START_DIR"
while [ "$DIR" != "/" ]; do
  if [ -d "$DIR/sources" ]; then
    echo "$DIR"
    exit 0
  fi
  DIR=$(dirname "$DIR")
done

echo "Error: Workspace not found" >&2
echo "Searched from: $START_DIR" >&2
exit 1
```

- [ ] **Step 2: Update safety-check.sh**

Remove the hardcoded `glab mr view` block (lines 60-72). Replace with provider delegation:

```sh
HAS_OPEN_PR=0
PR_URL=""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SEARCH_PRS=$("$SCRIPT_DIR/resolve-provider.sh" script git-hosting search-prs 2>/dev/null || echo "")
if [ -n "$SEARCH_PRS" ]; then
  # Extract ticket ID from branch name for search
  TICKET_HINT=$(echo "$BRANCH" | grep -oE '^[A-Za-z]+-[0-9]+' || echo "$BRANCH")
  PR_RESULTS=$("$SEARCH_PRS" "$TICKET_HINT" 2>/dev/null || echo "[]")
  OPEN_PR=$(echo "$PR_RESULTS" | jq -r '[.[] | select(.state == "opened" and .branch == "'"$BRANCH"'")] | first // empty' 2>/dev/null || echo "")
  if [ -n "$OPEN_PR" ]; then
    HAS_OPEN_PR=1
    PR_URL=$(echo "$OPEN_PR" | jq -r '.url // empty')
  fi
fi
```

Update the JSON output to use `open_pr` instead of `open_mr`.

- [ ] **Step 3: Update list-repos.sh**

Replace `sources/` references with `modules/` (with fallback to `sources/` for backward compatibility):

```sh
MODULES_DIR="$WORKSPACE/modules"
if [ ! -d "$MODULES_DIR" ]; then
  MODULES_DIR="$WORKSPACE/sources"
fi
```

- [ ] **Step 4: Update worktree-status.sh, list-worktrees.sh**

Replace `tasks/` references with `trees/`:
- `$WORKSPACE/tasks` → `$WORKSPACE/trees`
- Add fallback check for `tasks/` for backward compatibility

- [ ] **Step 5: Update workspace-sync.sh**

Replace `$WORKSPACE/sources` with `$WORKSPACE/modules` (with fallback).

- [ ] **Step 6: Remove vendor-specific search scripts**

These are now in the GitLab extension:

```bash
rm kraftwork/scripts/search-ticket-mrs.sh
rm kraftwork/scripts/search-ticket-branches.sh
```

- [ ] **Step 7: Commit**

```bash
git add kraftwork/scripts/
git commit -m "fix: update core scripts for new layout and provider delegation

- find-workspace.sh: recognizes modules/ alongside sources/
- safety-check.sh: PR check via provider instead of glab
- list-repos.sh, workspace-sync.sh: modules/ with sources/ fallback
- worktree-status.sh, list-worktrees.sh: trees/ with tasks/ fallback
- Removed search-ticket-mrs.sh and search-ticket-branches.sh (now in extensions)"
```

---

### Task 13: Update kraft-sync for New Layout

**Files:**
- Modify: `kraftwork/skills/kraft-sync/SKILL.md`

- [ ] **Step 1: Update references**

- `sources/` → `modules/`
- The skill itself is thin (delegates to `workspace-sync.sh`), so this is mostly updating the description.

- [ ] **Step 2: Commit**

```bash
git add kraftwork/skills/kraft-sync/SKILL.md
git commit -m "fix: update kraft-sync for modules/ layout"
```

---

### Task 14: Update plugin.json Metadata

**Files:**
- Modify: `kraftwork/.claude-plugin/plugin.json`

- [ ] **Step 1: Bump version and update description**

```json
{
  "name": "kraftwork",
  "version": "3.0.0",
  "description": "Opinionated developer workflow orchestration with pluggable providers for git hosting, ticket management, and document storage",
  "author": {
    "name": "Filipe Estacio",
    "email": "f.estacio@gmail.com"
  }
}
```

- [ ] **Step 2: Bump extension versions**

Update `kraftwork-gitlab/.claude-plugin/plugin.json` and `kraftwork-jira/.claude-plugin/plugin.json` to `3.0.0`.

- [ ] **Step 3: Commit**

```bash
git add kraftwork/.claude-plugin/plugin.json kraftwork-gitlab/.claude-plugin/plugin.json kraftwork-jira/.claude-plugin/plugin.json
git commit -m "chore: bump to v3.0.0 for provider decoupling release"
```

---

### Task 15: Verify the Full System

- [ ] **Step 1: Verify kraftwork-local provider scripts are executable and have correct paths**

```bash
ls -la kraftwork/providers/local/scripts/
ls -la kraftwork/providers/local/fragments/
```

Expected: all .sh files have execute permission, all fragments exist.

- [ ] **Step 2: Verify resolve-provider.sh works with local provider**

Create a minimal test workspace.json:

```bash
mkdir -p /tmp/kraft-test
cat > /tmp/kraft-test/workspace.json << 'EOF'
{
  "workspace": {"name": "test", "path": "/tmp/kraft-test"},
  "providers": {
    "git-hosting": {"plugin": "kraftwork-local"},
    "ticket-management": {"plugin": "kraftwork-local"},
    "document-storage": {"plugin": "kraftwork-local"}
  }
}
EOF

cd /tmp/kraft-test
/path/to/kraftwork/scripts/resolve-provider.sh script git-hosting auth-check
# Expected: prints path to local auth-check.sh

/path/to/kraftwork/scripts/resolve-provider.sh has git-hosting create-pr
# Expected: exit 1 (not available in local provider)

/path/to/kraftwork/scripts/resolve-provider.sh fragment ticket-management ticket-id-pattern
# Expected: prints fragment content
```

- [ ] **Step 3: Verify no remaining vendor references in core skills**

```bash
grep -r "glab\|acli\|gitlab\|jira" kraftwork/skills/ --include="*.md" -l
```

Expected: no matches (all vendor references moved to extensions).

```bash
grep -r "glab\|acli" kraftwork/scripts/ --include="*.sh"
```

Expected: no matches (vendor-specific scripts removed from core).

- [ ] **Step 4: Verify directory references updated**

```bash
grep -r "sources/" kraftwork/skills/ --include="*.md" | grep -v "modules/"
grep -r "/tasks/" kraftwork/skills/ --include="*.md" | grep -v "/trees/"
```

Expected: no matches for old directory names without the new equivalents nearby (backward-compat fallbacks in scripts are acceptable).

- [ ] **Step 5: Verify all skills reference correct sibling skills**

```bash
grep -r "kraft-init\|kraft-start\|kraft-resume\|kraft-stack" kraftwork/skills/ --include="*.md"
```

Expected: no matches (all renamed to kraft-config, kraft-work).

- [ ] **Step 6: Clean up test workspace**

```bash
rm -rf /tmp/kraft-test
```

- [ ] **Step 7: Commit any fixes found during verification**

```bash
git add -A
git commit -m "fix: address issues found during verification"
```
