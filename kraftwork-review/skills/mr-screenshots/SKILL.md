---
name: mr-screenshots
description: Use when a frontend MR or PR is ready and needs screenshots before review — captures UI states via chrome-devtools MCP, uploads to the hosting platform, and updates the MR/PR description. Trigger after implementation is complete, before requesting review.
---

# MR Screenshots

Capture screenshots of frontend features via chrome-devtools MCP, upload them, and embed in the MR/PR description.

## Prerequisites

- **chrome-devtools MCP** connected (provides `take_screenshot`, `navigate_page`, `click`, `take_snapshot`, `wait_for`)
- Dev server running with the feature branch code
- MR/PR already created

## Workflow

### 1. Identify Key States

Before touching the browser, list the UI states worth capturing. Typically:

- **Default/empty state** — feature with no data
- **Populated state** — feature with data loaded
- **Interactive states** — dialogs, dropdowns open, hover states
- **Error/edge states** — if visually distinct

Ask the user which states matter if unclear. Fewer good screenshots beat many redundant ones.

### 2. Navigate and Capture

```
mcp__chrome-devtools__navigate_page  → load the page
mcp__chrome-devtools__wait_for       → wait for content to render
mcp__chrome-devtools__take_screenshot → capture the viewport
```

For interactive states (dialogs, dropdowns):

```
mcp__chrome-devtools__take_snapshot  → get element UIDs
mcp__chrome-devtools__click          → trigger interaction
mcp__chrome-devtools__wait_for       → wait for new content
mcp__chrome-devtools__take_screenshot → capture
```

Save screenshots to a `screenshots/` directory in the worktree (gitignored).

### 3. Upload to Platform

**GitLab:**
```bash
curl --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  --form "file=@screenshots/name.png" \
  "https://gitlab.com/api/v4/projects/<url-encoded-project>/uploads"
```
Returns markdown: `![name](/uploads/<hash>/name.png)`

**GitHub:**
Screenshots can be dragged into PR descriptions via the web UI, or uploaded via the API. For CLI workflows, embed as base64 or link to committed images.

### 4. Update MR/PR Description

Add a `## Screenshots` section with the uploaded image markdown. Use `glab mr update` or `gh pr edit` to update the description.

## Tips

- **Reload after setup** — if the user configured data in the UI, reload to pick up saved state before capturing
- **`take_snapshot` before `click`** — you need element UIDs from the a11y tree to click interactive elements
- **`wait_for` after navigation** — don't screenshot before content renders
- **Name files descriptively** — `kb-card-empty-state.png` not `screenshot-1.png`
- **Verify screenshots** — use the Read tool on the saved PNG to visually confirm before uploading
