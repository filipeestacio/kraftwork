# kraftwork-clickup Design Spec

**Date:** 2026-03-25
**Status:** Draft

## Overview

A new kraftwork extension providing ClickUp task management and team communication, as an alternative to kraftwork-jira. Config-driven via `workspace.json` with a nested space/list hierarchy. Uses a single Bun helper script (`clickup-api.ts`) to centralize API concerns (auth, pagination, rate limiting, error handling), keeping skills focused on workflow logic.

## Directory Structure

```
kraftwork-clickup/
├── .claude-plugin/
│   └── plugin.json
├── config/
│   └── workspace-config.json
├── scripts/
│   └── clickup-api.ts
└── skills/
    ├── clickup-search/
    │   └── SKILL.md
    ├── clickup-ticket/
    │   └── SKILL.md
    ├── clickup-share/
    │   └── SKILL.md
    └── clickup-sync/
        └── SKILL.md
```

## Plugin Manifest

```json
{
  "name": "kraftwork-clickup",
  "version": "2.0.0",
  "description": "ClickUp task management and team communication for Kraftwork (requires kraftwork core)",
  "author": {
    "name": "Filipe Estacio",
    "email": "f.estacio@gmail.com"
  }
}
```

## Configuration

### workspace-config.json Schema

Defines the fields that `/kraft-init` prompts for:

```json
{
  "section": "clickup",
  "title": "ClickUp Configuration",
  "description": "ClickUp workspace, spaces, and list settings for task management",
  "fields": [
    {
      "key": "teamId",
      "type": "string",
      "prompt": "What is your ClickUp workspace/team ID?",
      "example": "9012143904",
      "required": true
    },
    {
      "key": "token_env",
      "type": "string",
      "prompt": "Environment variable name for your ClickUp API token",
      "default": "CLICKUP_TOKEN",
      "required": false
    },
    {
      "key": "defaultList",
      "type": "string",
      "prompt": "Default list ID for task creation",
      "example": "901216485743",
      "required": true
    },
    {
      "key": "chatChannelId",
      "type": "string",
      "prompt": "Chat channel ID for team notifications (leave blank to skip)",
      "required": false
    },
    {
      "key": "spaces",
      "type": "object",
      "prompt": "Run /clickup-sync to populate spaces and lists",
      "required": false
    }
  ]
}
```

### Populated Config Example

After running `/clickup-sync`, the `clickup` section in `workspace.json` looks like:

```json
{
  "clickup": {
    "teamId": "9012143904",
    "token_env": "CLICKUP_TOKEN",
    "defaultList": "901216485743",
    "chatChannelId": "6-901216558082-8",
    "spaces": {
      "engineering": {
        "id": "90126745151",
        "lists": {
          "admin-portal": "901216485740",
          "developer-portal": "901216485741",
          "ops-portal": "901216485742",
          "platform": "901216485743",
          "continuous-delivery": "901216605368"
        }
      },
      "product": {
        "id": "90126808861",
        "lists": {
          "initiatives": "901216605750"
        }
      }
    }
  }
}
```

Minimal config to get started: `teamId` + `defaultList` + a valid token env var. Spaces/lists build up via `/clickup-sync`.

## Helper Script: clickup-api.ts

Single Bun script centralizing all ClickUp API interactions. Each skill derives the script path relative to its own SKILL.md location — the script is always at `../../scripts/clickup-api.ts` relative to any `skills/<name>/SKILL.md`.

```bash
bun run "$SCRIPT_DIR/clickup-api.ts" <subcommand> [args]
```

### Subcommands

v2 API (task operations):

| Subcommand | Purpose | Key Args |
|------------|---------|----------|
| `get-task <id>` | Fetch a single task | — |
| `search-tasks` | List tasks in a specific list with filters | `--list <id>`, `--status <s>`, `--assignee me`, `--include-closed` |
| `find-tasks` | Free-text search across the workspace | `--query <q>`, `--include-closed` |
| `create-task` | Create a task in a list | `--list <id>`, `--name <n>`, `--description <d>`, `--status <s>`, `--priority <p>`, `--tags <t,...>` |
| `update-task <id>` | Update task fields | `--status <s>`, `--name <n>`, `--description <d>`, `--priority <p>` |
| `add-comment <id>` | Add comment to a task | `--body <text>` |
| `get-checklist <id>` | Get checklists for a task | — |
| `check-item` | Mark checklist item resolved | `<checklist_id> <item_id>` |
| `list-spaces` | Fetch all spaces in workspace | — |
| `list-folders` | Fetch folders in a space | `--space <id>` |
| `list-lists` | Fetch lists in a folder | `--folder <id>` |
| `list-folderless-lists` | Fetch lists directly under a space (not in any folder) | `--space <id>` |
| `list-statuses` | Fetch available statuses for a list | `--list <id>` |

v3 API (chat):

| Subcommand | Purpose | Key Args |
|------------|---------|----------|
| `send-chat` | Post to Chat channel | `--channel <id>`, `--body <text>` |

### API Endpoint Mapping

- `search-tasks` → `GET /list/{list_id}/task` — filtered task list within a specific list. Supports status, assignee, and `include_closed` filters.
- `find-tasks` → `GET /team/{team_id}/task` — free-text name search across the workspace. Supports `name` parameter and `include_closed`.
- `list-folderless-lists` → `GET /space/{space_id}/list` — lists sitting directly under a space, not inside any folder.
- `list-statuses` → derived from `GET /list/{list_id}` response, which includes the `statuses` array for that list.
- `send-chat` → `POST /api/v3/workspaces/{team_id}/chat/channels/{channel_id}/messages`.

### Shared Concerns

- **Auth:** Reads token from env var named in config (`token_env`, defaults to `CLICKUP_TOKEN`). Validates token is set before any request. On missing token or 401 response, reports: "Set the `<token_env>` environment variable with your ClickUp API token."
- **Base URL:** `https://api.clickup.com/api/v2` for task operations, `https://api.clickup.com/api/v3` for chat endpoints.
- **Custom task IDs:** When a task ID matches `[A-Z]+-[0-9]+`, automatically appends `?custom_task_ids=true&team_id=<teamId>` to the request URL.
- **Pagination:** Handles `page` parameter for list endpoints, fetches all pages by default.
- **Rate limiting:** Checks `X-RateLimit-Remaining` header, waits on `429` using `X-RateLimit-Reset`. ClickUp Business plan allows 100 req/min.
- **Error formatting:** Consistent JSON output: `{ "ok": true, "data": ... }` on success, `{ "ok": false, "error": "..." }` on failure.
- **Config reading:** Reads `workspace.json` from the workspace root, found by walking up from CWD or using `$KRAFTWORK_WORKSPACE` env var.

### Output Shapes

| Subcommand | `data` shape |
|------------|-------------|
| `get-task` | Single task object (raw ClickUp response) |
| `search-tasks`, `find-tasks` | `{ "tasks": [...] }` — array of task objects |
| `create-task` | Single task object (the created task) |
| `update-task` | Single task object (the updated task) |
| `add-comment` | Comment object |
| `get-checklist` | `{ "checklists": [...] }` — array with items nested |
| `check-item` | Updated checklist item object |
| `list-spaces` | `{ "spaces": [...] }` |
| `list-folders` | `{ "folders": [...] }` |
| `list-lists`, `list-folderless-lists` | `{ "lists": [...] }` |
| `list-statuses` | `{ "statuses": [...] }` — array of `{ "status": "name", "type": "open\|closed", "color": "..." }` |
| `send-chat` | Message object |

### Closed Tasks

The ClickUp API excludes tasks with closed statuses (e.g., `complete`) by default. The `search-tasks` subcommand accepts `--include-closed` which passes `include_closed=true` to the API. Skills that need visibility into completed work must use this flag explicitly.

## Skills

Each skill reads config from `workspace.json` at the workspace root. Extract the `clickup` section. If it is missing, tell the user to run `/kraft-init`. If specific fields are missing (e.g., `spaces` not populated), suggest `/clickup-sync`.

Each skill derives the helper script path relative to its own SKILL.md: `SCRIPT_DIR` is `../../scripts` from any `skills/<name>/SKILL.md`.

### Auth (all skills)

Do not pre-check authentication. Run the intended operation. If the token env var is unset, report: "Set `<token_env>` with your ClickUp API token." If the API returns 401, report: "ClickUp API returned unauthorized — check that `<token_env>` contains a valid token."

### /clickup-search

```yaml
---
name: clickup-search
description: Use when searching for ClickUp tasks — finding your open tasks, browsing by list, filtering by status, or searching by name
---
```

**Subcommands:**

| Subcommand | Default | Behavior | Script call |
|------------|---------|----------|-------------|
| `mine` | Yes | My open tasks across all configured lists, grouped by status | `search-tasks --list <id> --assignee me` per list |
| `list <name>` | — | Tasks in a named list from config, optional `--status` filter | `search-tasks --list <id> [--status <s>]` |
| `status <status>` | — | My tasks in a given status across all configured lists | `search-tasks --list <id> --assignee me --status <s>` per list |
| `query <text>` | — | Free-text search across the workspace | `find-tasks --query <q>` |

All subcommands accept `--all` to include completed/closed tasks (passes `--include-closed` to the script).

**Config dependency:** Reads `clickup.spaces` to enumerate lists for `mine`, `list`, and `status` subcommands. If the user references a list not in config, suggests running `/clickup-sync`.

**Presentation:** Numbered results with custom task IDs, grouped by status. Footer line when closed tasks are excluded.

**Output format:**

```
### In Progress (2)
| # | Task | Priority | Summary |
|---|------|----------|---------|
| 1 | ENG-42 | High | Fix login bug |
| 2 | ENG-57 | Medium | Add billing alerts |

### To Do (1)
| # | Task | Priority | Summary |
|---|------|----------|---------|
| 3 | ENG-73 | High | Migrate Partner records |

3 open tasks. Showing open tasks only. Use --all to include completed.
```

**Error handling:**
- **Token not set / 401:** See Auth section above.
- **403 Forbidden:** "You don't have access to this list. Check workspace permissions."
- **404 list not found:** "List ID not found in ClickUp. Run `/clickup-sync` to refresh your config."
- **429 rate limited:** Handled by the script automatically (waits and retries).
- **Empty results:** "No tasks found matching your filters." Suggest broadening the search.

### /clickup-ticket

```yaml
---
name: clickup-ticket
description: Use when working with a specific ClickUp task — viewing details, creating new tasks, updating fields, transitioning status, adding comments, or managing checklists
---
```

**Subcommands:**

| Subcommand | Behavior |
|------------|----------|
| `view` (default when ID given) | Show task details: summary, status, priority, assignee, description, checklist items, last 3 comments |
| `create` | Gather name, description, priority, list. Present lists by config name. Falls back to `defaultList`. |
| `update` | Show current state, ask what to change, apply updates |
| `transition` | Fetch available statuses via `list-statuses --list <list_id>` (list ID from the task), present options, let user pick, apply via `update-task` |
| `comment` | Add a comment to the task |
| `checklist` | View checklist items, tick them off interactively |

**Task creation flow:**

1. Ask for task name (required)
2. Ask for list — present named lists from config, default to `defaultList`
3. Ask for description, priority, tags (optional)
4. Create via `clickup-api.ts create-task`
5. Confirm with task ID and URL

**Transition flow:**

1. Fetch the task via `get-task` to determine its current list and status.
2. Fetch available statuses for that list via `list-statuses --list <list_id>`.
3. Present statuses to user (excluding current), indicating which are open vs closed.
4. User picks a status. Apply via `update-task <id> --status <s>`.
5. Confirm the new status.

**Custom task ID handling:** When the user provides an ID like `ENG-42`, the script automatically handles the `custom_task_ids` parameter. If the user provides a raw ClickUp ID, it's used directly.

**Error handling:**
- **Token not set / 401:** See Auth section above.
- **404 task not found:** "Task not found. Check the ID — use the custom task ID (e.g., ENG-42) or the raw ClickUp ID."
- **Invalid status on transition:** "Status `<s>` is not available for this list. Available: ..." (re-present options).
- **Missing required field on create:** Report which field is missing.
- **Empty checklist:** "This task has no checklists."

### /clickup-share

```yaml
---
name: clickup-share
description: Use when posting status updates, progress notes, or messages to the ClickUp Chat channel and optionally to task comments
---
```

**Behavior:**

1. Reads `chatChannelId` from config. If not configured, tells user to add it via `/kraft-init` or set it in `workspace.json`.
2. Asks user for the message content.
3. Detects if on a task branch (ticket ID pattern in branch name). If so, offers to also post as a task comment.
4. Posts to Chat via `clickup-api.ts send-chat` (v3 API).
5. Optionally posts to task via `clickup-api.ts add-comment`.
6. Confirms what was posted and where.

**Message prefixes:**
- `[Update]` — General progress updates
- `[Blocker]` — Blocking issues
- `[Done]` — Completed work

Format: `[Prefix] TASK-ID: Message text`

**Rules:**
- Never posts without explicit user intent.
- Always confirms what was posted and where.
- If Chat API fails, falls back to task comment only (if applicable).

**Error handling:**
- **Token not set / 401:** See Auth section above.
- **chatChannelId not configured:** "No chat channel configured. Add `chatChannelId` to the clickup section of workspace.json or run `/kraft-init`."
- **Chat API failure (non-auth):** Report the error, fall back to task comment if a task ID is available.
- **Message too long:** ClickUp Chat has a character limit. If the message exceeds it, truncate with a note or suggest shortening.

### /clickup-sync

```yaml
---
name: clickup-sync
description: Use when syncing ClickUp workspace hierarchy (spaces, folders, lists) into workspace.json, or when config is stale or missing spaces/lists
---
```

**Flow:**

1. Fetch all spaces via `clickup-api.ts list-spaces`.
2. Present spaces to user with current config state (new/existing/removed).
3. User selects which spaces to include.
4. For each selected space:
   - Fetch folders via `clickup-api.ts list-folders --space <id>`.
   - For each folder, fetch lists via `clickup-api.ts list-lists --folder <id>`.
   - Fetch folderless lists via `clickup-api.ts list-folderless-lists --space <id>`.
5. Present the full tree with selection state.
6. User confirms or deselects individual lists.
7. Show diff against current config:
   - New spaces/lists being added
   - Existing spaces/lists unchanged
   - Spaces/lists in config but no longer in ClickUp (suggest removal)
8. User confirms. Write updated `clickup` section to `workspace.json`.

**Edge cases:**
- If `defaultList` no longer exists in ClickUp, warn and ask user to pick a new default.
- Slugifies space and list names for config keys (e.g., "Admin Portal" becomes "admin-portal").
- Preserves `teamId`, `token_env`, and `chatChannelId` — only touches `spaces` and validates `defaultList`.
- Folderless lists (lists directly under a space, not in any folder) are included alongside folder-based lists.

**Error handling:**
- **Token not set / 401:** See Auth section above.
- **Empty workspace:** "No spaces found in this workspace. Check that `teamId` is correct."
- **API errors during folder/list fetch:** Report the error for the specific space, continue with remaining spaces.

## Integration with Core

kraftwork-clickup integrates with the core the same way kraftwork-jira does:

- **kraft-start** uses the ticket ID pattern `[A-Z]+-[0-9]+` which works with ClickUp custom task IDs (e.g., `ENG-42`).
- **kraft-plan** extracts ticket ID from worktree directory name — no change needed.
- **workspace.json** gets the `clickup` section added during `/kraft-init`, which reads `workspace-config.json` from this plugin.

No core changes are required.

## Design Decisions

1. **Helper script over raw curl** — Centralizes auth, pagination, rate limiting, and error handling in one place. Skills stay focused on workflow. More maintainable as the API surface grows.
2. **Nested space/list config** — Reflects ClickUp's actual hierarchy. Lists belong to spaces, not floating free.
3. **Interactive sync** — ClickUp workspaces can be large. Users curate which spaces/lists they care about rather than dumping everything.
4. **Closed tasks excluded by default** — Matches ClickUp API behavior. `--include-closed` / `--all` flag for when visibility into completed work is needed.
5. **Config-driven, not hardcoded** — All workspace-specific values (team ID, list IDs, channel IDs) live in `workspace.json` so the extension works for any ClickUp workspace.
6. **Graceful degradation on missing config** — Skills that hit a missing list/space suggest `/clickup-sync` rather than failing.
7. **Coexists with kraftwork-jira** — Both plugins write to separate config sections (`clickup` vs `jira`) and can be installed in the same workspace without conflict.
