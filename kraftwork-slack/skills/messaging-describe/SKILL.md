---
name: messaging-describe
description: Read Slack channel messages, threads, or user profiles in detail
---

# Slack Describe

Read `workspace.json` from the workspace root. Extract `slack.channels` for the channel directory. If the `slack` section is missing, tell the user to run `/kraft-config`.

Read detailed Slack content using MCP tools.

## Input

Optional subcommand: `channel`, `thread`, `user`.

Examples: `/messaging-describe #dev-updates`, `/messaging-describe thread <thread-url>`, `/messaging-describe user @alice`

**Default:** Infer from argument — channel name → `channel`, URL or thread reference → `thread`, user mention → `user`.

---

## Subcommand: channel

Read recent messages from a channel.

```
mcp__claude_ai_Slack__slack_read_channel
  channel_name: "[CHANNEL_NAME]"
```

Present as a chronological conversation:

```
#dev-updates — recent messages:

**@alice** (2026-03-28, 10:15):
Deployment to prod failed — rollback initiated

  → 5 replies (use `/messaging-describe thread` to expand)

**@bob** (2026-03-28, 09:30):
PR #456 merged — staging looks good

**@alice** (2026-03-27, 16:45):
v2.3.1 deployed successfully
```

If the channel directory in `workspace.json` has a matching entry, include its purpose at the top:

```
#dev-updates — Deployment and CI notifications
```

---

## Subcommand: thread

Read a complete thread with all replies.

```
mcp__claude_ai_Slack__slack_read_thread
  channel_name: "[CHANNEL_NAME]"
  thread_ts: "[THREAD_TIMESTAMP]"
```

The user may provide a Slack URL, a channel + timestamp, or a reference from a previous search. Extract the channel and thread timestamp from whatever format is given.

Present as a threaded conversation:

```
Thread in #dev-updates:

**@alice** (2026-03-28, 10:15):
Deployment to prod failed — rollback initiated

  **@bob** (10:18): Which service? I see the API pod restarting
  **@alice** (10:20): auth-service — the new token validation is timing out
  **@carol** (10:25): I see the same in Grafana — latency spiked at 10:12
  **@alice** (10:40): Rolled back to v2.3.0, latency back to normal
  **@bob** (10:42): Confirmed — all green now
```

---

## Subcommand: user

Look up a user's profile.

```
mcp__claude_ai_Slack__slack_read_user_profile
  user_name: "[USER_NAME]"
```

Present:

```
@alice — Alice Johnson
  Title: Senior Backend Engineer
  Team: Platform
  Timezone: Europe/London (UTC+0)
  Status: 🟢 Active
```

---

## Error Handling

- **Channel not found**: Suggest searching with `/messaging-find channels`
- **Thread not found**: Check the URL or timestamp format
- **User not found**: Suggest searching with `slack_search_users`
- **Auth failure**: Suggest checking the Slack MCP connection in Claude settings
