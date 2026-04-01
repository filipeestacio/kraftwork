---
name: ticket-management-find
description: Use when searching for ClickUp tasks — finding your open tasks, browsing by list, filtering by status, or searching by name
---

# ClickUp Search

Let `SCRIPT_DIR` be `../../scripts` relative to this SKILL.md file.

Read `workspace.json` from the workspace root. Extract the `clickup` section. If the `clickup` section is missing, tell the user to run `/kraft-init`. If `clickup.spaces` is not populated, suggest running `/clickup-sync` to fetch workspace data.

## Input

Optional subcommand: `mine`, `list`, `status`, `query`.

Examples: `/clickup-search`, `/clickup-search list "Engineering"`, `/clickup-search status "In Progress"`, `/clickup-search query "billing alerts"`

**Default (no subcommand):** `mine`.

All subcommands accept `--all` to include completed/closed tasks (passes `--include-closed` to the script).

## Auth

Do NOT pre-check authentication. Run the intended operation. If the `token_env` environment variable is unset, report:

```
Set `<token_env>` with your ClickUp API token.
```

If the API returns 401, report:

```
ClickUp API returned unauthorized — check that `<token_env>` contains a valid token.
```

---

## Config Dependency

The `mine`, `list`, and `status` subcommands enumerate lists from `clickup.spaces`. Each space contains lists with `id` and `name` fields. If a user references a list not found in config, suggest running `/clickup-sync` to refresh the configuration.

---

## Subcommand: mine

My open tasks across all configured lists, grouped by status.

For each list in `clickup.spaces`, run:

```bash
bun run "$SCRIPT_DIR/clickup-api.ts" search-tasks --list <id> --assignee me [--include-closed]
```

Collect all results across lists. Deduplicate by task ID. Group by status and present as numbered markdown tables.

If no results:
```
No open tasks assigned to you across your configured lists.
```

---

## Subcommand: list &lt;name&gt;

Tasks in a named list from config, with optional `--status` filter.

Match the provided name (case-insensitive) against list names in `clickup.spaces`. If no match found:
```
List "<name>" not found in your config. Run `/clickup-sync` to refresh your workspace lists.
```

If matched, run:

```bash
bun run "$SCRIPT_DIR/clickup-api.ts" search-tasks --list <id> [--status <status>] [--include-closed]
```

If no status argument provided, return all tasks in the list.

---

## Subcommand: status &lt;status&gt;

My tasks in a given status across all configured lists.

For each list in `clickup.spaces`, run:

```bash
bun run "$SCRIPT_DIR/clickup-api.ts" search-tasks --list <id> --assignee me --status <status> [--include-closed]
```

Collect and deduplicate results across lists. Present grouped by list name.

If no status argument provided, ask:
```
Which status? (e.g., "To Do", "In Progress", "In Review", "Done", "Blocked")
```

---

## Subcommand: query &lt;text&gt;

Free-text search across the workspace.

```bash
bun run "$SCRIPT_DIR/clickup-api.ts" find-tasks --query <text> [--include-closed]
```

Present results as a numbered table. If no query text provided, ask the user for the search terms.

---

## Presentation

Number results sequentially. Group by status. Show custom task IDs, priority, and summary.

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

When `--all` is passed, omit the "Use --all to include completed." sentence and replace "open tasks" with "tasks (including completed)".

---

## Error Handling

- **Token not set / 401**: See Auth section above.
- **403 Forbidden**: "You don't have access to this list. Check workspace permissions."
- **404 Not Found**: "List ID not found in ClickUp. Run `/clickup-sync` to refresh your config."
- **429 Rate Limited**: Handled by the script automatically.
- **Empty results**: "No tasks found matching your filters." Suggest broadening the search or removing the `--status` filter.
