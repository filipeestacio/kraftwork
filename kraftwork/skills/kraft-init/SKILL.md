---
name: kraft-init
description: Initialize a development workspace with configuration wizard and repository cloning.
---

# Workspace Init

Set up a new development workspace with a configuration wizard, directory scaffolding, and repository cloning.

## Prerequisites

- `git` with SSH access to your git host
- `glab` CLI authenticated (for GitLab hosts) or `gh` CLI authenticated (for GitHub hosts)
- `jq` for JSON parsing

## Script Paths

**IMPORTANT:** Derive the scripts directory from this skill file's location:
- This skill file: `kraftwork/skills/kraft-init/SKILL.md`
- Workspace plugin root: 3 directories up from this file
- Scripts directory: `<workspace-root>/scripts/`

When you load this skill, note its file path and compute the scripts directory. For example, if this skill is at `/path/to/kraftwork/skills/kraft-init/SKILL.md`, then scripts are at `/path/to/kraftwork/scripts/`.

## Phase 1 — Configuration Wizard

### Step 1: Discover Schemas

Read `~/.claude/settings.json` and extract the `enabledPlugins` object. The keys are formatted as `pluginName@marketplace`. If the `enabledPlugins` key is absent from settings.json, treat all cached plugins as enabled.

For each enabled plugin (where the value is `true`), check whether this file exists:

```
~/.claude/plugins/cache/<marketplace>/<pluginName>/<version>/config/workspace-config.json
```

The `<version>` directory is whatever single directory exists under the plugin name (e.g., `1.0.0`).

```sh
SETTINGS="$HOME/.claude/settings.json"
CACHE_DIR="$HOME/.claude/plugins/cache"

ENABLED_PLUGINS=$(jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$SETTINGS")

SCHEMAS=()
for ENTRY in $ENABLED_PLUGINS; do
  PLUGIN_NAME="${ENTRY%%@*}"
  MARKETPLACE="${ENTRY##*@}"
  PLUGIN_DIR="$CACHE_DIR/$MARKETPLACE/$PLUGIN_NAME"
  if [ -d "$PLUGIN_DIR" ]; then
    VERSION_DIR=$(ls -1 "$PLUGIN_DIR" | head -1)
    SCHEMA_FILE="$PLUGIN_DIR/$VERSION_DIR/config/workspace-config.json"
    if [ -f "$SCHEMA_FILE" ]; then
      echo "Found schema: $PLUGIN_NAME ($SCHEMA_FILE)"
    fi
  fi
done
```

Read each discovered schema file. If the content is a JSON object (not an array), wrap it in an array. If it is already an array, use it as-is. Collect all section definitions into a single list, tracking which plugin each section came from.

### Step 2: Check for Section Conflicts

Group all collected sections by their `section` field. If any section name appears from two different plugins, present this to the user:

> Both `<plugin-a>` and `<plugin-b>` declare the `<section>` config section. Which should be used? (The other plugin's skills that need this section will not work.)

Recommend disabling the unused plugin. Wait for the user to choose before continuing. Drop the unchosen plugin's section from the collected list.

### Step 3: Determine Wizard Mode

Determine which mode to run:

- If the user said "reconfigure" or passed `--reconfigure`: **full wizard mode** (existing values shown as defaults).
- Else if `workspace.json` exists at the target workspace root: **delta mode**.
- Else: **full wizard mode**.

To locate the target workspace root for the existence check: if there is an existing `workspace.json` in the current working directory or any parent, use that. Otherwise, the workspace root will be determined during the wizard.

### Step 4: Delta Mode

Run this step only when workspace.json already exists and the user did not request reconfigure.

Read the existing `workspace.json`. For each section in the collected schemas:

1. If the section key is absent from workspace.json, prompt the user for all fields in that section.
2. If the section key exists, check each field where `required` is `true`. If any required field's key is absent from the section object, prompt for just that missing field.
3. If all required fields are present, skip the section silently.

If nothing is missing across all sections, report "Config up to date" and proceed to Phase 2.

When writing the updated config, preserve all existing sections in workspace.json — including orphaned sections from previously uninstalled plugins. Only add or update keys. Never remove existing keys or sections.

Write the updated workspace.json and proceed to Phase 2.

### Step 5: Full Wizard Mode

Run this step when no workspace.json exists or the user requested reconfigure.

Present sections in this order: `workspace` first, `git` second, then all remaining sections sorted alphabetically by section name.

For each section:

1. Announce the section title and description from the schema.
2. For each field in the section, use the `prompt` text as conversational guidance and the `example` as illustration.

Field type handling:

- **`string` fields:** Ask and accept a single value.
- **`boolean` fields:** Ask as a yes/no question.
- **`string[]` fields:** Ask the user to list items. They can provide comma-separated values or list them one at a time. Use the `prompt` to guide what kind of list is expected.
- **Optional fields** (`required: false` or `required` absent): Ask, but accept blank/skip. If skipped, omit the field from workspace.json entirely — do not write null.

Infer smart defaults where possible:

```sh
# Detect current directory as potential workspace path
echo "Detected: $(pwd)"

# Check git remote in any sources/ repo for host and group
REMOTE_URL=$(git -C "$WORKSPACE/sources/$(ls "$WORKSPACE/sources/" 2>/dev/null | head -1)" remote get-url origin 2>/dev/null || true)
```

Parse the remote URL to suggest git host and group if detectable.

If reconfiguring, show existing values from the previous workspace.json as defaults for each field. The user can press enter to keep the existing value or type a new one.

After collecting all sections, assemble the full workspace.json and show a preview:

```
Here is the workspace.json that will be written:

{
  "configVersion": 1,
  "workspace": { ... },
  "git": { ... },
  ...
}

Does this look right?
```

Wait for the user to confirm before writing. If the user requests changes, re-prompt for the specific fields they want to adjust.

Write workspace.json with `"configVersion": 1` as the first key. When reconfiguring, preserve any orphaned sections from the previous file that are not covered by current schemas.

## Phase 2 — Scaffold

### Step 6: Create Directory Structure

Read the workspace path from the config:

```sh
WORKSPACE=$(jq -r '.workspace.path' workspace.json)
WORKSPACE="${WORKSPACE/#\~/$HOME}"
```

Create the standard directory structure:

```sh
mkdir -p "$WORKSPACE/sources"
mkdir -p "$WORKSPACE/tasks"
mkdir -p "$WORKSPACE/docs/specs"
mkdir -p "$WORKSPACE/docs/plans"
mkdir -p "$WORKSPACE/docs/lessons"
```

### Step 7: Clone Repositories

Read clone parameters from workspace.json:

```sh
GIT_HOST=$(jq -r '.git.host' workspace.json)
GIT_GROUP=$(jq -r '.git.group' workspace.json)
REPOS=$(jq -r '.git.repos[]' workspace.json)
```

For each repo, skip if the target directory already exists under `$WORKSPACE/sources/`. Otherwise clone using the appropriate tool:

- **gitlab:** `glab repo clone "$GIT_GROUP/$REPO" "$WORKSPACE/sources/$REPO"`
- **github:** `gh repo clone "$GIT_GROUP/$REPO" "$WORKSPACE/sources/$REPO"`
- **other hosts:** `git clone "git@$GIT_HOST:$GIT_GROUP/$REPO.git" "$WORKSPACE/sources/$REPO"`

```sh
for REPO in $REPOS; do
  TARGET="$WORKSPACE/sources/$REPO"
  if [ -d "$TARGET" ]; then
    echo "Skipping $REPO (already exists)"
    continue
  fi
  echo "Cloning $REPO..."
  case "$GIT_HOST" in
    gitlab) glab repo clone "$GIT_GROUP/$REPO" "$TARGET" ;;
    github) gh repo clone "$GIT_GROUP/$REPO" "$TARGET" ;;
    *) git clone "git@$GIT_HOST:$GIT_GROUP/$REPO.git" "$TARGET" ;;
  esac
done
```

### Step 8: Run Post-Install Scripts

Check if the workspace plugin ships `config/repo-setup.json`. If it exists, read it and execute any post-clone setup commands for each repository (unchanged mechanism from previous implementation).

### Step 9: Generate CLAUDE.md

If `$WORKSPACE/CLAUDE.md` does not already exist, generate it from the config values in workspace.json.

Read these values:

```sh
WS_NAME=$(jq -r '.workspace.name' workspace.json)
GIT_HOST=$(jq -r '.git.host' workspace.json)
GIT_GROUP=$(jq -r '.git.group' workspace.json)
REPOS=$(jq -r '.git.repos | join(", ")' workspace.json)
```

Generate CLAUDE.md with:

- A heading using the workspace name
- The directory structure (sources/, tasks/, docs/ with subdirectories)
- Workflow descriptions for each directory
- A configuration section listing the git host, group, and repo names
- A repos table built from the repos list

All values must come from workspace.json. Do not hardcode any company name, URLs, or repository names.

## Phase 3 — Completion

### Step 10: Output Summary

Show the workspace structure with repo count:

```sh
CLONED_COUNT=$(ls -1 "$WORKSPACE/sources" 2>/dev/null | wc -l | tr -d ' ')
```

```
Workspace initialized at $WORKSPACE

Structure:
  $WORKSPACE/
  ├── sources/       ($CLONED_COUNT repos cloned)
  ├── tasks/         (ready for worktrees)
  └── docs/
      ├── specs/     (ready for ticket specs)
      ├── plans/     (ready for design docs)
      └── lessons/   (ready for learnings)

Next steps:
1. cd "$WORKSPACE"
2. Run /kraft-start TICKET-123 to begin work on a ticket
3. Run /kraft-sync to update all repos
```

## Error Handling

- **Git CLI not authenticated:** Provide the appropriate login command (`glab auth login` or `gh auth login`).
- **Clone failures:** Continue with remaining repos. Report all failures at the end.
- **Directory exists:** Skip and continue. Do not overwrite.
- **Schema parse failures:** Report the plugin name and file path. Skip that schema and continue with the rest.
