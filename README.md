<img width="1600" height="679" alt="Kraftwork_banner" src="https://github.com/user-attachments/assets/09164633-434a-4633-92ad-57bd7feebe19" />

# Kraftwork

Opinionated developer workflow orchestration for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Manages the full development lifecycle — from ticket to merge request — through spec-driven planning, git worktree isolation, and modular integrations.

## Overview

Kraftwork is a monorepo containing a core plugin and optional extensions, all built as Claude Code plugins. It enforces a structured workflow: plan before you code, isolate work in worktrees, decompose into small reviewable MRs, and capture learnings along the way.

```
kraftwork/              Core workflow plugin with pluggable providers
kraftwork-argocd/       ArgoCD deployment health and debugging
kraftwork-clickup/      ClickUp ticket management and document storage provider
kraftwork-github/       GitHub git hosting provider
kraftwork-gitlab/       GitLab CI/CD and merge request workflows
kraftwork-intel/        Local intelligence layer — metrics, knowledge, evals
kraftwork-jira/         Jira ticket search and management
kraftwork-review/       Independent code review perspectives
kraftwork-zellij/       Zellij terminal multiplexer control
```

## Core Workflow

The typical development cycle follows this path:

1. **`/kraft-config`** — Configure workspace with repos, providers, and directory scaffolding
2. **`/kraft-work TICKET-123`** — Create a git worktree for a ticket, resume existing work, or manage stacked worktrees
3. **`/kraft-plan`** — Brainstorm, create a spec, and decompose work into MR-sized tasks
4. **`/kraft-implement`** — Execute tasks from the spec with change tracking
5. **`/kraft-split`** — Split a branch into stacked MRs with verification
6. **`/kraft-archive`** — Clean up completed worktrees with safety checks

Additional core commands: `/kraft-sync` (pull latest across repos), `/kraft-import` (import remote branches), `/kraft-retro` (post-merge retrospective).

### Workspace Layout

```
workspace/
├── modules/                 Source repositories
├── tasks/TICKET-123/        Isolated git worktrees per ticket
└── docs/specs/TICKET-123/   Planning artifacts (idea.md, spec.md, tasks.md)
```

## Extensions

Each extension is an independent Claude Code plugin that builds on the core. Extensions that implement the provider contract (git hosting, tickets, docs) are automatically discovered at runtime.

### kraftwork-github

GitHub git hosting provider.

| Command | Purpose |
|---------|---------|
| Provider scripts | Clone repos, create PRs, search branches/PRs, CI status |

### kraftwork-gitlab

GitLab CI/CD and merge request management.

| Command | Purpose |
|---------|---------|
| `/glab-mr` | Create, update, and track merge requests |
| `/glab-pipeline` | Check pipeline status and view logs |
| `/glab-review` | Request or assign MR reviews |

### kraftwork-jira

Jira integration for ticket discovery and management.

| Command | Purpose |
|---------|---------|
| `/jira-search` | Find tickets by sprint, status, board, or custom JQL |
| `/jira-ticket` | View ticket details, comments, and transitions |

### kraftwork-clickup

ClickUp task management and team communication.

| Command | Purpose |
|---------|---------|
| `/clickup-search` | Find tasks by list, status, assignee, or name |
| `/clickup-ticket` | View, create, update, transition, or comment on tasks |
| `/clickup-share` | Post updates to Chat channel and task comments |
| `/clickup-sync` | Sync workspace hierarchy into config |

### kraftwork-argocd

ArgoCD application monitoring and debugging.

| Command | Purpose |
|---------|---------|
| `/argocd-status` | Quick health check across environments |
| `/argocd-debug` | Deep debugging with resource status, logs, and events |

### kraftwork-review

Independent code review from multiple perspectives.

| Command | Purpose |
|---------|---------|
| `/fresh-eyes` | Zero-context review of plans, specs, or code |
| `/self-review` | Senior engineer review of your branch diff |
| `/mr-screenshots` | Capture visual output for MR documentation |

### kraftwork-intel

Local-first intelligence layer for metrics and knowledge capture.

| Command | Purpose |
|---------|---------|
| `/intel-report` | View skill usage metrics and session statistics |
| `/intel-store` | Store codebase learnings (architecture, patterns, debugging) |
| `/intel-query` | Semantic search across stored knowledge |
| `/intel-eval` | Run quality evaluations against skills |

Data stays local: SQLite for metrics, LanceDB with local embeddings for knowledge search.

### kraftwork-zellij

Zellij terminal multiplexer integration.

| Command | Purpose |
|---------|---------|
| `/zellij` | Manage sessions, open task tabs, control panes |

## Installation

The marketplace is bundled in this repository. Add it and install plugins with the Claude Code CLI.

### Via marketplace (recommended)

```bash
# Add the marketplace
claude plugin marketplace add https://github.com/filipeestacio/kraftwork.git

# Install core (required)
claude plugin install kraftwork@kraftwork-marketplace

# Install extensions (optional, each requires core)
claude plugin install kraftwork-clickup@kraftwork-marketplace
claude plugin install kraftwork-gitlab@kraftwork-marketplace
claude plugin install kraftwork-intel@kraftwork-marketplace
# ... see plugin list below
```

After installing, restart Claude Code and run `/kraft-config` to set up your workspace.

### Via local path

For development or if you've cloned this monorepo locally:

```bash
claude --plugin-dir /path/to/kraftwork/kraftwork
claude --plugin-dir /path/to/kraftwork/kraftwork-clickup
# ... etc
```

### Nix / Home Manager

If `~/.claude/settings.json` is a read-only symlink (managed by Home Manager), user-scope installs fail with `EACCES`. Use `--scope project` for all installs:

```bash
claude plugin install kraftwork@kraftwork-marketplace --scope project
```

### LLM autonomous installation

Paste this prompt into Claude Code to install automatically:

````
Install the Kraftwork plugin marketplace and plugins for this workspace.

1. Add the marketplace:
   claude plugin marketplace add https://github.com/filipeestacio/kraftwork.git

2. Install the core plugin and any add-ons relevant to this project. Available plugins:
   - kraftwork (core — always install this first)
   - kraftwork-github (GitHub git hosting provider)
   - kraftwork-gitlab (GitLab CI/CD)
   - kraftwork-clickup (ClickUp tickets and docs)
   - kraftwork-jira (Jira integration)
   - kraftwork-intel (local intelligence layer)
   - kraftwork-argocd (ArgoCD debugging)
   - kraftwork-review (code review perspectives)
   - kraftwork-zellij (Zellij multiplexer)
   - presentation (standalone — HTML slideshows)

   Use: claude plugin install <name>@kraftwork-marketplace
   If the install fails with EACCES on ~/.claude/settings.json (common with
   Nix/Home Manager), retry with --scope project.

3. After installing, tell me to restart the session so plugin skills are
   registered, then run /kraft-config to initialize the workspace.
````

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- [Bun](https://bun.sh) — used by helper scripts
- Git with worktree support
- Extension-specific: `gh` (GitHub CLI), `glab` (GitLab CLI), `acli` (Jira CLI), `argocd` (ArgoCD CLI), [Zellij](https://zellij.dev), `CLICKUP_TOKEN` (ClickUp API token)

## Design Principles

- **Spec-driven** — Planning artifacts guide implementation, not the other way around
- **Worktree isolation** — Every ticket gets its own git worktree, keeping branches clean
- **Small MRs** — Work is decomposed into reviewable, independently mergeable chunks
- **Local intelligence** — All metrics and knowledge stored on your machine
- **Safety-first** — Checks for uncommitted changes, unpushed commits, and active worktrees before destructive operations
- **Modular** — Use only the integrations you need
