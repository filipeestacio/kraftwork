---
name: jira-ticket
description: Use when working with a specific Jira ticket — viewing details, transitioning status, adding comments, editing fields, or creating new tickets
---

# Jira Ticket Management

Read `workspace.json` from the workspace root. Extract `jira.project` and `jira.cloudId`. If the `jira` section is missing, tell the user to run `/kraft-init`.

Single-ticket operations via `acli jira` CLI.

## Input

Optional subcommand and ticket ID: `view`, `transition`, `comment`, `edit`, `create`.

Examples: `/jira-ticket PROJ-1234`, `/jira-ticket transition PROJ-1234`, `/jira-ticket create`

**Default (ticket ID given, no subcommand):** `view`.

## Auth

Do NOT gate on `acli auth status` — it returns false negatives. Instead, run the actual command. If it fails with an auth/unauthorized error, then suggest `acli auth login`.

---

## Subcommand: view

```bash
acli jira workitem view [TICKET] --fields "*all"
```

Present:
- **Key** and **Type** (Story, Bug, Task, etc.)
- **Summary**
- **Status** and **Priority**
- **Assignee**
- **Labels** and **Story Points** (if set)
- **Description** (truncated if very long)
- **Comments** (last 3, with author and date)

For just the raw JSON (useful for scripting):
```bash
acli jira workitem view [TICKET] --json
```

---

## Subcommand: transition

### Phase 1: Discover Available Transitions

Always use the Atlassian MCP tool to get real transitions — do NOT guess:
```
mcp__atlassian__getTransitionsForJiraIssue
  cloudId: [jira.cloudId from workspace.json]
  issueIdOrKey: "[TICKET]"
```

Present what's actually available:
```
[TICKET] is currently: In Progress

Available transitions:
  1. Code Review → In Code Review
  2. To Do

Which transition?
```

Note: if the desired status isn't directly reachable, you may need to step through intermediate states. Discover transitions at each step.

### Phase 2: Execute Transition

**Try `acli` first** (simpler, works for transitions without required fields):
```bash
acli jira workitem transition --key "[TICKET]" --status "[STATUS]" --yes
```

**If `acli` fails with a required fields error**, fall back to the Atlassian MCP tool which can pass fields:
```
mcp__atlassian__transitionJiraIssue
  cloudId: [jira.cloudId from workspace.json]
  issueIdOrKey: "[TICKET]"
  transition: {"id": "[TRANSITION_ID]"}
  fields: {"resolution": {"name": "..."}, ...}
```

Transitions with `hasScreen: true` (visible in Phase 1 response) typically require fields like Story Points, Epic Link, or Resolution. The `acli` CLI cannot pass these — the MCP fallback is required.

### Phase 3: Confirm

```bash
acli jira workitem view [TICKET] --fields "status"
```

Report new status.

---

## Subcommand: comment

### Phase 1: Get Comment Text

Ask the user for the comment text. For long comments, write to a temp file.

### Phase 2: Add Comment

For short comments:
```bash
acli jira workitem comment create --key "[TICKET]" --body "[COMMENT]"
```

For long comments:
```bash
echo "[COMMENT]" > /tmp/jira-comment.txt
acli jira workitem comment create --key "[TICKET]" --body-file /tmp/jira-comment.txt
```

### Phase 3: Confirm

Report that the comment was added.

---

## Subcommand: edit

### Phase 1: Show Current State

```bash
acli jira workitem view [TICKET] --fields "summary,assignee,priority,labels,status" --json
```

Present current values. Ask the user what they want to change.

### Phase 2: Apply Changes

Build the edit command with the requested changes:

```bash
acli jira workitem edit --key "[TICKET]" --summary "[NEW_SUMMARY]"
acli jira workitem edit --key "[TICKET]" --assignee "[EMAIL]"
acli jira workitem edit --key "[TICKET]" --labels "[LABEL1,LABEL2]"
acli jira workitem edit --key "[TICKET]" --type "[NEW_TYPE]"
```

For self-assignment:
```bash
acli jira workitem edit --key "[TICKET]" --assignee "@me"
```

Multiple fields can be combined in one command:
```bash
acli jira workitem edit --key "[TICKET]" --summary "[SUMMARY]" --assignee "@me" --labels "[LABELS]"
```

### Phase 3: Confirm

```bash
acli jira workitem view [TICKET] --fields "summary,assignee,priority,labels"
```

Report updated fields.

---

## Subcommand: create

### Phase 1: Gather Details

Prompt the user for:
- **Type**: Story, Bug, Task, Sub-task (default: Task)
- **Summary**: required
- **Parent Epic**: required for all non-Epic types (ask if not provided)
- **Description**: optional
- **Priority**: optional
- **Assignee**: optional (use `@me` for self-assignment)
- **Labels**: optional

**Parent Epic rule:** Every ticket must have a parent epic unless the type is explicitly Epic. If the user doesn't provide one, search for relevant epics and suggest matches before asking. Epics themselves are typically created by someone else or via the Jira UI — if the user asks to create an Epic, confirm that's what they intend.

To find relevant epics, search using keywords from the ticket summary:
```bash
acli jira workitem search --jql "project = [jira.project] AND type = Epic AND status != Done AND summary ~ '[KEYWORD]' ORDER BY updated DESC" --fields "key,summary,status" --limit 10
```

If no keyword match, fall back to recently active epics:
```bash
acli jira workitem search --jql "project = [jira.project] AND type = Epic AND status != Done ORDER BY updated DESC" --fields "key,summary,status" --limit 10
```

Present matches and let the user pick:
```
This ticket needs a parent epic. Here are some that might fit:
  1. [PROJECT]-3700  Messaging AI Agent Builder
  2. [PROJECT]-3600  Dashboard V4 Integration
  3. [PROJECT]-3500  Admin Portal

Which epic? (number, key, or describe what you're looking for)
```

### Phase 2: Create

```bash
acli jira workitem create --project "[jira.project]" --type "[TYPE]" --summary "[SUMMARY]" --parent "[EPIC_KEY]" --description "[DESCRIPTION]"
```

Add optional flags as provided:
```bash
--assignee "[EMAIL]" --label "[LABELS]"
```

For long descriptions:
```bash
echo "[DESCRIPTION]" > /tmp/jira-description.txt
acli jira workitem create --project "[jira.project]" --type "[TYPE]" --summary "[SUMMARY]" --parent "[EPIC_KEY]" --description-file /tmp/jira-description.txt
```

### Phase 3: Confirm

Report: ticket key, URL, summary, type, parent epic.

---

## Error Handling

- **Ticket not found**: Check the key format ([PROJECT]-XXXX)
- **Invalid transition**: List available transitions and ask user to pick again
- **Permission denied**: Check project access
- **Invalid field value**: Report which field and accepted values
