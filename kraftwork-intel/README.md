# kraftwork-intel

Local intelligence layer for Kraftwork — metrics, knowledge, and evals.

## Prerequisites

### Required

- **[Bun](https://bun.sh)** >= 1.3 — runtime for the CLI and hooks
  ```sh
  curl -fsSL https://bun.sh/install | bash
  ```

- **kraftwork-intel CLI** installed at `~/.claude/kraftwork-intel/`
  ```sh
  git clone https://gitlab.com/filipe.estacio/kraftwork-intel-cli.git ~/.claude/kraftwork-intel
  cd ~/.claude/kraftwork-intel && bun install
  ```

### Optional (for eval LLM scoring)

- **[Ollama](https://ollama.com)** with the `llama3.2:3b` model
  ```sh
  brew install ollama
  ollama pull llama3.2:3b
  ```
  Without Ollama, evals still run using heuristic scorers only.

## What It Does

### Passive Data Collection (Hooks)

The plugin registers four Claude Code hooks that run automatically:

| Hook | Trigger | Records |
|------|---------|---------|
| `SessionStart` | Claude Code launches | Session start event with project context |
| `UserPromptSubmit` | You send a prompt | Your prompt as a session interaction |
| `PostToolUse` | A skill is invoked | Skill name and invocation metadata |
| `Stop` | Claude Code responds | Agent response on the last interaction |

All data is stored locally at `~/.claude/kraftwork-intel/data/metrics.db` (SQLite).

### Active Skills

| Skill | Purpose |
|-------|---------|
| `/intel-report` | Show skill usage metrics and session statistics |
| `/intel-store` | Store a codebase learning (architecture, patterns, debugging insights) |
| `/intel-query` | Search the knowledge base by semantic similarity |
| `/intel-eval` | Run quality evaluations against skills using recorded interactions |

### Knowledge Store

Codebase learnings are stored in a LanceDB vector database at `~/.claude/kraftwork-intel/data/knowledge/`. Embeddings are generated locally using `all-MiniLM-L6-v2` (384-dim) via `@huggingface/transformers` — no API keys or cloud calls.

### Eval Runner

Evaluates skill quality using two scoring methods:

- **Heuristic scorers** — response length, clarifying questions, TDD adherence, comment discipline
- **LLM scorer** (optional) — Ollama `llama3.2:3b` as a local judge against a rubric

## Data Storage

All data lives outside any git repo:

```
~/.claude/kraftwork-intel/data/
├── metrics.db      # SQLite — sessions, interactions, skill invocations, eval results
└── knowledge/      # LanceDB — vector store for codebase learnings
```

## CLI Reference

The backing CLI at `~/.claude/kraftwork-intel/` supports direct usage:

```sh
cd ~/.claude/kraftwork-intel

# Metrics
bun run src/cli.ts report                          # Usage summary
bun run src/cli.ts report --days 7                  # Last 7 days

# Knowledge
bun run src/cli.ts store --content "..." --category architecture
bun run src/cli.ts query --query "how does X work"
bun run src/cli.ts query --query "..." --category patterns --limit 5

# Evals
bun run src/cli.ts eval --skill kraft-start     # Eval one skill
bun run src/cli.ts eval --all                        # Eval all recorded skills
bun run src/cli.ts eval --flagged                    # Eval skills with <70% success rate
bun run src/cli.ts eval --skill X --llm              # Include Ollama LLM scoring
```

## Architecture

```
Plugin (this repo)          CLI (~/.claude/kraftwork-intel/)
├── hooks/hooks.json        ├── src/
│   SessionStart ──────────►│   ├── hooks/session-start.ts
│   UserPromptSubmit ──────►│   ├── hooks/user-prompt.ts
│   PostToolUse ───────────►│   ├── hooks/post-tool.ts
│   Stop ──────────────────►│   ├── hooks/stop.ts
├── skills/                 │   ├── metrics/store.ts
│   intel-report ──────────►│   ├── knowledge/store.ts
│   intel-store ───────────►│   ├── evals/runner.ts
│   intel-query ───────────►│   └── cli.ts
│   intel-eval ────────────►│
└── .claude-plugin/         └── data/
    plugin.json                 ├── metrics.db
                                └── knowledge/
```

The plugin is a thin shell — hooks and skills invoke `bun run` against the CLI source. All logic lives in the CLI repo.

## Running Tests

```sh
cd ~/.claude/kraftwork-intel
bun test
```

49 tests across metrics, knowledge, hooks, and eval modules.
