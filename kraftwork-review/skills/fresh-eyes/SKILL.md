---
name: fresh-eyes
description: Use when you want an independent review of a plan, spec, or code file — uses cursor agent with gpt-5.3-codex for a fresh perspective to find gaps, unstated assumptions, and risks
---

# Fresh Eyes Review

Get an independent review of any file from a model with zero context of the current conversation. Surfaces what the author missed.

## Input

File path (optional). Optional focus area in quotes.

Examples: `/fresh-eyes`, `/fresh-eyes docs/plans/audit-log-design.md`, `/fresh-eyes src/handler.ts "focus on error handling"`

## Phase 1: Parse Input

**If a file path is provided:** use it directly.

**If no file path is provided:** look back through the current conversation for the most recent file you created (Write tool) or edited (Edit tool). Use that file's path. Tell the user which file you're reviewing so there's no ambiguity:

> No path specified — reviewing the last file I touched: `[FILE_PATH]`

If no file was created or edited in this session, ask the user for a path.

Validate the file exists:
```bash
test -f [FILE_PATH] && echo "exists" || echo "not found"
```

If not found, locate the workspace plugin's scripts directory in the plugin cache and run `find-workspace.sh` to get the workspace root, then try resolving the path relative to that root. If still not found, STOP and tell the user.

Extract the optional focus area — anything after the file path in quotes.

## Phase 2: Detect File Type

Classify the file to select the right review prompt:

| Classification | Match criteria |
|---------------|---------------|
| **plan** | Path contains `docs/plans/` OR filename ends with `-design.md` or `-plan.md` |
| **spec** | Path contains `docs/specs/` OR filename is `spec.md`, `idea.md`, or `tasks.md` |
| **code** | Everything else |

Store the classification as `[TYPE]`.

## Phase 3: Build Review Prompt

All prompts start with this base framing:

> You are reviewing this file with completely fresh eyes. You have no prior context about this project beyond what's in the file itself. Your job is to find what the author missed — not to praise what they got right. Be specific: quote the section, state the issue, explain why it matters.

Then append the type-specific instructions:

### Plan prompt
> This is a design document or architecture plan. Focus on:
> - Feasibility gaps — does this actually work end to end?
> - Missing alternatives that should have been considered
> - Unstated constraints or assumptions baked into the design
> - Scalability and operational concerns not addressed
> - Dependencies or failure modes not accounted for
> - Vague sections that need more specificity to be actionable

### Spec prompt
> This is a specification or requirements document. Focus on:
> - Ambiguous requirements that could be interpreted multiple ways
> - Missing edge cases and undefined behavior
> - Unclear or missing acceptance criteria
> - Gaps between what's stated and what would actually be needed to implement this
> - Contradictions between different sections
> - Assumptions about existing system behavior that aren't verified

### Code prompt
> This is source code. Focus on:
> - Bugs and logic errors
> - Unhandled error paths and failure modes
> - Security vulnerabilities
> - Race conditions or concurrency issues
> - Unclear intent — code that a new reader would misunderstand
> - Missing validation at system boundaries

### Focus override

If the user provided a focus area, append:

> Additionally, pay special attention to: [FOCUS_AREA]

### Assemble the prompt

Combine: base framing + type-specific instructions + optional focus override + the instruction:

> Read the file at [FILE_PATH] and provide your review.

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
## Fresh Eyes Review: [FILE_PATH]
**Type**: [TYPE] | **Model**: gpt-5.3-codex

---

[cursor agent output]

---

*Review by cursor agent (gpt-5.3-codex) — independent perspective, no shared context.*
```

## Error Handling

- **File not found**: Suggest the correct path or list similar files in the directory
- **cursor command not found**: Tell the user to install Cursor CLI or check PATH
- **Timeout**: Suggest a shorter file or splitting into sections
- **Empty output**: Retry once, then report the issue
