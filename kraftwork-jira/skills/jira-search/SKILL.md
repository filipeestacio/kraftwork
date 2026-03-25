---
name: jira-search
description: Use when searching for Jira tickets — finding your open tickets, browsing the current sprint, filtering by status, viewing the kanban board for top priorities, or running custom JQL queries
---

# Jira Search

Read `workspace.json` from the workspace root. Extract `jira.project` and `jira.cloudId`. If the `jira` section is missing, tell the user to run `/kraft-init`.

Find and browse Jira tickets via `acli jira` CLI.

## Input

Optional subcommand: `mine`, `sprint`, `status`, `board`, `jql`.

Examples: `/jira-search`, `/jira-search sprint`, `/jira-search status "In Review"`, `/jira-search board`, `/jira-search jql "project = [jira.project] AND type = Bug"`

**Default (no subcommand):** `mine`.

## Auth

Do NOT gate on `acli auth status` — it returns false negatives. Instead, run the actual query. If it fails with an auth/unauthorized error, then suggest `acli auth login`.

---

## Subcommand: mine

My open tickets, sorted by priority.

```bash
acli jira workitem search --jql "project = [jira.project] AND assignee = currentUser() AND status != Done ORDER BY priority ASC, updated DESC" --fields "key,issuetype,priority,status,summary" --paginate
```

Group results by status and present as markdown tables. Use this order: In Code Review, Ready For Production, In Progress, To Do. Omit empty groups.

```
### In Code Review (1)
| Key | Summary |
|-----|---------|
| PROJ-1236 | Fix null pointer in handler |

### In Progress (1)
| Key | Summary |
|-----|---------|
| PROJ-1234 | Add user preferences modal |

### To Do (1)
| Key | Summary |
|-----|---------|
| PROJ-1235 | Update API documentation |

X total tickets.
```

If no results:
```
No open tickets assigned to you in [jira.project].
```

---

## Subcommand: sprint

All tickets in the current active sprint.

### Phase 1: Find Board and Active Sprint

Find the board:
```bash
acli jira board search --project "[jira.project]" --json
```

Extract the board ID. Then find the active sprint:
```bash
acli jira board list-sprints [BOARD_ID] --json
```

Parse to find the sprint with `state: "active"`. Store sprint ID.

### Phase 2: List Sprint Tickets

```bash
acli jira sprint list-workitems --board [BOARD_ID] --sprint [SPRINT_ID] --fields "key,issuetype,assignee,priority,status,summary" --paginate
```

Present as a table grouped by status:
```
Sprint: Sprint 42 (Jan 15 - Jan 29)

To Do:
  PROJ-1240   Task    @unassigned   Medium   Set up monitoring alerts

In Progress:
  PROJ-1234   Story   @filipe       High     Add user preferences modal

In Review:
  PROJ-1236   Bug     @filipe       Low      Fix null pointer in handler

Done:
  PROJ-1238   Task    @colleague    Medium   Update CI config
```

---

## Subcommand: status

Tickets in a given status. Defaults to current user's tickets only.

**My tickets in status (default):**
```bash
acli jira workitem search --jql "project = [jira.project] AND assignee = currentUser() AND status = '[STATUS]' ORDER BY priority ASC, updated DESC" --fields "key,issuetype,priority,summary" --paginate
```

**All team tickets in status** (use when user says "all", "team", or "everyone's"):
```bash
acli jira workitem search --jql "project = [jira.project] AND status = '[STATUS]' ORDER BY priority ASC, updated DESC" --fields "key,issuetype,assignee,priority,summary" --paginate
```

If no status argument provided, ask:
```
Which status? (e.g., "To Do", "In Progress", "In Review", "Done", "Blocked")
```

Present as a table.

---

## Subcommand: board

Kanban view — top priority tickets grouped by status, highlighting what to pick up next.

### Phase 1: Fetch Open Tickets

```bash
acli jira workitem search --jql "project = [jira.project] AND status != Done AND sprint in openSprints() ORDER BY priority ASC, rank ASC" --fields "key,issuetype,assignee,priority,status,summary" --paginate --json
```

If no active sprint or `openSprints()` fails, fall back to:
```bash
acli jira workitem search --jql "project = [jira.project] AND status != Done ORDER BY priority ASC, rank ASC" --fields "key,issuetype,assignee,priority,status,summary" --limit 50 --json
```

### Phase 2: Group and Present

Group tickets by status column. Within each column, tickets are already sorted by priority and rank.

```
Kanban Board — [jira.project]
══════════════════

To Do (3):
  1. PROJ-1240  [High]    Set up monitoring alerts        @unassigned
  2. PROJ-1241  [Medium]  Refactor auth middleware         @unassigned
  3. PROJ-1245  [Low]     Update README                   @unassigned

In Progress (2):
  1. PROJ-1234  [High]    Add user preferences modal      @filipe
  2. PROJ-1237  [Medium]  Migrate legacy endpoint          @colleague

In Review (1):
  1. PROJ-1236  [Low]     Fix null pointer in handler     @filipe

Blocked (1):
  1. PROJ-1239  [High]    Integrate new payment provider  @colleague

Top priorities to pick up:
  → PROJ-1240  [High]  Set up monitoring alerts  (unassigned, To Do)
  → PROJ-1241  [Medium]  Refactor auth middleware  (unassigned, To Do)
```

The "Top priorities to pick up" section shows the highest-priority unassigned tickets in To Do.

---

## Subcommand: jql

Raw JQL query for anything not covered by the shortcuts.

```bash
acli jira workitem search --jql "[USER_QUERY]" --fields "key,issuetype,assignee,priority,status,summary" --paginate
```

If no query provided, ask the user for the JQL string.

Present results as a table.

---

## Error Handling

- **Invalid JQL**: Report the error message from `acli` and suggest correcting syntax
- **No board found**: Suggest checking project key
- **No active sprint**: Fall back to all open tickets
- **Empty results**: Confirm the query and suggest broadening filters
