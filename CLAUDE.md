# kraftwork — development guide

Monorepo of Claude Code plugins for developer workflow orchestration. Each subdirectory is an independently installable plugin.

## Repo Structure

```
kraftwork/              Core workflow plugin — kraft-config, kraft-work, kraft-plan, etc.
kraftwork-github/       GitHub git-hosting provider
kraftwork-gitlab/       GitLab git-hosting + ci provider
kraftwork-jira/         Jira ticket-management provider
kraftwork-clickup/      ClickUp ticket-management + document-storage provider
kraftwork-slack/        Slack messaging provider
kraftwork-intel/        Memory provider — SQLite metrics, LanceDB knowledge, skill evals
kraftwork-argocd/       ArgoCD deployment health (no provider interface)
kraftwork-review/       Code review skills (no provider interface)
kraftwork-zellij/       Zellij terminal control (no provider interface)
kraftwork-template/     Scaffold for new provider plugins
.claude-plugin/         Marketplace definition (marketplace.json)
```

## Versioning Rules

Every change that affects plugin behaviour **must** be accompanied by a version bump — otherwise consumers who have already installed the plugin will not pick up the change.

1. Edit the plugin's `.claude-plugin/plugin.json` — bump `version`.
2. Edit `.claude-plugin/marketplace.json` — bump the matching plugin entry's `version` to the same value.
3. Both changes go in the same commit as the behaviour change.

Patch bump (x.y.**Z**) for bug fixes and docs. Minor bump (x.**Y**.0) for new skills, new config fields, or changed behaviour.

## Provider Interface Pattern

Provider plugins declare their category in `providers.json` at the plugin root. kraft-config reads this to discover what each plugin offers.

```json
{
  "providers": [
    { "category": "git-hosting", "skills": ["find", "describe", "import", "request-review", "review"] }
  ]
}
```

Skill names in `providers.json` are suffixes — the full skill name is `<category>-<skill>` (e.g., `git-hosting-find`).

Each provider plugin can also include:
- `config/workspace-config.json` — fields kraft-config prompts for during setup
- `config/claude-md-fragment.md` — behavioral guidance appended to the workspace CLAUDE.md

## Tests

Only `kraftwork-intel` has an automated test suite:

```sh
cd kraftwork-intel && bun test
```

25 tests across metrics, knowledge, hooks, and eval modules. Run before committing changes to `kraftwork-intel/src/`.

## kraftwork-intel CLI

The CLI at `kraftwork-intel/src/cli.ts` is bundled with the plugin. It self-registers a wrapper at `~/.claude/kraftwork-intel/cli` on the first Claude Code session start after install — no manual setup needed.

To test the CLI locally against the installed plugin:
```sh
~/.claude/kraftwork-intel/cli check
~/.claude/kraftwork-intel/cli report
```
