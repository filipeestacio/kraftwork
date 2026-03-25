---
name: clickup-share
description: Use when posting status updates, progress notes, or messages to the ClickUp Chat channel and optionally to task comments
---

# ClickUp Share

`SCRIPT_DIR` is `../../scripts` relative to this SKILL.md file.

Read `workspace.json` from the workspace root. Extract the `clickup` section. If the `clickup` section is missing, tell the user to run `/kraft-init`.

## Auth

Do NOT pre-check authentication. Run the intended operation. If the token env var is unset, report:

> Set `<token_env>` with your ClickUp API token.

If the API returns 401, report:

> ClickUp API returned unauthorized — check that `<token_env>` contains a valid token.

---

## Step 1: Check Chat Channel Config

Read `chatChannelId` from the `clickup` section of `workspace.json`. If it is not configured, tell the user:

> No chat channel configured. Add `chatChannelId` to the clickup section of workspace.json or run `/kraft-init`.

---

## Step 2: Choose Message Prefix

Ask the user which prefix to use, or infer from context:

| Prefix | When to use |
|--------|-------------|
| `[Update]` | General progress updates |
| `[Blocker]` | Blocking issues |
| `[Done]` | Completed work |

Format the final message as:

```
[Prefix] TASK-ID: Message text
```

If no task ID is available, omit the `TASK-ID:` portion.

---

## Step 3: Ask for Message Content

Ask the user for the message text if not already provided. Combine it with the chosen prefix and task ID (if any) to produce the final message body.

---

## Step 4: Detect Task Branch

Check the current git branch name for a ticket ID matching the pattern `[A-Z]+-[0-9]+`:

```bash
git rev-parse --abbrev-ref HEAD
```

If a ticket ID is found, offer to also post the message as a comment on that task. Ask the user whether they want to do so before posting.

---

## Step 5: Post to Chat

```bash
bun run "$SCRIPT_DIR/clickup-api.ts" send-chat --channel <chatChannelId> --body <message>
```

If the Chat API fails with a non-auth error, report the error and fall back to posting as a task comment (Step 6) if a task ID is available.

---

## Step 6: Optionally Post to Task (if applicable)

If a task ID was detected and the user agreed, or if Chat failed and a task ID is available:

```bash
bun run "$SCRIPT_DIR/clickup-api.ts" add-comment <task_id> --body <message>
```

---

## Step 7: Confirm

Report what was posted and where. Example:

```
Posted to Chat (#general): [Update] TASK-123: Finished refactoring the auth module.
Posted as comment on TASK-123.
```

Never post without explicit user intent. Always confirm what was posted and where.

---

## Error Handling

- **Token not set / 401**: See Auth section above.
- **`chatChannelId` not configured**: "No chat channel configured. Add `chatChannelId` to the clickup section of workspace.json or run `/kraft-init`."
- **Chat API failure (non-auth)**: Report the error. If a task ID is available, fall back to posting as a task comment only.
- **Message too long**: ClickUp Chat has a character limit. If the message exceeds it, warn the user and suggest shortening, or truncate with a trailing note such as `… [truncated]`.
