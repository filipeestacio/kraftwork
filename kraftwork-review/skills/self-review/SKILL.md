---
name: self-review
description: Use when implementation is complete and you want to review the branch diff before submitting an MR — uses cursor agent with gpt-5.3-codex to simulate a senior engineer MR review
---

# Self-Review

Review the current branch's diff against its base branch using a model with zero context of the current conversation. Simulates a senior engineer MR review before you submit.

## Input

Optional focus area in quotes.

Examples: `/self-review`, `/self-review "focus on error handling"`

## Phase 1: Validate Context

Verify we're inside a git repo:
```bash
git rev-parse --is-inside-work-tree 2>/dev/null && echo "git repo" || echo "not a git repo"
```

If not a git repo, STOP: "This skill requires a git repository. Run it from inside a worktree."

Get the current branch:
```bash
git branch --show-current
```

If on `main` or `master`, STOP: "You're on the main branch. Switch to a feature branch first."

Auto-detect the base branch:
```bash
git rev-parse --abbrev-ref @{upstream} 2>/dev/null
```

If upstream is set, extract the remote branch name (e.g., `origin/main` → use `origin/main`). If no upstream, fall back to `origin/main`.

Store as `[BASE]`.

Verify there are commits to review:
```bash
git log [BASE]..HEAD --oneline
```

If empty, STOP: "No commits found between `[BASE]` and HEAD. Nothing to review."

Tell the user what you're reviewing:

> Reviewing branch `[BRANCH]` against `[BASE]`

## Phase 2: Generate Diff & Stats

Capture the diff stats:
```bash
git diff [BASE]...HEAD --stat
```

Capture commit messages:
```bash
git log [BASE]..HEAD --oneline
```

Capture the full diff:
```bash
git diff [BASE]...HEAD
```

Count diff lines. If over 3000 lines, warn:

> This diff is large (~[N] lines). The review may miss details — consider splitting your MR.

Proceed regardless.

Store the diff as `[DIFF]`, stats as `[STATS]`, and commit log as `[COMMITS]`.

## Phase 3: Build Review Prompt

Start with the base framing:

> You are a senior engineer reviewing a merge request. You have no prior context about this project beyond the diff and commit messages below. Your job is to find what the author missed — not to praise what they got right. Be specific: quote the code, state the issue, explain why it matters.

Append the review instructions:

> Review this merge request for:
>
> **Correctness & Logic**
> - Bugs, logic errors, off-by-one mistakes
> - Unhandled error paths and failure modes
> - Race conditions or concurrency issues
> - Security vulnerabilities (injection, auth bypass, data leaks)
>
> **Code Quality**
> - Unclear intent — code a new reader would misunderstand
> - Missing validation at system boundaries
> - DRY violations — duplicated logic that should be extracted
> - YAGNI violations — over-engineering, unnecessary abstractions, speculative features
> - Unnecessary comments that restate the code
>
> **Change Hygiene**
> - Commit messages: are they clear and well-scoped?
> - Is the change appropriately scoped, or does it mix unrelated concerns?
> - Are there test coverage gaps for new/changed behavior?
> - Are there leftover debug statements, TODOs, or commented-out code?
>
> Structure your review as:
> 1. **Summary** — one paragraph on what this MR does and your overall assessment
> 2. **Critical issues** — must fix before merge
> 3. **Suggestions** — would improve but not blocking
> 4. **Nits** — minor style/preference items

If the user provided a focus area, append:

> Additionally, pay special attention to: [FOCUS_AREA]

Append the commit log and diff:

> ## Commits
> [COMMITS]
>
> ## Diff
> [DIFF]

Store the full prompt as `[PROMPT]`.

## Phase 4: Run Review

```bash
cursor agent --model gpt-5.3-codex -p "[PROMPT]"
```

Capture the full output.

If the command fails or times out, report the error and suggest the user check that `cursor` CLI is installed and accessible.

## Phase 5: Present Results

Present the output under a clear header:

```
## Self-Review: [BRANCH] → [BASE]
**Files changed**: [FILE_COUNT] | **Lines**: [INSERTIONS]+/[DELETIONS]- | **Model**: gpt-5.3-codex

---

[cursor agent output]

---

*Review by cursor agent (gpt-5.3-codex) — independent perspective, no shared context.*
```

## Error Handling

- **Not a git repo**: Stop with clear message suggesting to run from a worktree
- **On main branch**: Stop, explain to switch to a feature branch
- **No commits**: Stop, explain nothing to review
- **cursor command not found**: Tell the user to install Cursor CLI or check PATH
- **Timeout**: Suggest a smaller diff or splitting the MR
- **Empty output**: Retry once, then report the issue
