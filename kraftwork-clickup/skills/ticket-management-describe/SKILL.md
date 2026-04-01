---
name: ticket-management-describe
description: Use when working with a specific ClickUp task — viewing details, creating new tasks, updating fields, transitioning status, adding comments, or managing checklists
---

# ClickUp Ticket Management

```
SCRIPT_DIR="../../scripts"  # relative to this SKILL.md file
```

Read `workspace.json` from the workspace root. Extract the `clickup` section. If the `clickup` section is missing, tell the user to run `/kraft-init`.

Single-task operations via the ClickUp API scripts.

## Input

Optional subcommand and task ID: `view`, `create`, `update`, `transition`, `comment`, `checklist`.

Examples: `/clickup-ticket ENG-42`, `/clickup-ticket create`, `/clickup-ticket transition ENG-42`

**Default (task ID given, no subcommand):** `view`.

## Auth

Do NOT pre-check authentication. Run the intended operation directly. If the token env var is unset, report:

> Set `<token_env>` with your ClickUp API token.

If the API returns 401, report:

> ClickUp API returned unauthorized — check that `<token_env>` contains a valid token.

---

## Subcommand: view

```bash
bun run "$SCRIPT_DIR/clickup-api.ts" get-task <id>
```

Present:
- **Task ID** and **Name**
- **Status** and **Priority**
- **Assignee**
- **Description** (truncated if very long)
- **Checklist items** (with resolved/unresolved state)
- **Comments** (last 3, with author and date)

### Custom Task ID Handling

When the user provides an ID like `ENG-42`, the script automatically handles the `custom_task_ids` parameter. Raw ClickUp IDs (e.g., `abc123`) also work directly.

---

## Subcommand: create

### Phase 1: Gather Details

Ask the user for:
- **Task name**: required
- **List**: present named lists from `clickup.spaces` config; default to `clickup.defaultList`
- **Description**: optional
- **Priority**: optional (1 = Urgent, 2 = High, 3 = Normal, 4 = Low)
- **Tags**: optional

### Phase 2: Create

```bash
bun run "$SCRIPT_DIR/clickup-api.ts" create-task \
  --list <list_id> \
  --name <name> \
  [--description <description>] \
  [--priority <priority>] \
  [--tags <tags>]
```

### Phase 3: Confirm

Report: task ID, URL, and task name.

---

## Subcommand: update

### Phase 1: Show Current State

```bash
bun run "$SCRIPT_DIR/clickup-api.ts" get-task <id>
```

Present the current values for name, description, priority, and status. Ask the user what they want to change.

### Phase 2: Apply Changes

```bash
bun run "$SCRIPT_DIR/clickup-api.ts" update-task <id> \
  [--name <name>] \
  [--description <description>] \
  [--priority <priority>]
```

### Phase 3: Confirm

Report the updated fields.

---

## Subcommand: transition

### Phase 1: Fetch Task and Available Statuses

First, fetch the task to determine its current list and status:
```bash
bun run "$SCRIPT_DIR/clickup-api.ts" get-task <id>
```

Then fetch available statuses for that list (using `list.id` from the task response):
```bash
bun run "$SCRIPT_DIR/clickup-api.ts" list-statuses --list <list_id>
```

### Phase 2: Present Options

Present all statuses except the current one, indicating which are open vs closed:

```
ENG-42 is currently: In Progress

Available statuses:
  1. To Do  [open]
  2. In Review  [open]
  3. Done  [closed]

Which status?
```

### Phase 3: Execute Transition

```bash
bun run "$SCRIPT_DIR/clickup-api.ts" update-task <id> --status <status>
```

### Phase 4: Confirm

Report the new status.

---

## Subcommand: comment

### Phase 1: Get Comment Text

Ask the user for the comment text.

### Phase 2: Post Comment

```bash
bun run "$SCRIPT_DIR/clickup-api.ts" add-comment <id> --body <text>
```

### Phase 3: Confirm

Report that the comment was added.

---

## Subcommand: checklist

### Phase 1: Fetch Checklist

```bash
bun run "$SCRIPT_DIR/clickup-api.ts" get-checklist <id>
```

### Phase 2: Present Items

Show checklist items with their resolved/unresolved state:

```
Checklist: "Definition of Done"
  [x] Write unit tests
  [ ] Update documentation
  [ ] Reviewed by peer
```

### Phase 3: Select Items to Tick Off

Ask the user which items to mark as complete.

### Phase 4: Update Items

For each selected item:
```bash
bun run "$SCRIPT_DIR/clickup-api.ts" check-item <checklist_id> <item_id>
```

### Phase 5: Confirm

Report which items were checked off.

---

## Error Handling

- **Token not set / 401**: See Auth section above.
- **404 task not found**: "Task not found. Check the ID — use the custom task ID (e.g., ENG-42) or the raw ClickUp ID."
- **Invalid status on transition**: "Status `<s>` is not available for this list. Available: ..." then re-present the status options.
- **Missing required field on create**: Report which field is missing and prompt again.
- **Empty checklist**: "This task has no checklists."
