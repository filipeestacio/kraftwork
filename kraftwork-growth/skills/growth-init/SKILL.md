---
name: growth-init
description: Set up growth tracking — scaffolds goal directory structure and guides creation of goal files with practices and success signals
---

# Growth Init — Set Up Growth Tracking

Scaffolds the growth directory structure and guides you through creating goal files that `growth-reflect` uses for evidence gathering.

## Setup

Read `workspace.json` from the workspace root. Extract `growth.docsPath`. If the `growth` section is missing or `docsPath` is not set, default to `docs/growth`.

Store:
- `[WORKSPACE]` = workspace root (directory containing `workspace.json`)
- `[DOCS_PATH]` = `[WORKSPACE]/<growth.docsPath or "docs/growth">`

If `workspace.json` is not found (walk up from cwd), ask the user for the workspace path. Do not create `docs/` — that's a workspace-level decision.

## Step 1: Scaffold Directory Structure

Create the required directories:

```sh
mkdir -p "[DOCS_PATH]/goals"
mkdir -p "[DOCS_PATH]/definitions"
mkdir -p "[DOCS_PATH]/progress"
```

Check what already exists and report:

> **Growth directory status:**
> - `goals/` — N goal files found (or "empty — needs goals")
> - `definitions/` — N definition files found (or "empty")
> - `progress/` — N progress entries found (or "empty — run /growth-reflect to start")

If goal files already exist, skip to Step 3.

## Step 2: Guide Goal File Creation

Ask the user:

> **Let's set up your goals.** For each goal, I need:
> 1. Goal name (becomes the filename)
> 2. A summary of what the goal means
> 3. What it means in practice (concrete behaviors)
> 4. Success signals (how you know you're making progress)
>
> You can paste from your performance review tool, a doc, or describe it and I'll help structure it.
>
> How many goals do you have?

For each goal, create a file following this format:

**File:** `[DOCS_PATH]/goals/<Goal Name>.md`

```markdown
<Summary — 1-2 sentences describing the goal>

### What This Means in Practice

- <Concrete behavior or action>
- <Another behavior>

### Success Signals

- <Observable indicator of progress>
- <Another indicator>
```

The file has no top-level heading — the filename IS the title. This keeps it clean in Obsidian.

After creating each goal file, show it to the user for confirmation before moving to the next.

## Step 3: Validate Setup

Read each goal file and verify it has the required sections. Detection must be fuzzy — accept any of these formats (case-insensitive):
- `### Success Signals`, `**Success Signals**`, `**Success signals**`
- `### What This Means in Practice`, `**What this means in practice**`

Each section must have at least one bullet point underneath it. Check for content presence, not heading format — goal files may be pasted from various sources with inconsistent formatting.

Report:

> **Setup complete.**
> - Goals: [list of goal names]
> - Ready for: `/growth-reflect`
>
> Tip: You can also add supporting documents to `definitions/` for reference.

## Error Handling

- **No workspace.json found:** Ask the user for the workspace path. Do not create `docs/` — that's a workspace-level decision.
- **Goal file missing required sections:** Warn and offer to fix. Don't silently skip.
- **Re-running on existing setup:** Report what exists, offer to add new goals. Never overwrite existing files.
