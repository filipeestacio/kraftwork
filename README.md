<img width="1600" height="679" alt="Kraftwork_banner" src="https://github.com/user-attachments/assets/09164633-434a-4633-92ad-57bd7feebe19" />

# Kraftwork

Opinionated developer workflow orchestration for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Manages the full development lifecycle — from ticket to merge request — through spec-driven planning, git worktree isolation, and modular integrations.

## Quick Start

### Install via Claude Code CLI

```bash
claude plugin marketplace add https://github.com/filipeestacio/kraftwork.git

claude plugin install kraftwork@kraftwork-marketplace
```

Then restart Claude Code and run `/kraft-config` to set up your workspace.

### Install extensions

Pick the ones relevant to your stack:

```bash
claude plugin install kraftwork-gitlab@kraftwork-marketplace   # GitLab CI/CD + merge requests
claude plugin install kraftwork-github@kraftwork-marketplace   # GitHub pull requests
claude plugin install kraftwork-jira@kraftwork-marketplace     # Jira ticket management
claude plugin install kraftwork-clickup@kraftwork-marketplace  # ClickUp tickets + docs
claude plugin install kraftwork-intel@kraftwork-marketplace    # Local knowledge base + metrics
claude plugin install kraftwork-argocd@kraftwork-marketplace   # ArgoCD deployment health
claude plugin install kraftwork-review@kraftwork-marketplace   # Independent code review
claude plugin install kraftwork-zellij@kraftwork-marketplace   # Zellij terminal multiplexer
```

### Let Claude Code install it for you

Copy this entire block into a Claude Code session:

````
Install the Kraftwork plugin marketplace and plugins for this workspace.

1. Add the marketplace:
   claude plugin marketplace add https://github.com/filipeestacio/kraftwork.git

2. Install the core plugin (always required):
   claude plugin install kraftwork@kraftwork-marketplace

3. Then install whichever extensions match this project's tooling. Available:
   - kraftwork-github — GitHub git hosting provider
   - kraftwork-gitlab — GitLab CI/CD and merge requests
   - kraftwork-jira — Jira ticket management
   - kraftwork-clickup — ClickUp tickets and document storage
   - kraftwork-intel — local knowledge base, metrics, and evals
   - kraftwork-argocd — ArgoCD deployment health
   - kraftwork-review — independent code review perspectives
   - kraftwork-zellij — Zellij terminal multiplexer
   - presentation — standalone HTML slideshow generator

   Install with: claude plugin install <name>@kraftwork-marketplace

   If any install fails with EACCES on ~/.claude/settings.json (common with
   Nix / Home Manager), retry with --scope project.

4. After installing, tell me to restart the session so plugin skills are
   registered, then run /kraft-config to initialize the workspace.
````

### Alternative installation methods

**Local path** (for development or if you've cloned this monorepo):

```bash
claude --plugin-dir /path/to/kraftwork/kraftwork
claude --plugin-dir /path/to/kraftwork/kraftwork-gitlab
```

**Nix / Home Manager** — if `~/.claude/settings.json` is a read-only symlink, use `--scope project` for all installs:

```bash
claude plugin install kraftwork@kraftwork-marketplace --scope project
```

## Overview

Kraftwork is a monorepo containing a core plugin and optional extensions, all built as Claude Code plugins. It enforces a structured workflow: plan before you code, isolate work in worktrees, decompose into small reviewable MRs, and capture learnings along the way.

```
kraftwork/              Core workflow plugin with pluggable provider interfaces
kraftwork-github/       GitHub git hosting provider
kraftwork-gitlab/       GitLab CI/CD and merge request provider
kraftwork-jira/         Jira ticket management provider
kraftwork-clickup/      ClickUp ticket management and document storage provider
kraftwork-intel/        Local intelligence — metrics, knowledge, evals (memory provider)
kraftwork-argocd/       ArgoCD deployment health and debugging
kraftwork-review/       Independent code review perspectives
kraftwork-zellij/       Zellij terminal multiplexer control
```

## Core Workflow

The typical development cycle:

1. **`/kraft-config`** — Configure workspace with repos, providers, and directory scaffolding
2. **`/kraft-work TICKET-123`** — Create a git worktree for a ticket, resume existing work, or stack worktrees
3. **`/kraft-plan`** — Brainstorm, create a spec, and decompose work into MR-sized tasks
4. **`/kraft-implement`** — Execute tasks from the spec with change tracking
5. **`/kraft-split`** — Split a branch into stacked MRs with verification
6. **`/kraft-archive`** — Clean up completed worktrees with safety checks

Additional commands: `/kraft-sync` (pull latest across repos), `/kraft-import` (import remote branches), `/kraft-retro` (post-merge retrospective).

### Workspace Layout

```
workspace/
├── modules/                     Source repositories
├── trees/TICKET-123-*/          Isolated git worktrees per ticket
└── docs/specs/TICKET-123/       Planning artifacts (idea.md, spec.md, tasks.md)
```

## Provider Interfaces

Kraftwork uses a provider interface system — the core plugin defines abstract capabilities, and extensions implement them. This means the core workflow commands (`/kraft-work`, `/kraft-plan`, etc.) work the same regardless of whether you use GitHub or GitLab, Jira or ClickUp.

Six interface categories exist:

| Interface | Purpose | Providers |
|-----------|---------|-----------|
| **git-hosting** | Branches, PRs/MRs, repo cloning | kraftwork-github, kraftwork-gitlab |
| **ci** | Pipelines, jobs, logs | kraftwork-gitlab |
| **ticket-management** | Ticket search, creation, status | kraftwork-jira, kraftwork-clickup, local fallback |
| **document-storage** | Document read/write | kraftwork-clickup, local fallback |
| **memory** | Knowledge storage and retrieval | kraftwork-intel, local fallback |
| **messaging** | Notifications and chat | kraftwork-clickup |

`/kraft-config` discovers installed providers and lets you choose one per category. Categories without an installed provider fall back to local implementations (markdown files, filesystem, grep) — except git-hosting and messaging, which are simply skipped.

## Extensions

### kraftwork-github

GitHub git hosting provider. Implements the `git-hosting` interface.

| Skill | Purpose |
|-------|---------|
| `git-hosting-find` | Search branches and pull requests by ticket ID or keyword |
| `git-hosting-describe` | Get PR details, status, approvals, and diff stats |
| `git-hosting-import` | Clone a repository and register it in the workspace |
| `git-hosting-request-review` | Create, update, or check status of pull requests |
| `git-hosting-review` | Review a PR diff with local checkout |

Requires: [`gh`](https://cli.github.com/) (GitHub CLI)

### kraftwork-gitlab

GitLab provider. Implements `git-hosting` and `ci` interfaces.

| Skill | Purpose |
|-------|---------|
| `git-hosting-find` | Search branches and merge requests |
| `git-hosting-describe` | Get MR details, approvals, threads, and diff stats |
| `git-hosting-import` | Clone a repository and register it |
| `git-hosting-request-review` | Create, update, or manage merge requests |
| `git-hosting-review` | Review an MR diff with local checkout |
| `ci-find` | Search pipelines by branch, ticket, or status |
| `ci-describe` | Get pipeline/job details and read logs |
| `ci-watch` | Monitor a pipeline until completion |
| `ci-fix` | Debug a failed pipeline and attempt resolution |
| `ci-retry` | Re-trigger a failed job or pipeline |
| `ci-trigger` | Start a new pipeline run |

Requires: [`glab`](https://gitlab.com/gitlab-org/cli) (GitLab CLI)

### kraftwork-jira

Jira provider. Implements the `ticket-management` interface.

| Skill | Purpose |
|-------|---------|
| `ticket-management-find` | Search tickets by sprint, status, board, assignee, or JQL |
| `ticket-management-describe` | View ticket details, comments, and transitions |
| `ticket-management-create` | Create new tickets |
| `ticket-management-update` | Transition status, edit fields, add comments |

Requires: [`acli`](https://bobswift.atlassian.net/wiki/spaces/ACLI) (Atlassian CLI)

### kraftwork-clickup

ClickUp provider. Implements `ticket-management`, `document-storage`, and `messaging` interfaces.

| Skill | Purpose |
|-------|---------|
| `ticket-management-find` | Search tasks by list, status, assignee, or name |
| `ticket-management-describe` | View task details, comments, and custom fields |
| `ticket-management-create` | Create new tasks |
| `ticket-management-update` | Transition, edit, or comment on tasks |
| `document-storage-find` | Search ClickUp Docs |
| `document-storage-describe` | Read a document |
| `document-storage-create` | Create a new document |
| `document-storage-update` | Update an existing document |

Requires: `CLICKUP_TOKEN` environment variable

### kraftwork-intel

Local-first intelligence layer. Implements the `memory` interface.

| Skill | Purpose |
|-------|---------|
| `/intel-report` | View skill usage metrics and session statistics |
| `/intel-store` | Store codebase learnings (architecture, patterns, debugging) |
| `/intel-query` | Semantic search across stored knowledge |
| `/intel-eval` | Run quality evaluations against skills |

Data stays local: SQLite for metrics, LanceDB with local embeddings for knowledge search.

Optional: [Ollama](https://ollama.com/) with `llama3.2:3b` for LLM-based evals.

### kraftwork-argocd

ArgoCD application monitoring and debugging.

| Skill | Purpose |
|-------|---------|
| `/argocd-status` | Quick health check across environments |
| `/argocd-debug` | Deep debugging with resource status, logs, and events |

Requires: [`argocd`](https://argo-cd.readthedocs.io/en/stable/cli_installation/) CLI

### kraftwork-review

Independent code review from multiple perspectives.

| Skill | Purpose |
|-------|---------|
| `/fresh-eyes` | Zero-context review of plans, specs, or code |
| `/self-review` | Senior engineer review of your branch diff |
| `/mr-screenshots` | Capture UI screenshots for MR documentation |

### kraftwork-zellij

Zellij terminal multiplexer integration.

| Skill | Purpose |
|-------|---------|
| `/zellij` | Manage sessions, open task tabs, control panes |

Requires: [Zellij](https://zellij.dev)

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- [Bun](https://bun.sh) >= 1.3
- Git with worktree support
- `jq` for JSON parsing
- Extension-specific CLIs listed in each extension section above

## Design Principles

- **Spec-driven** — Planning artifacts guide implementation, not the other way around
- **Worktree isolation** — Every ticket gets its own git worktree, keeping branches clean
- **Small MRs** — Work decomposes into reviewable, independently mergeable chunks
- **Provider interfaces** — Swap integrations without changing your workflow
- **Local intelligence** — All metrics and knowledge stored on your machine
- **Safety-first** — Checks for uncommitted changes, unpushed commits, and active worktrees before destructive operations
