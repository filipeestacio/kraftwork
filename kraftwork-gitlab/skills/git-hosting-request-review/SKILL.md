---
name: git-hosting-request-review
description: Use when managing merge requests — creating, checking status, listing open MRs, viewing approvals or threads, or updating MR description
---

# GitLab MR Management

Manage merge request lifecycle via `glab` CLI.

## Setup

Read `workspace.json` from the workspace root. Extract `glab.defaultGroup` and `git.group`. If the `glab` section is missing, tell the user to run `/kraft-init` and STOP.

## Input

Optional subcommand: `create`, `status`, `list`, `approvals`, `threads`, `update`.

Examples: `/glab-mr`, `/glab-mr create`, `/glab-mr status`, `/glab-mr update`

**Default:** `status` if current branch has an MR, otherwise `list`.

## Project Detection

If inside a git repo, `glab` auto-detects the project. If at the workspace root or outside a repo, pass `--repo <git.group>/<name>` (using `git.group` from workspace.json) to commands that need it.

Check:
```bash
git remote get-url origin 2>/dev/null
```

If no remote, ask the user which project.

## Auth Check

```bash
glab auth status 2>&1
```

If not authenticated:
```
Not logged in to GitLab. Run: glab auth login
```
Then STOP.

---

## Subcommand: create

### Phase 1: Gather Context

```bash
git branch --show-current
git log main..HEAD --oneline
```

Determine target branch (default `main`). Build a suggested title from the branch name or first commit.

### Phase 1.5: Size Check (Soft Gate)

Before creating the MR, check the diff size:

```bash
INSERTIONS=$(git diff --shortstat $(git merge-base HEAD main)...HEAD | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)
DELETIONS=$(git diff --shortstat $(git merge-base HEAD main)...HEAD | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo 0)
TOTAL_LINES=$((INSERTIONS + DELETIONS))
FILES_CHANGED=$(git diff --name-only $(git merge-base HEAD main)...HEAD | wc -l | tr -d ' ')
```

**If TOTAL_LINES > 200 or FILES_CHANGED > 10:**

```
This MR is larger than recommended:
  Lines changed: $TOTAL_LINES (target: <200)
  Files touched: $FILES_CHANGED (target: <10)

Consider running /kraft-split to analyze whether this should be broken up.
```

Ask the user whether to:
1. **Proceed anyway** — create the MR as-is
2. **Run /kraft-split** — analyze and split first

If the user chooses to proceed, continue. If they choose to split, invoke `/kraft-split` and STOP.

This is a soft gate — the user always has the final say.

### Phase 2: Create MR

**IMPORTANT:** The MR description MUST end with `Closes <TICKET-ID>` (e.g., `Closes PROJ-1234`). Extract the ticket ID from the branch name. This auto-closes the linked ticket when the MR merges.

```bash
glab mr create --fill --target-branch main --title "[TITLE]" --description "[DESCRIPTION]

Closes [TICKET-ID]"
```

If the user wants to edit the description interactively, use `--web` to open in browser instead.

If a draft: add `--draft`.

### Phase 3: Confirm

Report: MR URL, title, target branch, draft status.

---

## Subcommand: status

### Phase 1: Find MR

```bash
glab mr view --json state,title,webUrl,mergeStatusEnum,pipeline,approvedBy,reviewers,headPipeline 2>/dev/null
```

If no MR for current branch:
```
No MR found for branch [BRANCH].

Run /glab-mr create to create one, or /glab-mr list to see open MRs.
```
Then STOP.

### Phase 2: Report

Present:
- **Title** and URL
- **State**: open / merged / closed
- **Mergeable**: yes / no (and why not, if blocked)
- **Pipeline**: status of latest pipeline
- **Approvals**: who approved, who's pending
- **Threads**: count of unresolved threads

---

## Subcommand: list

```bash
glab mr list --author=@me
```

If at workspace root (no git remote), search across the group using `glab.defaultGroup` from workspace.json:
```bash
glab api "/groups/<glab.defaultGroup>/merge_requests?state=opened&author_username=$(glab api /user --jq .username)&per_page=20"
```

Present as a table: MR number, title, project, pipeline status, approvals.

---

## Subcommand: approvals

### Phase 1: Get MR Approvals

```bash
glab mr view --json approvedBy,reviewers,approvalsLeft
```

If `glab mr view` doesn't expose `approvalsLeft`, fall back to the API:
```bash
glab api "projects/:id/merge_requests/:iid/approvals"
```

### Phase 2: Report

- **Approved by**: list of names
- **Pending reviewers**: who hasn't approved yet
- **Approvals remaining**: how many more needed
- **Blocked**: any approval rules not satisfied

---

## Subcommand: threads

```bash
glab mr view --comments
```

Filter to unresolved threads. For each:
- Author, timestamp
- File and line (if inline comment)
- Comment body (truncated if long)
- Thread status (resolved/unresolved)

If no unresolved threads:
```
No unresolved threads on this MR.
```

---

## Subcommand: update

### Phase 1: Fetch Current MR

```bash
glab mr view --json title,description,webUrl,iid
```

If no MR for current branch, STOP with message.

### Phase 2: Present Current State

Show current title and description to the user. Ask what they want to change:
- Title only
- Description only
- Both

### Phase 3: Apply Update

```bash
glab mr update [IID] --title "[NEW_TITLE]"
```

```bash
glab mr update [IID] --description "[NEW_DESCRIPTION]"
```

For long descriptions, write to a temp file and use:
```bash
glab mr update [IID] --description "$(cat /tmp/mr-description.md)"
```

### Phase 4: Confirm

Report updated fields and MR URL.

---

## Error Handling

- **No remote**: Ask user which project to use
- **Branch not pushed**: Suggest `git push -u origin [BRANCH]` first
- **MR conflicts**: Report and suggest rebasing
- **Permission denied**: Check project access
