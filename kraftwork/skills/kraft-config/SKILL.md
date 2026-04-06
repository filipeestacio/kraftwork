---
name: kraft-config
description: Provider-aware workspace configuration wizard — idempotent and incremental.
---

# Workspace Config

Set up or reconfigure a development workspace by discovering installed providers, collecting provider-specific config, and scaffolding the workspace directory structure.

## Prerequisites

- `jq` for JSON parsing
- `git` installed

## Script Paths

**IMPORTANT:** Derive the scripts directory from this skill file's location:
- This skill file: `kraftwork/skills/kraft-config/SKILL.md`
- Workspace plugin root: 3 directories up from this file
- Scripts directory: `<workspace-root>/scripts/`

When you load this skill, note its file path and compute the scripts directory. For example, if this skill is at `/path/to/kraftwork/skills/kraft-config/SKILL.md`, then scripts are at `/path/to/kraftwork/scripts/`.

## Phase 1 — Provider Discovery

### Step 1: Read Enabled Plugins

Read `~/.claude/settings.json` and extract the `enabledPlugins` object. Keys are formatted as `pluginName@marketplace`, values are booleans. If `enabledPlugins` is absent, treat all cached plugins as enabled.

```sh
SETTINGS="$HOME/.claude/settings.json"
CACHE_DIR="$HOME/.claude/plugins/cache"

ENABLED_PLUGINS=$(jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$SETTINGS")
```

### Step 2: Collect Provider Declarations

For each enabled `kraftwork-*` plugin, check for a `providers.json` at:

```
~/.claude/plugins/cache/<marketplace>/<pluginName>/<version>/providers.json
```

The `<version>` directory is whichever single directory exists under the plugin name.

```sh
PROVIDERS_BY_CATEGORY=()
for ENTRY in $ENABLED_PLUGINS; do
  PLUGIN_NAME="${ENTRY%%@*}"
  MARKETPLACE="${ENTRY##*@}"

  # Only process kraftwork-* plugins
  [[ "$PLUGIN_NAME" == kraftwork-* ]] || continue

  PLUGIN_DIR="$CACHE_DIR/$MARKETPLACE/$PLUGIN_NAME"
  [ -d "$PLUGIN_DIR" ] || continue

  VERSION_DIR=$(ls -1 "$PLUGIN_DIR" | head -1)
  PROVIDERS_FILE="$PLUGIN_DIR/$VERSION_DIR/providers.json"

  if [ -f "$PROVIDERS_FILE" ]; then
    echo "Found providers: $PLUGIN_NAME ($PROVIDERS_FILE)"
  fi
done
```

Parse each `providers.json` and collect provider declarations grouped by category. A `providers.json` lists which categories a plugin handles, for example:

```json
[
  { "category": "git-hosting", "plugin": "kraftwork-gitlab" },
  { "category": "ticket-management", "plugin": "kraftwork-jira" }
]
```

### Step 3: Select Providers Per Category

The six categories are: `git-hosting`, `ci`, `ticket-management`, `document-storage`, `memory`, `messaging`.

Each category has different fallback behaviour when the user has no external provider:

| Category | Local fallback | Fallback provider |
|---|---|---|
| `ticket-management` | Full — markdown files in workspace | `kraftwork-local` |
| `document-storage` | Full — filesystem under workspace | `kraftwork-local` |
| `memory` | Degraded — markdown files, grep-based recall | `kraftwork-local` |
| `ci` | Partial — local test/build commands | `kraftwork-local` |
| `git-hosting` | None — category skipped | (omitted from workspace.json) |
| `messaging` | None — category skipped | (omitted from workspace.json) |

For each category:

- **One provider available** (from discovered plugins): auto-select it, inform the user.
- **Multiple providers available**: ask the user which to use. List the options by plugin name.
- **No providers discovered + fallback exists**: offer `kraftwork-local` or skip. Explain what the local fallback provides.
- **No providers discovered + no fallback**: inform the user the category will be skipped. The orchestrator degrades gracefully.
- **User says "I don't have one" + fallback exists**: auto-select `kraftwork-local`.
- **User says "I don't have one" + no fallback**: skip the category.

Always include `kraftwork-local` as an explicit option for categories that support it.

## Phase 1.5 — Dependency Validation

### Step 3.5: Check Required Dependencies

Kraftwork requires the `superpowers` plugin. Check that it is installed and enabled:

```sh
SUPERPOWERS_INSTALLED=$(echo "$ENABLED_PLUGINS" | grep -c "^superpowers@" || true)

if [ "$SUPERPOWERS_INSTALLED" -eq 0 ]; then
  echo "WARNING: The 'superpowers' plugin is required by Kraftwork but is not installed."
  echo "Install it with: claude plugin install superpowers"
  echo ""
  echo "Kraftwork uses superpowers for brainstorming, planning, TDD, and debugging workflows."
  echo "You can continue setup, but orchestrator skills will not function correctly without it."
fi
```

Warn but do not block — the user may install it later.

## Phase 2 — Provider Configuration

### Step 4: Collect Provider-Specific Config

For each selected provider that is not `kraftwork-local`:

1. Locate its `config/workspace-config.json`:

```sh
PLUGIN_DIR="$CACHE_DIR/$MARKETPLACE/$PLUGIN_NAME"
VERSION_DIR=$(ls -1 "$PLUGIN_DIR" | head -1)
SCHEMA_FILE="$PLUGIN_DIR/$VERSION_DIR/config/workspace-config.json"
```

2. If the schema exists, present each field to the user using the `prompt` text as conversational guidance and `example` as illustration.

3. Collect responses and store them internally — provider config is handled by the extension, not written to workspace.json.

Field type handling:

- **`string` fields:** Ask and accept a single value.
- **`boolean` fields:** Ask as a yes/no question.
- **`string[]` fields:** Accept comma-separated values or one at a time.
- **Optional fields** (`required: false` or `required` absent): Accept blank/skip. If skipped, omit the field entirely — do not write null.

## Phase 3 — Core Configuration

### Step 5: Collect Workspace Settings

Read the core workspace schema from this skill's plugin root at `config/workspace-config.json`. Prompt for each field defined there:

- `workspace.name` — the workspace name
- `workspace.path` — the workspace root directory

Infer a smart default for path from the current directory:

```sh
echo "Current directory: $(pwd)"
```

## Phase 4 — Scaffold Workspace

### Step 6: Preview and Confirm

Assemble the full workspace.json and show a preview before writing:

```
Here is the workspace.json that will be written:

{
  "configVersion": 3,
  "workspace": { ... },
  "providers": {
    "git-hosting": "kraftwork-gitlab",
    "ci": "kraftwork-local",
    "ticket-management": "kraftwork-jira",
    "document-storage": "kraftwork-local",
    "memory": "kraftwork-local"
  }
}

Does this look right?
```

Categories not configured will be omitted from the providers object.

Wait for confirmation. If the user requests changes, re-prompt for the specific fields they want to adjust.

### Step 7: Write workspace.json

Write workspace.json with `"configVersion": 3` as the first key, at the workspace root path. The `providers` object maps each configured category to its plugin name as a plain string. Omit unconfigured categories entirely.

### Step 8: Create Directory Structure

```sh
WORKSPACE=$(jq -r '.workspace.path' workspace.json)
WORKSPACE="${WORKSPACE/#\~/$HOME}"

# Initialise as git repo if not already one
git -C "$WORKSPACE" rev-parse --git-dir 2>/dev/null || git init "$WORKSPACE"

mkdir -p "$WORKSPACE/modules"
mkdir -p "$WORKSPACE/trees"

# .gitignore with trees/ entry
if [ ! -f "$WORKSPACE/.gitignore" ]; then
  echo "trees/" > "$WORKSPACE/.gitignore"
elif ! grep -q "^trees/$" "$WORKSPACE/.gitignore"; then
  echo "trees/" >> "$WORKSPACE/.gitignore"
fi
```

Do NOT create `docs/` — it is created lazily by the document storage provider on first use.

## Phase 5 — Clone Repositories

### Step 9: Clone Into modules/

This phase runs only when git-hosting is configured in workspace.json.

```sh
GIT_PROVIDER=$(jq -r '.providers["git-hosting"] // empty' workspace.json)
```

If configured, ask the user which repositories to clone. For each repo:

1. Skip if `$WORKSPACE/modules/<repo>` already exists.
2. Invoke `{git-hosting}:git-hosting-import` with the repo name and target path `$WORKSPACE/modules/<repo>`.

If no git-hosting provider is configured, skip this phase and inform the user they can clone repos manually into `modules/`.

## Phase 6 — Generate CLAUDE.md

### Step 10: Write Workspace CLAUDE.md

If `$WORKSPACE/CLAUDE.md` does not already exist, generate it with:

- A heading using the workspace name
- The directory structure (`modules/`, `trees/`, `docs/`)
- A brief description of each directory's purpose
- The provider configuration summary (which plugin is selected per category)
- A modules table listing any cloned repos

All values must come from workspace.json. Do not hardcode any company name, URLs, or repository names.

## Phase 6.5 — Plugin-Specific Setup

### Step 11: Set Up kraftwork-intel CLI

This step runs whenever `kraftwork-intel` is installed, regardless of whether it is the selected memory provider.

```sh
INTEL_INSTALLED=$(echo "$ENABLED_PLUGINS" | grep -c "^kraftwork-intel@" || true)
```

If `INTEL_INSTALLED` is greater than 0:

1. **Locate the installed plugin path:**

```sh
INTEL_PLUGIN=$(echo "$ENABLED_PLUGINS" | grep "^kraftwork-intel@")
MARKETPLACE="${INTEL_PLUGIN##*@}"
PLUGIN_DIR="$CACHE_DIR/$MARKETPLACE/kraftwork-intel"
VERSION_DIR=$(ls -1 "$PLUGIN_DIR" | head -1)
INTEL_PATH="$PLUGIN_DIR/$VERSION_DIR"
```

2. **Install dependencies:**

```sh
cd "$INTEL_PATH" && bun install
```

If `bun install` fails, inform the user and stop: `"kraftwork-intel requires bun >= 1.3. Install from https://bun.sh"`

3. **Run the dependency check:**

```sh
bun run "$INTEL_PATH/src/cli.ts" check
```

If the check exits non-zero, surface the failure to the user before continuing.

4. **Write the wrapper script:**

```sh
mkdir -p "$HOME/.claude/kraftwork-intel"
cat > "$HOME/.claude/kraftwork-intel/cli" <<EOF
#!/bin/sh
exec bun run "$INTEL_PATH/src/cli.ts" "\$@"
EOF
chmod +x "$HOME/.claude/kraftwork-intel/cli"
echo "✓ kraftwork-intel CLI registered at ~/.claude/kraftwork-intel/cli"
```

If `~/.claude/kraftwork-intel/cli` already exists (re-run), overwrite it silently — the plugin path may have changed.

## Idempotent Re-run (Delta Mode)

### Step 12: Delta Mode Logic

If `workspace.json` already exists:

1. Read the existing workspace.json.
2. Check `configVersion`:
   - **Version 2 or below:** Inform the user that the workspace format has changed. Offer to migrate:
     - Convert `providers.<category>.plugin` format to `providers.<category>` (direct string)
     - Add any new categories discovered from installed plugins
     - Bump to `configVersion: 3`
   - **Version 3:** Proceed with normal delta checks.
3. Check for new `kraftwork-*` plugins that have appeared since the last run.
4. For each of the six categories, check if a new provider is available that was not previously configured. Offer to add it.
5. Preserve all existing config — only add or update keys. Never remove existing keys or sections.

If nothing is missing or changed, report "Config up to date" and exit.

## Error Handling

- **Missing providers.json:** Skip that plugin silently. It may not declare any providers.
- **Schema parse failures:** Report the plugin name and file path. Skip that schema and continue.
- **Directory already exists:** Skip creation, continue.
- **Clone failures:** Continue with remaining repos. Report all failures at the end.
- **workspace.json write failure:** Report the error and show the JSON that would have been written so the user can save it manually.

## Completion

After all phases, show a summary:

```
Workspace configured at $WORKSPACE

Providers:
  <category>:  <plugin>   (one line per configured category)

Skipped: <comma-separated list of unconfigured categories, or "none">

Structure:
  $WORKSPACE/
  ├── modules/    (<N> repos)
  ├── trees/      (git worktrees — gitignored)
  └── docs/       (created on first use by document storage provider)

Next steps:
1. cd "$WORKSPACE"
2. Run /kraft-work TICKET-123 to begin work on a ticket
3. Run /kraft-sync to update all repos
```
