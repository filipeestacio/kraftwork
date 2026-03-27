# Extension Framework Design

A template extension and two concrete extensions (GitHub, ClickUp) to validate the provider system and make building new integrations fast.

## Template Extension

`kraftwork-template/` is a complete, copy-and-rename starting point for building new provider extensions.

### Structure

```
kraftwork-template/
  .claude-plugin/
    plugin.json
  config/
    workspace-config.json
  providers.json
  scripts/
    auth-check.sh
    search-prs.sh
    search-branches.sh
    clone-repo.sh
    create-pr.sh
    fetch-pr-details.sh
    ci-status.sh
    fetch-ticket.sh
    search-tickets.sh
    transition-ticket.sh
    write-doc.sh
    read-doc.sh
    list-docs.sh
  fragments/
    pr-description-guide.md
    branch-naming.md
    ticket-id-pattern.md
  CHECKLIST.md
```

### plugin.json

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

### providers.json

Declares all three categories. Delete the ones you don't need.

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

### Script Stubs

Each script stub includes:
- Usage header with argument documentation
- Argument parsing and validation
- JSON output scaffolding matching the provider contract
- Correct exit codes (0 success, 1 missing args/not found, 2 auth failure)
- A clear `# --- IMPLEMENT BELOW ---` marker where vendor logic goes

### Auth Patterns

`auth-check.sh` includes two patterns, clearly marked. Delete the one you don't need:

**CLI-based** (for providers that use a CLI tool like `gh`, `glab`):
```sh
if ! command -v TOOL >/dev/null 2>&1; then
  echo "TOOL not installed" >&2
  exit 1
fi
if ! TOOL auth status >/dev/null 2>&1; then
  echo "TOOL not authenticated" >&2
  exit 1
fi
exit 0
```

**API-based** (for providers that use REST APIs with tokens):
```sh
# Locate workspace.json
DIR="$(pwd)"
while [ "$DIR" != "/" ]; do
  [ -f "$DIR/workspace.json" ] && break
  DIR=$(dirname "$DIR")
done
WORKSPACE_JSON="$DIR/workspace.json"

TOKEN_ENV=$(jq -r '.providers."CATEGORY".config.apiTokenEnv' "$WORKSPACE_JSON")
TOKEN=$(eval echo "\$$TOKEN_ENV")
if [ -z "$TOKEN" ]; then
  echo "$TOKEN_ENV is not set" >&2
  exit 1
fi
exit 0
```

API-based auth checks verify the env var is set and non-empty. They do not ping the API — invalid tokens are caught on first real operation. This avoids eating rate limits.

### Convention: Secrets via Environment Variables

Extensions that require API tokens store the **env var name** in `workspace.json`, not the token itself. This keeps secrets out of the workspace git repo.

```json
{
  "key": "apiTokenEnv",
  "type": "string",
  "prompt": "What environment variable holds your API token?",
  "example": "CLICKUP_API_TOKEN",
  "required": true
}
```

Scripts read the token at runtime:
```sh
TOKEN_ENV=$(jq -r '.providers."<category>".config.apiTokenEnv' "$WORKSPACE_JSON")
TOKEN=$(eval echo "\$$TOKEN_ENV")
```

### workspace-config.json

Empty section with placeholder fields:

```json
{
  "section": "CHANGEME",
  "title": "CHANGEME Configuration",
  "description": "Settings for CHANGEME integration",
  "fields": []
}
```

### CHECKLIST.md

Step-by-step guide:

1. Copy `kraftwork-template/` to `kraftwork-<name>/`
2. Update `plugin.json` — name, description
3. Edit `providers.json` — delete categories you don't provide
4. Delete script stubs for removed categories
5. Delete fragment stubs for removed categories
6. Fill in `workspace-config.json` fields for your provider
7. Implement each script (replace the `# --- IMPLEMENT BELOW ---` sections)
8. Write fragment content
9. Test: `kraft-config` detects the new extension and offers it
10. Test: each script works via `resolve-provider.sh`

## kraftwork-github

Git-hosting provider via the `gh` CLI.

### providers.json

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

### workspace-config.json

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

### Script Implementations

| Script | Implementation |
|---|---|
| `auth-check` | `gh auth status` |
| `search-prs` | `gh api "search/issues?q=TICKET+type:pr+org:ORG"`, transform to standard JSON format |
| `search-branches` | Same git-based logic as GitLab extension — search `modules/` (fallback `sources/`) with `git fetch` + `git branch -a` |
| `clone-repo` | `gh repo clone ORG/REPO DEST` |
| `create-pr` | `git push -u origin BRANCH` then `gh pr create --base TARGET --head SOURCE --title TITLE --body BODY` |
| `fetch-pr-details` | `gh api "repos/OWNER/REPO/pulls/NUM"` + `/reviews` + `/comments` + `/files`, bundled as `{"details": ..., "discussions": ..., "changes": ..., "commits": ...}` |
| `ci-status` | `gh run list --branch BRANCH --json status,conclusion,name` |

### Fragments

**pr-description-guide.md:**
```
Include `Fixes <TICKET-ID>` in the PR description for auto-closing linked issues.
Use GitHub-flavored markdown. Check the Actions tab for CI status.
For stacked PRs, include `Stacked on #<parent-PR-number>` and note merge order.
```

**branch-naming.md:**
```
Branch naming convention: `<ticket-id>-<slug>` (e.g., `PROJ-123-add-login-endpoint`).
The ticket ID prefix enables automatic PR-to-issue linking.
```

## kraftwork-clickup

Ticket-management and document-storage provider via ClickUp REST API v2.

### providers.json

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

### workspace-config.json

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

### Auth Pattern

API-based — stores env var name in config, reads token at runtime. `auth-check.sh` verifies the env var is set and non-empty. Does not ping the ClickUp API.

### Script Implementations

**Ticket Management:**

| Script | Implementation |
|---|---|
| `fetch-ticket` | `curl -s -H "Authorization: $TOKEN" "https://api.clickup.com/api/v2/task/$TICKET_ID"`, extract id/name/status, output `{"id": "...", "summary": "...", "status": "..."}` |
| `search-tickets` | `curl -s -H "Authorization: $TOKEN" "https://api.clickup.com/api/v2/team/$TEAM_ID/task?query=$QUERY"`, output JSON array |
| `transition-ticket` | `curl -s -X PUT -H "Authorization: $TOKEN" -H "Content-Type: application/json" -d '{"status": "$STATUS"}' "https://api.clickup.com/api/v2/task/$TICKET_ID"` |

**Document Storage:**

| Script | Implementation |
|---|---|
| `write-doc` | ClickUp Docs API: create or update doc in the appropriate space |
| `read-doc` | `GET /doc/<doc_id>`, output content |
| `list-docs` | `GET /space/<space_id>/doc`, output list of doc paths/titles |

Document storage scripts read the `spaces` array from config to determine which space to target. For `list-docs`, if no prefix/space filter is provided, list across all configured spaces.

### Fragments

**ticket-id-pattern.md:**
```
ClickUp task IDs are alphanumeric strings (e.g., `abc123`).
If custom task IDs are enabled, they follow the workspace's configured pattern.
The regex pattern is: `[a-z0-9]+` (case-insensitive).
```

### Space Routing

The `spaces` config array maps space IDs to human-readable names and descriptions. Scripts read this from `workspace.json` at runtime. Skills that need to pick a space (e.g., document storage) read the spaces list and select based on context — the LLM uses the name and description to route appropriately.

## Delivery Order

1. **Template extension** — the scaffold
2. **kraftwork-github** — built from template, validates git-hosting provider contract
3. **kraftwork-clickup** — built from template, validates ticket-management + document-storage contracts
