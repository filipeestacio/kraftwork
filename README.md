# Kraftwork

Opinionated developer workflow orchestration for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Manages the full development lifecycle — from ticket to merge request — through spec-driven planning, git worktree isolation, and modular integrations.

## Overview

Kraftwork is a monorepo containing a core plugin and optional extensions, all built as Claude Code plugins. It enforces a structured workflow: plan before you code, isolate work in worktrees, decompose into small reviewable MRs, and capture learnings along the way.

```
kraftwork/              Core workflow plugin
kraftwork-argocd/       ArgoCD deployment health and debugging
kraftwork-clickup/      ClickUp task management and team communication
kraftwork-gitlab/       GitLab CI/CD and merge request workflows
kraftwork-intel/        Local intelligence layer — metrics, knowledge, evals
kraftwork-jira/         Jira ticket search and management
kraftwork-review/       Independent code review perspectives
kraftwork-zellij/       Zellij terminal multiplexer control
```

## Core Workflow

The typical development cycle follows this path:

1. **`/kraft-init`** — Initialize workspace with repos, config, and directory scaffolding
2. **`/kraft-start TICKET-123`** — Create a git worktree for a ticket, auto-discovering the target repo
3. **`/kraft-plan`** — Brainstorm, create a spec, and decompose work into MR-sized tasks
4. **`/kraft-implement`** — Execute tasks from the spec with change tracking
5. **`/kraft-resume`** — List active worktrees and pick up where you left off
6. **`/kraft-split`** — Split a branch into stacked MRs with verification
7. **`/kraft-archive`** — Clean up completed worktrees with safety checks

Additional core commands: `/kraft-stack` (dependent worktrees), `/kraft-sync` (pull latest across repos), `/kraft-import` (import remote branches), `/kraft-retro` (post-merge retrospective).

### Workspace Layout

```
workspace/
├── sources/                 Read-only reference repositories
├── tasks/TICKET-123/        Isolated git worktrees per ticket
└── docs/specs/TICKET-123/   Planning artifacts (idea.md, spec.md, tasks.md)
```

## Extensions

Each extension is an independent Claude Code plugin that builds on the core.

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

Each module is a Claude Code plugin. Install them by adding the plugin directories to your Claude Code configuration:

```bash
# Core (required)
claude plugins add /path/to/kraftwork/kraftwork

# Extensions (optional, each requires core)
claude plugins add /path/to/kraftwork/kraftwork-gitlab
claude plugins add /path/to/kraftwork/kraftwork-jira
claude plugins add /path/to/kraftwork/kraftwork-clickup
claude plugins add /path/to/kraftwork/kraftwork-argocd
claude plugins add /path/to/kraftwork/kraftwork-review
claude plugins add /path/to/kraftwork/kraftwork-intel
claude plugins add /path/to/kraftwork/kraftwork-zellij
```

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- [Bun](https://bun.sh) — used by helper scripts
- Git with worktree support
- Extension-specific: `glab` (GitLab CLI), `acli` (Jira CLI), `argocd` (ArgoCD CLI), [Zellij](https://zellij.dev), `CLICKUP_TOKEN` (ClickUp API token)

## Design Principles

- **Spec-driven** — Planning artifacts guide implementation, not the other way around
- **Worktree isolation** — Every ticket gets its own git worktree, keeping branches clean
- **Small MRs** — Work is decomposed into reviewable, independently mergeable chunks
- **Local intelligence** — All metrics and knowledge stored on your machine
- **Safety-first** — Checks for uncommitted changes, unpushed commits, and active worktrees before destructive operations
- **Modular** — Use only the integrations you need
