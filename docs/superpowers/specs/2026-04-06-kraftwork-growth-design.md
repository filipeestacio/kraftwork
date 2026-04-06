# kraftwork-growth — Design Spec

Standalone kraftwork plugin for structured growth tracking and weekly evidence-based reflection. Replaces the Aircall-specific `growth` plugin with a provider-aware, configurable alternative.

## Problem

Developers tracking growth goals (OKRs, performance reviews, personal development) lack a structured way to gather evidence of progress across their daily tools. The original `growth` plugin solved this but was hardcoded to Aircall's toolchain (CultureAmp, GitLab, specific MCP servers).

## Goals

- Generic goal structure that works with any goal framework
- Auto-discover evidence sources from installed kraftwork providers
- Configurable via `workspace-config.json` like all kraftwork plugins
- Obsidian-compatible output (wikilinks, vault-friendly structure)

## Non-Goals

- No provider interface — this is a standalone utility plugin
- No custom goal template schemas — the practices + signals format is fixed
- No output format toggle — Obsidian wikilinks are the only format

## Plugin Structure

```
kraftwork-growth/
├── .claude-plugin/
│   └── plugin.json
├── config/
│   ├── workspace-config.json
│   └── claude-md-fragment.md
└── skills/
    ├── growth-init/
    │   └── SKILL.md
    └── growth-reflect/
        └── SKILL.md
```

No `providers.json` — standalone plugin like `kraftwork-argocd`.

## Configuration

### plugin.json

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

### workspace-config.json

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

- `docsPath` defaults to `docs/growth` when not set
- `disabledSources` defaults to empty (all available sources enabled)

### claude-md-fragment.md

Behavioral guidance appended to workspace CLAUDE.md during kraft-config:
- Use `growth-init` to set up goal tracking before first reflection
- Use `growth-reflect` for weekly evidence gathering sessions
- Evidence is gathered from installed providers — no manual source configuration needed

## Skill: growth-init

Scaffolds the growth directory and guides goal file creation.

### Workflow

1. **Locate workspace** — read `workspace.json` from workspace root (walk up from cwd). Extract `growth.docsPath` or default to `docs/growth`.
2. **Scaffold directories** — create `goals/`, `definitions/`, `progress/` under the docs path. Report what already exists.
3. **Guide goal creation** — ask user for goals (name, summary, practices, signals). Supports pasting from any source. Create one file per goal.
4. **Validate** — check each goal file has both sections with at least one bullet. Report status.

### Goal File Format

**File:** `<docsPath>/goals/<Goal Name>.md`

```markdown
<Summary — 1-2 sentences describing the goal>

### What This Means in Practice

- <Concrete behavior or action>

### Success Signals

- <Observable indicator of progress>
```

No top-level heading — filename is the title. Section detection is fuzzy and case-insensitive to handle pasted content from any goal-tracking tool.

### Idempotency

Re-running reports existing goals and offers to add new ones. Never overwrites existing files.

## Skill: growth-reflect

Weekly evidence-gathering session against loaded goals.

### Arguments

- No argument: last 7 days
- `<days>`: last N days

### Source Discovery

The skill determines available sources by reading `workspace.json`:

| Source | Detection Method | What It Searches |
|--------|-----------------|------------------|
| Messaging (Slack) | `workspace.json` has `messaging` provider config | User's messages matching goal keywords |
| Git hosting (GitHub/GitLab) | `workspace.json` has `git-hosting` provider config | User's PRs/MRs, descriptions, review discussions |
| Ticket management (Jira/ClickUp) | `workspace.json` has `ticket-management` provider config | User's recent ticket activity, comments, transitions |
| Gmail | Gmail MCP server connected | Emails matching goal keywords (meeting notes, 1:1s) |
| Google Drive | Google Drive MCP server connected | Recently modified docs matching goal keywords |
| Local workspace | Always available | Git logs across repos, recent docs, intel-store |

Sources listed in `growth.disabledSources` are skipped. Unavailable sources log a warning and continue.

### Provider-Aware Queries

Instead of hardcoding tool names, the skill resolves how to query each source:

- **Messaging:** uses MCP tools from the installed messaging provider (e.g., `slack_search_public_and_private`)
- **Git hosting:** for local repos, uses `git log` directly. For remote PR/MR data, checks which provider is installed — GitHub uses `gh` CLI, GitLab uses `glab` CLI. The skill reads `workspace.json` to determine the git-hosting provider type.
- **Ticket management:** uses MCP tools from the installed ticket provider (e.g., Jira MCP for JQL queries, ClickUp MCP for task searches)
- **Gmail/Google Drive:** uses their respective MCP tools directly (these aren't kraftwork providers)
- **Local:** uses `git`, `find`, and the intel CLI directly

### Workflow

1. **Locate workspace and load goals** — find `workspace.json`, read `growth.docsPath`, load all goal files. Extract success signals and derive search keywords.
2. **Gather evidence** — for each goal, search available sources with goal-specific keyword queries. Classify findings against success signals.
3. **Present findings** — organize by goal, map evidence to success signals, note gaps. Then **stop and wait**.
4. **User curation** — one goal at a time, user dismisses irrelevant items, adds missed items, writes their own reflection. The skill does not generate reflections.
5. **Write progress files** — after user confirms, write to `<docsPath>/progress/<WEEK_DATE>/<goal-slug>.md` with Obsidian wikilinks. Update or create `index.md` with newest-first entries.

### Progress File Format

**File:** `<docsPath>/progress/<WEEK_DATE>/<goal-slug>.md`

```markdown
# [Goal Name] — Week of [WEEK_DATE]

## Evidence
- **[Source]** Description of activity
  - *Success signal: [mapping]*

## Reflection
[User's written reflection — verbatim from curation step]
```

### Index Format

**File:** `<docsPath>/progress/index.md`

```markdown
# Growth Progress

## [WEEK_DATE]
- [[<WEEK_DATE>/<goal-slug>|Goal Name]] — one-line summary

## [PREVIOUS_WEEK_DATE]
- ...
```

Newest first. Existing entries preserved. Duplicate week headings updated in place.

### Error Handling

- Progress file exists for this week + goal: ask before overwriting
- Week heading already in index: update in place, don't duplicate
- Malformed index: warn and rebuild from existing progress directories
- No evidence survives curation: inform user, don't create empty files
- No goals found: direct to `growth-init`

## What Changed From the Original

| Original (growth plugin) | kraftwork-growth |
|--------------------------|-----------------|
| CultureAmp goal references | Generic — works with any goal framework |
| `find-workspace.sh` dependency | `workspace.json` lookup |
| Hardcoded `glab` CLI | Provider-resolved git-hosting (gh or glab) |
| Hardcoded Slack MCP tool names | Discovered from installed messaging provider |
| Hardcoded Jira MCP | Discovered from installed ticket-management provider |
| `filipe.estacio@aircall.io` author | `f.estacio@gmail.com` |
| No configuration | `workspace-config.json` with docsPath and disabledSources |

## Marketplace Registration

Add to `.claude-plugin/marketplace.json`:

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
