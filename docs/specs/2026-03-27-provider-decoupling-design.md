# Provider Decoupling Design

Decouple kraftwork core from vendor-specific extensions (Jira, GitLab, etc.) so that core orchestrates workflows without knowing which vendors provide the underlying capabilities.

## Problem

Core skills hardcode references to `glab`, `acli`, and vendor-specific APIs. Installing kraftwork for a project that uses GitHub + Clickup, or a purely local project, breaks or degrades ungracefully.

## Provider Categories

Core defines three capability categories. Each category has a set of named capabilities that providers implement.

### Git Hosting

Covers repository operations, PR lifecycle, and CI.

| Capability | Type | Signature |
|---|---|---|
| `auth-check` | script | `→ exit 0 if authenticated` |
| `search-prs` | script | `<ticket-id> → JSON array of PRs` |
| `search-branches` | script | `<ticket-id> → JSON array of branches` |
| `clone-repo` | script | `<group> <repo> <dest> → cloned repo` |
| `create-pr` | script | `<source> <target> <title> <body> → PR URL` |
| `fetch-pr-details` | script | `<pr-id> → JSON with metadata, discussions, changes` |
| `ci-status` | script | `<branch> → JSON pipeline/checks status` |
| `pr-description-guide` | fragment | Vendor-specific PR description conventions |
| `branch-naming` | fragment | Vendor-specific branch naming conventions |

### Ticket Management

Covers task tracking and ticket lifecycle.

| Capability | Type | Signature |
|---|---|---|
| `fetch-ticket` | script | `<ticket-id> → JSON with summary, status, fields` |
| `search-tickets` | script | `<query> → JSON array of tickets` |
| `transition-ticket` | script | `<ticket-id> <status> → updated ticket` |
| `ticket-id-pattern` | fragment | Regex pattern for ticket IDs (e.g., `PROJ-\d+`, `#\d+`) |

### Document Storage

Covers specs, plans, retros, and other project documents.

| Capability | Type | Signature |
|---|---|---|
| `write-doc` | script | `<path> <content> → written path` |
| `read-doc` | script | `<path> → document content` |
| `list-docs` | script | `<prefix> → list of document paths` |

## Provider Manifest

Each extension that provides core capabilities declares a `providers.json` at its plugin root:

```json
{
  "providers": [
    {
      "category": "git-hosting",
      "scripts": {
        "search-prs": "scripts/search-prs.sh",
        "search-branches": "scripts/search-branches.sh",
        "clone-repo": "scripts/clone-repo.sh",
        "create-pr": "scripts/create-pr.sh",
        "fetch-pr-details": "scripts/fetch-pr-details.sh",
        "auth-check": "scripts/auth-check.sh",
        "ci-status": "scripts/ci-status.sh"
      },
      "fragments": {
        "pr-description-guide": "fragments/pr-description.md",
        "branch-naming": "fragments/branch-naming.md"
      }
    }
  ]
}
```

An extension can provide multiple categories (e.g., Clickup providing both ticket-management and document-storage). A single category can only be filled by one provider at a time. The user selects per-category, not per-extension.

## Discovery and Configuration

### kraft-config (replaces kraft-init)

Single command, idempotent and incremental:

- **First run**: full wizard — scaffold workspace, scan installed `kraftwork-*` plugins for `providers.json`, present per-category choices, write config
- **Subsequent runs**: detect changes (new plugins, removed plugins, missing config sections), prompt only for the delta, preserve existing config

**Discovery flow:**

Plugin paths are resolved from the Claude Code plugin cache (`~/.claude/plugins/cache/`). `kraft-config` reads the plugin registry to find installed `kraftwork-*` plugins and their cache paths.

1. Scan installed `kraftwork-*` plugins for `providers.json`
2. Group by category
3. For each category:
   - One provider available → auto-select
   - Multiple providers → ask the user
   - No provider → use built-in fallback (`kraftwork-local`)
4. Write selections to `workspace.json`

### workspace.json Provider Config

```json
{
  "workspace": {
    "name": "my-project",
    "path": "/path/to/workspace"
  },
  "providers": {
    "git-hosting": {
      "plugin": "kraftwork-gitlab",
      "config": {
        "defaultGroup": "my-group"
      }
    },
    "ticket-management": {
      "plugin": "kraftwork-jira",
      "config": {
        "project": "PROJ",
        "cloudId": "abc-123"
      }
    },
    "document-storage": {
      "plugin": "kraftwork-local"
    }
  }
}
```

### Runtime Resolution

Core reads `workspace.json` to find which plugin provides each category, then resolves script/fragment paths from that plugin's `providers.json`. No scanning at runtime.

## Fragment Injection

Core skills define injection points as placeholders:

```
{{git-hosting:pr-description-guide}}
```

At skill load time:

1. Read `workspace.json` → determine provider plugin for the category
2. Read that plugin's `providers.json` → map fragment name to file path
3. Replace placeholder with fragment file content

If no provider is configured or the fragment doesn't exist, the placeholder is replaced with empty string. The skill works without it.

**Fragment vs script distinction:**
- Behavioral instructions for Claude (how to format, conventions, what to include) → fragment
- Executable logic (search, create, fetch) → script

## Built-in Fallback: kraftwork-local

Bundled inside core. Provides defaults for all categories, implementing only capabilities that genuinely work locally.

**Document Storage:** fully functional — reads/writes to `workspace/docs/`.

**Git Hosting:** partial — `auth-check` (always succeeds), `search-branches` (local branches only). PR and remote operations are unavailable. Skills that use unavailable capabilities skip gracefully with a one-time nudge to set up a git hosting provider.

**Ticket Management:** partial — provides a `workspace/tasks/` directory for local task files. Capabilities like `fetch-ticket` and `search-tickets` operate on this directory. If no ticket provider is configured, skills that derive branch names from tickets prompt the user for a branch name directly.

## Workspace Layout

```
workspace/
  modules/       # git repos as submodules of workspace repo
  trees/         # worktrees (gitignored)
  docs/          # specs, plans, retros (created on first use by doc provider)
  tasks/         # local task files (created only if no ticket provider)
  .gitignore     # trees/
```

The workspace itself is a git repo. Repos in `modules/` are submodules.

`kraft-config` creates `modules/`, `trees/`, and `.gitignore` on first run. `tasks/` and `docs/` are created lazily on first use by their respective providers.

### Renames from Current Layout

| Current | New | Reason |
|---|---|---|
| `workspace/sources/` | `workspace/modules/` | Workspace is a repo; codebases are submodules |
| `workspace/tasks/` (worktrees) | `workspace/trees/` | Frees `tasks/` for actual task management |

## Core Skills

### Inventory

| Skill | Purpose |
|---|---|
| `kraft-config` | Set up or reconfigure workspace and providers |
| `kraft-work` | Start, resume, or stack work (context-aware) |
| `kraft-plan` | Brainstorm and spec |
| `kraft-implement` | Execute from specs |
| `kraft-split` | Split branch into stacked PRs |
| `kraft-retro` | Post-merge retrospective |
| `kraft-archive` | Clean up completed worktree |
| `kraft-import` | Onboard new repo as submodule + codebase scan |
| `kraft-sync` | Pull latest for all modules |

### Consolidations

**kraft-work** merges `kraft-start`, `kraft-resume`, and `kraft-stack`:

- Ticket/branch ID provided + no existing worktree → create worktree (was kraft-start)
- Ticket/branch ID provided + existing worktree found → resume (was kraft-resume)
- No ID provided + active worktrees exist → list and pick (was kraft-resume)
- Run from inside a worktree → offer to stack on current or start fresh (was kraft-stack)

**kraft-config** replaces `kraft-init` with idempotent, incremental behavior.

### Removals

- **Zellij integration** removed from core. `kraftwork-zellij` remains as a standalone extension.
- **ArgoCD** dropped from core categories. `kraftwork-argocd` remains standalone until CD abstraction is better understood.

### Skill Adaptation Pattern

Each core skill follows this pattern:

1. Resolve providers from `workspace.json`
2. Check which capabilities are available
3. Use available capabilities; skip unavailable ones gracefully
4. No skill ever references `glab`, `gh`, `acli`, or any vendor CLI directly

**kraft-config**: scans plugins, presents per-category choices, writes `workspace.json`. Creates workspace directory structure. Idempotent on re-run.

**kraft-work**: delegates to ticket provider for ticket details (or prompts user directly). Delegates to git hosting for PR/branch search (or skips). Creates worktree locally (always available).

**kraft-split**: delegates PR creation to git hosting provider. Unavailable without git hosting — errors with guidance.

**kraft-retro**: fetches review feedback via git hosting `fetch-pr-details`. Reads docs via document storage `read-doc`. Works with whatever providers are available.

**kraft-import**: clones repo via git hosting `clone-repo`, adds as submodule. Scans codebase for documentation, updates workspace CLAUDE.md/AGENTS.md.

## Standalone Extensions

These extensions are not orchestrated by core — they provide independent skills that complement the workflow:

- **kraftwork-zellij** — terminal multiplexer integration
- **kraftwork-intel** — knowledge base (store/query codebase learnings)
- **kraftwork-review** — code review tools (self-review, fresh-eyes, screenshots)
- **kraftwork-argocd** — CD status and debugging

Standalone extensions have no `providers.json` and are not discovered by `kraft-config`.

## Migration Path

Existing `kraftwork-gitlab` and `kraftwork-jira` extensions need to:

1. Add `providers.json` declaring their categories and capabilities
2. Move/rename scripts to match the provider capability names
3. Move vendor-specific behavioral instructions from core skills into fragment files

Core skills need to:

1. Replace all direct `glab`/`acli`/vendor references with provider delegation
2. Add `{{category:fragment-name}}` placeholders where vendor-specific instructions live
3. Handle missing capabilities gracefully
4. Update directory references (`sources` → `modules`, `tasks` → `trees`)
