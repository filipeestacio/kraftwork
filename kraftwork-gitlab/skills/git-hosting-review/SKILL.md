---
name: git-hosting-review
description: Use when reviewing someone else's merge request — fetches MR details, shows diffs, lists discussions, and supports local checkout and commenting
---

# GitLab MR Review

Review someone else's merge request via `glab` CLI.

## Input

MR identifier: a number (e.g., `123`), a URL (e.g., `https://gitlab.com/my-group/my-repo/-/merge_requests/123`), or omit to be prompted.

Examples: `/glab-review 123`, `/glab-review https://gitlab.com/.../merge_requests/456`

## Parse Input

- **Number**: Use directly as MR IID. Requires being in the correct repo or specifying `--repo`.
- **URL**: Extract project path and MR IID from the URL.
- **None**: Ask the user for the MR number or URL.

## Auth Check

```bash
glab auth status 2>&1
```

If not authenticated, STOP and suggest `glab auth login`.

## Phase 1: MR Overview

```bash
glab mr view [IID] --repo [REPO]
```

Present:
- **Title** and URL
- **Author**
- **Source → Target** branch
- **State**: open / merged / closed / draft
- **Description** (truncated if very long)
- **Pipeline status**
- **Labels and milestones** (if any)

## Phase 2: Diff Stats

```bash
glab mr diff [IID] --repo [REPO] --stat
```

Present:
```
Files changed: [N]
Additions: +[X]  Deletions: -[Y]

  src/handler.ts        | +45 -12
  src/service.ts        | +8  -3
  test/handler.test.ts  | +67 -0
  ...
```

## Phase 3: Existing Discussions

```bash
glab mr view [IID] --repo [REPO] --comments
```

Summarize:
- Total threads (resolved and unresolved)
- Unresolved threads with: author, file/line, summary of comment

If no threads:
```
No discussions yet.
```

## Phase 4: Offer Next Actions

```
What would you like to do?

1. View full diff (opens in terminal)
2. Check out branch locally
3. Leave a comment
4. Approve the MR
5. Done
```

### Action: View Full Diff

```bash
glab mr diff [IID] --repo [REPO]
```

Present the diff, or if very large, summarize by file and ask which files to show.

### Action: Check Out Branch

```bash
glab mr checkout [IID] --repo [REPO]
```

Confirm the branch is checked out and ready for local review.

### Action: Leave a Comment

Ask the user for the comment text, then:

```bash
glab mr comment [IID] --repo [REPO] --message "[COMMENT]"
```

For long comments, write to temp file:
```bash
glab mr comment [IID] --repo [REPO] --message "$(cat /tmp/mr-comment.md)"
```

### Action: Approve

```bash
glab mr approve [IID] --repo [REPO]
```

Confirm approval was submitted.

## Error Handling

- **MR not found**: Check IID and project. List recent MRs with `glab mr list`.
- **Wrong project**: If IID doesn't match, suggest specifying `--repo <git.group>/<name>` (using `git.group` from workspace.json).
- **Permission denied**: Check project access.
- **Already approved**: Note it and move on.
