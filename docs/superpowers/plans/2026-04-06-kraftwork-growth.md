# kraftwork-growth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a standalone kraftwork plugin for growth tracking and weekly evidence-based reflection, with provider-aware source discovery.

**Architecture:** Standalone plugin (no `providers.json`) with two skills (`growth-init`, `growth-reflect`), a `workspace-config.json` for kraft-config integration, and a `claude-md-fragment.md` for workspace CLAUDE.md guidance. All files are markdown or JSON — no executable code.

**Tech Stack:** Claude Code plugin system (SKILL.md markdown skills, JSON config)

**Spec:** `docs/superpowers/specs/2026-04-06-kraftwork-growth-design.md`

---

## File Structure

```
kraftwork-growth/
├── .claude-plugin/
│   └── plugin.json              # Plugin metadata
├── config/
│   ├── workspace-config.json    # kraft-config fields (docsPath, disabledSources)
│   └── claude-md-fragment.md    # Behavioral guidance for workspace CLAUDE.md
└── skills/
    ├── growth-init/
    │   └── SKILL.md             # Goal scaffolding skill
    └── growth-reflect/
        └── SKILL.md             # Weekly evidence-gathering skill
```

Also modified:
- `.claude-plugin/marketplace.json` — add kraftwork-growth entry

---

### Task 1: Plugin scaffold and config files

**Files:**
- Create: `kraftwork-growth/.claude-plugin/plugin.json`
- Create: `kraftwork-growth/config/workspace-config.json`
- Create: `kraftwork-growth/config/claude-md-fragment.md`

- [ ] **Step 1: Create plugin.json**

```json
{
  "name": "kraftwork-growth",
  "version": "1.0.0",
  "description": "Growth tracking and weekly reflection for Kraftwork — scaffolds goals, gathers evidence from installed providers, writes Obsidian-compatible progress files (requires kraftwork core)",
  "author": {
    "name": "Filipe Estacio",
    "email": "f.estacio@gmail.com"
  }
}
```

- [ ] **Step 2: Create workspace-config.json**

```json
{
  "section": "growth",
  "title": "Growth Tracking Configuration",
  "description": "Settings for goal tracking and evidence-based reflection sessions",
  "fields": [
    {
      "key": "docsPath",
      "type": "string",
      "prompt": "Where should growth documents be stored, relative to workspace root?",
      "example": "docs/growth",
      "required": false
    },
    {
      "key": "disabledSources",
      "type": "string[]",
      "prompt": "Any evidence sources to skip? (slack, git-hosting, ticket-management, gmail, google-drive, local)",
      "example": "gmail, google-drive",
      "required": false
    }
  ]
}
```

- [ ] **Step 3: Create claude-md-fragment.md**

```markdown
## Growth Tracking

- Use `growth-init` to set up goal tracking before your first reflection session.
- Use `growth-reflect` for weekly evidence-gathering sessions against your goals.
- Evidence is gathered automatically from installed providers (messaging, git hosting, ticket management) and MCP servers (Gmail, Google Drive). No manual source configuration needed.
- Growth documents live in `docs/growth/` (or the path configured in workspace.json under `growth.docsPath`).
```

- [ ] **Step 4: Commit**

```bash
git add kraftwork-growth/.claude-plugin/plugin.json kraftwork-growth/config/workspace-config.json kraftwork-growth/config/claude-md-fragment.md
git commit -m "feat(kraftwork-growth): scaffold plugin with config files"
```

---

### Task 2: growth-init skill

**Files:**
- Create: `kraftwork-growth/skills/growth-init/SKILL.md`

- [ ] **Step 1: Write the growth-init SKILL.md**

The skill must follow the kraftwork skill format (YAML frontmatter with `name` and `description`, then markdown body). Full content:

````markdown
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
````

- [ ] **Step 2: Verify the file was written correctly**

Read the file back and confirm it has YAML frontmatter, all 3 steps, and the error handling section.

- [ ] **Step 3: Commit**

```bash
git add kraftwork-growth/skills/growth-init/SKILL.md
git commit -m "feat(kraftwork-growth): add growth-init skill"
```

---

### Task 3: growth-reflect skill

**Files:**
- Create: `kraftwork-growth/skills/growth-reflect/SKILL.md`

- [ ] **Step 1: Write the growth-reflect SKILL.md**

This is the largest file. Full content:

````markdown
---
name: growth-reflect
description: Weekly evidence-gathering reflection session — searches installed providers for progress against your growth goals, presents findings for curation, then writes Obsidian-compatible progress files
---

# Growth Reflect — Weekly Progress Session

Guided reflection on progress against your growth goals. Searches multiple sources for evidence, presents findings organized by goal and success signal, then pauses for you to curate and reflect before writing anything.

## Arguments

- No argument: covers the last 7 days
- `<days>`: covers the last N days (e.g., `/growth-reflect 14`)

## Setup

Read `workspace.json` from the workspace root. Extract:
- `[DOCS_PATH]` = `growth.docsPath` or default `docs/growth`
- `[DISABLED_SOURCES]` = `growth.disabledSources` or default `[]`

Detect installed providers by checking which sections exist in `workspace.json`:
- `[HAS_MESSAGING]` = true if `providers.messaging` or `slack` section exists
- `[HAS_GIT_HOSTING]` = true if `providers.git-hosting` or `github`/`gitlab` section exists
- `[GIT_HOST_TYPE]` = `"github"` if `github` section exists, `"gitlab"` if `gitlab` section exists
- `[HAS_TICKETS]` = true if `providers.ticket-management` or `jira`/`clickup` section exists
- `[TICKET_TYPE]` = `"jira"` if `jira` section exists, `"clickup"` if `clickup` section exists

MCP sources (not kraftwork providers) — detect by attempting a lightweight call:
- `[HAS_GMAIL]` = true if Gmail MCP tools are available
- `[HAS_GDRIVE]` = true if Google Drive MCP tools are available

`[HAS_LOCAL]` = always true.

Remove any source that appears in `[DISABLED_SOURCES]`.

If `workspace.json` is not found, look for `[DOCS_PATH]/goals/` by walking up from cwd. If neither is found, tell the user to run `/growth-init` first and stop.

Parse days argument:
```sh
DAYS="${1:-7}"
DATE_SINCE=$(date -v-${DAYS}d +%Y-%m-%d)
```

## Phase 1: Load Goals

Read all `.md` files from `[DOCS_PATH]/goals/` using the Read tool. For each goal file, extract:
- **Goal title** from the filename (strip `.md`, use as display name)
- **Success signals** from the "Success Signals" section
- **Practice descriptions** from the "What This Means in Practice" section
- **Search keywords** derived from the success signals and practice descriptions — pick the 3-4 most distinctive nouns and verbs per goal

Section detection must be fuzzy — match any of these formats (case-insensitive):
- `### Success Signals`, `**Success Signals**`, `**Success signals**`
- `### What This Means in Practice`, `**What this means in practice**`

If no goal files are found, tell the user to run `/growth-init` and stop.

Present to the user:

> **Goals loaded:**
> - [Goal Name] — N success signals
> - [Goal Name] — N success signals
>
> **Sources available:** [list of detected sources]
> **Sources disabled:** [list, or "none"]
>
> Searching the last {DAYS} days for evidence. This may take a moment.

## Phase 2: Gather Evidence

For each goal, search available sources using goal-specific keyword queries. Derive actual queries from the loaded goal files — do not use hardcoded search terms.

### Source: Messaging

**Skip if:** `[HAS_MESSAGING]` is false or `"slack"` in `[DISABLED_SOURCES]`.

Use the Slack MCP tool to search for messages in the date range:

```
mcp__claude_ai_Slack__slack_search_public_and_private
  query: "<goal keywords joined with OR> after:<DATE_SINCE>"
```

For each goal, construct a query combining its 3-4 most distinctive keywords with OR logic.

Example (derived from a goal about technical quality):
- `"architecture OR observability OR trade-off OR error-handling after:2026-03-30"`

Classify matching messages against the goal's success signals.

### Source: Git Hosting

**Skip if:** `[HAS_GIT_HOSTING]` is false or `"git-hosting"` in `[DISABLED_SOURCES]`.

**For GitHub (`[GIT_HOST_TYPE]` = `"github"`):**

```sh
gh api "search/issues?q=author:@me+type:pr+created:>=$DATE_SINCE&per_page=50"
```

For each PR, read the title and description. For PRs with review comments:
```sh
gh api "repos/[OWNER]/[REPO]/pulls/[NUMBER]/comments?per_page=20"
```

**For GitLab (`[GIT_HOST_TYPE]` = `"gitlab"`):**

```sh
USERNAME=$(glab api user | jq -r '.username')
glab api "merge_requests?scope=all&author_username=$USERNAME&created_after=$DATE_SINCE&state=all&per_page=50"
```

For MRs with discussions, extract `project_id` and `iid`:
```sh
glab api "projects/$PROJECT_ID/merge_requests/$MR_IID/notes?per_page=20"
```

Classify PRs/MRs against goals based on description content and discussion themes.

### Source: Ticket Management

**Skip if:** `[HAS_TICKETS]` is false or `"ticket-management"` in `[DISABLED_SOURCES]`.

**For Jira (`[TICKET_TYPE]` = `"jira"`):**

Use the Jira MCP tool:
```
mcp__claude_ai_Atlassian_Rovo__searchJiraIssuesUsingJql
  cloudId: <from workspace.json jira.cloudId>
  jql: "assignee = currentUser() AND updated >= '-[DAYS]d' ORDER BY updated DESC"
```

For each ticket, check status transitions and comments relevant to goal keywords.

**For ClickUp (`[TICKET_TYPE]` = `"clickup"`):**

Use the ClickUp MCP tools to search for tasks assigned to the user, updated within the date range. Classify against goal keywords.

### Source: Gmail

**Skip if:** `[HAS_GMAIL]` is false or `"gmail"` in `[DISABLED_SOURCES]`.

```
mcp__claude_ai_Gmail__gmail_search_messages
  query: "after:[DATE_SINCE_EPOCH] (meeting notes OR 1:1 OR standup OR retro OR <goal keywords>)"
```

Scan results for content relevant to loaded goals.

### Source: Google Drive

**Skip if:** `[HAS_GDRIVE]` is false or `"google-drive"` in `[DISABLED_SOURCES]`.

Search for documents modified in the date range using Google Drive MCP tools. Use goal-related keywords as search terms.

### Source: Local Workspace

**Skip if:** `"local"` in `[DISABLED_SOURCES]`.

Search local repositories for recent activity:

```sh
for repo in "[WORKSPACE]/sources"/*/; do
  git -C "$repo" log --author="$(git -C "$repo" config user.email)" --since="$DATE_SINCE" --oneline 2>/dev/null
done
```

Also check worktrees:
```sh
for wt in "[WORKSPACE]/tasks"/*/; do
  git -C "$wt" log --author="$(git -C "$wt" config user.email)" --since="$DATE_SINCE" --oneline 2>/dev/null
done
```

Check recently modified docs:
```sh
find "[WORKSPACE]/docs/plans" -name "*.md" -newermt "$DATE_SINCE" 2>/dev/null
find "[WORKSPACE]/docs/specs" -name "*.md" -newermt "$DATE_SINCE" 2>/dev/null
```

Check intel-store for recent learnings:
```sh
~/.claude/kraftwork-intel/cli query --recent $DAYS 2>/dev/null
```

If the intel CLI is not available, skip silently.

### Handling Unavailable Sources

For each source that fails or is not connected, log:

> **Warning: [Source] unavailable** — [reason]. Skipping.

Continue with remaining sources. The skill works with as few as one source available.

## Phase 3: Present Findings

Organize all gathered evidence by goal. For each goal, present:

```
## [Goal Name]

### Evidence Found

1. **[Source]** Brief description of the activity
   - *Success signal: [which success signal this maps to]*

2. **[Source]** Brief description
   - *Success signal: [mapping]*

### Gaps — no evidence found for:
- [Success signal with no matching evidence]
```

Present all goals, then **STOP**. Do not proceed to writing files.

Ask the user to curate, one goal at a time:

> **Ready for your input.** For each goal:
> 1. Which items should I dismiss?
> 2. Anything I missed that you want to add?
> 3. Write your reflection — what did you learn, what would you do differently, what's the trajectory?
>
> Let's start with **[first goal name]**.

Wait for the user to respond for each goal before moving to the next.

**IMPORTANT:** Do not generate reflections. The user writes these. You may prompt with guiding questions if the user is stuck:
- "What did you learn from [specific item]?"
- "How does this week compare to last?"
- "Any of the gaps worth addressing next week?"

But the words in the reflection are the user's.

After all goals are curated, confirm before writing:

> **Ready to write progress files.** Proceed?

## Phase 4: Write Progress Files

Only after the user confirms in Phase 3.

Determine the week date (Monday of the current week):

```sh
if [ "$(date +%u)" = "1" ]; then
  WEEK_DATE=$(date +%Y-%m-%d)
else
  WEEK_DATE=$(date -v-monday +%Y-%m-%d)
fi
```

Create the progress directory:

```sh
mkdir -p "[DOCS_PATH]/progress/$WEEK_DATE"
```

**Check for existing files first.** If `[DOCS_PATH]/progress/$WEEK_DATE/<goal-slug>.md` already exists, read it and ask the user:

> **Progress file already exists for [Goal Name] this week.** Append new evidence to the existing file, or replace it?

For each goal that has curated evidence, write a progress file using the Write tool.

**File:** `[DOCS_PATH]/progress/$WEEK_DATE/<goal-slug>.md`

Where `<goal-slug>` is the goal filename lowercased with spaces replaced by hyphens (e.g., "Software Craftsmanship" becomes "software-craftsmanship").

```markdown
# [Goal Name] — Week of [WEEK_DATE]

## Evidence
- **[Source]** Description of activity
  - *Success signal: [mapping]*
- **[Source]** Description
  - *Success signal: [mapping]*

## Reflection
[User's written reflection — copied verbatim from what they provided in Phase 3]
```

Only create a file for a goal if there is curated evidence. No empty files.

### Update Index

**File:** `[DOCS_PATH]/progress/index.md`

If the file exists, read it first. Check if a `## [WEEK_DATE]` section already exists:
- **If it exists:** update the section in place with the new/updated goal entries.
- **If it doesn't exist:** prepend the new week's entries at the top (after the `# Growth Progress` heading), keeping existing entries below.

If the file does not exist, create it.

Format:

```markdown
# Growth Progress

## [WEEK_DATE]
- [[<WEEK_DATE>/<goal-slug>|Goal Name]] — one-line summary of key evidence
- [[<WEEK_DATE>/<goal-slug>|Goal Name]] — one-line summary

## [PREVIOUS_WEEK_DATE]
- ...
```

Use Obsidian wikilink syntax. Newest entries first.

If the index file exists but is malformed (missing `# Growth Progress` heading or corrupted structure), warn the user and rebuild from all existing progress directories.

After writing all files:

> **Progress updated.**
> - Written: [list of files created/updated]
> - Index updated: `[DOCS_PATH]/progress/index.md`
>
> Next 1:1 prep: review the index for a quick update, or read individual goal files for detail.

## Error Handling

- **No workspace.json and no goals directory:** Tell user to run `/growth-init` and stop.
- **No evidence survives curation:** Inform the user. Do not create empty directories or files. This is itself a signal worth noting.
- **Source authentication failures:** Log the warning, skip the source, continue with others.
- **Date calculation on Linux:** Use `date -d "-${DAYS} days" +%Y-%m-%d` instead of `-v` flag if on Linux. Check `uname` first.
````

- [ ] **Step 2: Verify the file was written correctly**

Read the file back and confirm it has:
- YAML frontmatter with name and description
- Setup section with provider detection logic
- All 4 phases (Load Goals, Gather Evidence, Present Findings, Write Progress Files)
- All 6 source subsections in Phase 2
- Error handling section

- [ ] **Step 3: Commit**

```bash
git add kraftwork-growth/skills/growth-reflect/SKILL.md
git commit -m "feat(kraftwork-growth): add growth-reflect skill"
```

---

### Task 4: Marketplace registration

**Files:**
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Add kraftwork-growth to marketplace.json**

Add a new entry to the `plugins` array in `.claude-plugin/marketplace.json`:

```json
{
  "name": "kraftwork-growth",
  "source": {
    "source": "git-subdir",
    "url": "https://github.com/filipeestacio/kraftwork.git",
    "path": "kraftwork-growth"
  },
  "description": "Growth tracking and weekly reflection for Kraftwork — scaffolds goals, gathers evidence from installed providers, writes Obsidian-compatible progress files",
  "version": "1.0.0"
}
```

Insert it after the `kraftwork-zellij` entry (keeping utility plugins grouped together, before the `presentation` entry).

- [ ] **Step 2: Verify marketplace.json is valid JSON**

```bash
cat .claude-plugin/marketplace.json | jq . > /dev/null
```

Expected: exits 0 with no output (valid JSON).

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "feat(kraftwork-growth): register plugin in marketplace"
```
