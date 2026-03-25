---
name: clickup-sync
description: Use when syncing ClickUp workspace hierarchy (spaces, folders, lists) into workspace.json, or when config is stale or missing spaces/lists
---

# ClickUp Sync

## Setup

Derive `SCRIPT_DIR` as `../../scripts` relative to this SKILL.md file (i.e., `kraftwork-clickup/scripts`).

Read `workspace.json` from the workspace root. Extract the `clickup` section. If the `clickup` section is missing, tell the user:

```
No ClickUp configuration found in workspace.json. Run /kraft-init to set it up.
```

From the `clickup` section, extract:
- `teamId` — the ClickUp workspace/team ID
- `token_env` — the environment variable name holding the API token
- `defaultList` — the current default list key (if set)
- `spaces` — the current spaces map (if any)
- `chatChannelId` — (preserve as-is, do not modify)

## Auth

Do NOT pre-check authentication. Run the intended operation directly. Handle auth errors as they occur:

- If `token_env` is unset in the environment: report "Set `<token_env>` with your ClickUp API token."
- If the API returns 401: report "ClickUp API returned unauthorized — check that `<token_env>` contains a valid token."

---

## Interactive Flow

### Phase 1: Fetch All Spaces

Run:

```bash
bun run "$SCRIPT_DIR/clickup-api.ts" list-spaces
```

The command outputs JSON: `{ "ok": true, "data": { "spaces": [...] } }`

Each space has: `id`, `name`, and optionally other metadata.

If `ok` is false or the spaces array is empty:
```
No spaces found in this workspace. Check that `teamId` is correct.
```

### Phase 2: Present Spaces With Config State

Compare the fetched spaces against the current `clickup.spaces` in `workspace.json`. For each space, determine its state:

- **new** — exists in ClickUp but not in the current config
- **existing** — exists in both ClickUp and the current config
- **removed** — exists in the current config but was NOT returned by the API (no longer in ClickUp)

Present the spaces to the user:

```
ClickUp Spaces:

  [existing] admin-portal    → "Admin Portal"   (id: abc123)
  [new]      engineering     → "Engineering"     (id: def456)
  [removed]  legacy-ops      → "Legacy Ops"      (not in ClickUp)

Which spaces should be included in your config?
Enter space numbers to toggle, or press Enter to confirm:
```

Slugify space names for config keys (e.g., "Admin Portal" → `admin-portal`). Slugification rules: lowercase, replace spaces and special characters with hyphens, collapse consecutive hyphens.

### Phase 3: User Selects Spaces

Wait for the user to confirm their selection. The default selection is:
- All **existing** spaces are pre-selected.
- **New** spaces are pre-selected (user can deselect).
- **Removed** spaces are NOT selected by default.

### Phase 4: Fetch Hierarchy for Selected Spaces

For each selected space, run the following in sequence:

**Fetch folders:**
```bash
bun run "$SCRIPT_DIR/clickup-api.ts" list-folders --space <id>
```

Output: `{ "ok": true, "data": { "folders": [...] } }`

**For each folder, fetch its lists:**
```bash
bun run "$SCRIPT_DIR/clickup-api.ts" list-lists --folder <id>
```

Output: `{ "ok": true, "data": { "lists": [...] } }`

**Fetch folderless lists (lists directly under the space, not in any folder):**
```bash
bun run "$SCRIPT_DIR/clickup-api.ts" list-folderless-lists --space <id>
```

Output: `{ "ok": true, "data": { "lists": [...] } }`

If any individual fetch fails, report the error for that specific space and continue with the remaining spaces:
```
Warning: Failed to fetch folders for space "Engineering" — <error message>. Skipping.
```

### Phase 5: Present Full Tree With Selection State

Display the complete hierarchy for all selected spaces. Compare each list against the current config to determine its state (new/existing/removed). All lists are pre-selected by default.

```
Workspace Hierarchy:

  [✓] Admin Portal (existing)
      Folders:
        [✓] Projects
            [✓] active-projects     → "Active Projects"   (existing)
            [✓] backlog             → "Backlog"            (new)
        [✓] Operations
            [✓] ops-tasks           → "Ops Tasks"          (existing)
      Folderless Lists:
            [✓] general             → "General"            (existing)

  [✓] Engineering (new)
      Folders:
        [✓] Backend
            [✓] api-work            → "API Work"           (new)
      Folderless Lists:
            [✓] eng-general         → "Eng General"        (new)

Deselect any lists you don't want to include (e.g., "3", "5"), or press Enter to confirm all:
```

### Phase 6: User Confirms or Deselects

Wait for user input. Allow deselecting individual lists by number or name. Once the user confirms, proceed.

### Phase 7: Show Diff Against Current Config

Before writing, show a clear diff:

```
Changes to workspace.json:

  + spaces.engineering                          (new space)
  + spaces.admin-portal.lists.backlog           (new list)
  ~ spaces.admin-portal.lists.active-projects   (unchanged)
  ~ spaces.admin-portal.lists.ops-tasks         (unchanged)
  ~ spaces.admin-portal.lists.general           (unchanged)
  - spaces.legacy-ops                           (removed from ClickUp — will be removed)

Write these changes to workspace.json? [Y/n]
```

Use `+` for additions, `~` for unchanged, `-` for removals.

If any space or list in the current config was NOT returned by the ClickUp API (state: removed), propose removing it from `workspace.json` and explain why.

### Phase 8: Validate defaultList

If `clickup.defaultList` is set, check whether the corresponding list still exists among the selected lists. If it does not:

```
Warning: The current defaultList "<key>" no longer exists in ClickUp (or was not selected).
Please pick a new default list:

  1. active-projects  → "Active Projects"   (Admin Portal / Projects)
  2. ops-tasks        → "Ops Tasks"         (Admin Portal / Operations)
  3. general          → "General"           (Admin Portal)
  ...

Enter the number of the new default list:
```

Wait for the user to select a new default. Update `defaultList` in the written config.

### Phase 9: Write to workspace.json

After user confirmation, update `workspace.json`:

- Replace `clickup.spaces` with the new spaces map.
- Update `clickup.defaultList` if it changed.
- Preserve all other fields: `teamId`, `token_env`, `chatChannelId`, and any other top-level keys.

The spaces map structure mirrors the existing config format. Each space entry includes its `id` and a `lists` map. Each list entry includes its `id`. Slugify all keys.

Example resulting structure:
```json
{
  "clickup": {
    "teamId": "...",
    "token_env": "CLICKUP_API_TOKEN",
    "defaultList": "active-projects",
    "chatChannelId": "...",
    "spaces": {
      "admin-portal": {
        "id": "abc123",
        "lists": {
          "active-projects": { "id": "list1" },
          "backlog":         { "id": "list2" },
          "ops-tasks":       { "id": "list3" },
          "general":         { "id": "list4" }
        }
      },
      "engineering": {
        "id": "def456",
        "lists": {
          "api-work":    { "id": "list5" },
          "eng-general": { "id": "list6" }
        }
      }
    }
  }
}
```

Confirm success:
```
workspace.json updated. ClickUp config now includes 2 spaces and 6 lists.
```

---

## Error Handling

- **Token not set / 401**: See Auth section above.
- **Empty workspace**: "No spaces found in this workspace. Check that `teamId` is correct."
- **API error for a specific space**: Report the error and continue with remaining spaces.
- **workspace.json not writable**: Report the error and show the intended JSON so the user can apply it manually.
- **Invalid JSON in workspace.json**: Report the parse error and stop — do not overwrite.
