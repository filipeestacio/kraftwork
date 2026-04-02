---
name: messaging-find
description: Search Slack conversations and messages by topic, keyword, or channel name
---

# Slack Search

Read `workspace.json` from the workspace root. Extract `slack.channels` for the channel directory. If the `slack` section is missing, tell the user to run `/kraft-config`.

Search Slack messages and channels using MCP tools.

## Input

Optional subcommand: `messages`, `channels`.

Examples: `/messaging-find deployment failed`, `/messaging-find channels frontend`, `/messaging-find messages "auth bug" in #dev`

**Default (no subcommand):** `messages`.

---

## Subcommand: messages

Search message content across accessible channels.

```
mcp__claude_ai_Slack__slack_search_public_and_private
  query: "[SEARCH_TERMS]"
```

If the user specifies a channel (e.g., "in #dev-updates"), append `in:#dev-updates` to the query string.

Present results grouped by channel:

```
Found N messages matching "[SEARCH_TERMS]":

### #dev-updates (3 matches)
- **@alice** (2026-03-28): "Deployment to prod failed — rollback initiated"
  → [thread: 5 replies]
- **@bob** (2026-03-27): "v2.3.1 deployed successfully"
- **@alice** (2026-03-25): "Hotfix deployment for auth timeout"

### #incidents (1 match)
- **@oncall** (2026-03-28): "P1: API latency spike after deploy"
  → [thread: 12 replies]
```

If a result has a thread, note the reply count. The user can then use `/messaging-describe` to read the full thread.

If no results:
```
No messages found matching "[SEARCH_TERMS]". Try broader terms or check channel access.
```

---

## Subcommand: channels

Search for channels by name or topic.

```
mcp__claude_ai_Slack__slack_search_channels
  query: "[SEARCH_TERMS]"
```

Present results as a list:

```
Channels matching "[SEARCH_TERMS]":

| Channel | Members | Purpose |
|---------|---------|---------|
| #frontend-dev | 12 | Frontend development discussion |
| #frontend-releases | 8 | Frontend release tracking |
```

If no results:
```
No channels found matching "[SEARCH_TERMS]".
```

---

## Error Handling

- **Auth failure**: Suggest checking the Slack MCP connection in Claude settings
- **No results**: Suggest broader search terms or different channels
- **Rate limiting**: Wait briefly and retry once
