---
name: zellij
description: "Control Zellij terminal multiplexer from Claude Code. Use when managing terminal sessions, opening task directories in new tabs, running commands in panes, capturing terminal output, or when user mentions zellij, terminal multiplexer, floating panes, or session layouts."
---

# Zellij Skill

Control Zellij programmatically from Claude Code — session management, pane orchestration, and workspace-aware tab creation.

## Environment Detection

Before any Zellij action, check if we're inside a session:

```bash
if [ -n "$ZELLIJ" ]; then
  echo "Inside Zellij session: $ZELLIJ_SESSION_NAME"
else
  echo "Not inside a Zellij session"
fi
```

When inside a session, all `zellij action` commands target the current session by default. Only use `-s <name>` when targeting a different session.

## Workspace Task Tab

When starting work on a new task (e.g., after `kraft-start` creates a worktree), open the task directory in a new Zellij tab named after the task:

```bash
TASK_DIR="$1"
TAB_NAME="$2"

zellij action new-tab --name "$TAB_NAME" --cwd "$TASK_DIR"
```

### Integration with kraft-start

After a worktree is created at `tasks/<TICKET>-<description>/`:
1. Extract the tab name from the directory basename (e.g., `MES-1234-add-retry-logic`)
2. Create a new tab with that name pointing to the task directory
3. The user lands in the new tab, ready to work

```bash
TASK_DIR="/Users/example/Developer/myworkspace/tasks/MES-1234-add-retry-logic"
TAB_NAME=$(basename "$TASK_DIR")

zellij action new-tab --name "$TAB_NAME" --cwd "$TASK_DIR"
```

### Resuming a task

When resuming work on an existing worktree, check if a tab already exists:

```bash
TAB_NAME=$(basename "$TASK_DIR")
EXISTING_TAB=$(zellij action query-tab-names | grep -n "$TAB_NAME")

if [ -n "$EXISTING_TAB" ]; then
  TAB_INDEX=$(echo "$EXISTING_TAB" | cut -d: -f1)
  zellij action go-to-tab "$TAB_INDEX"
else
  zellij action new-tab --name "$TAB_NAME" --cwd "$TASK_DIR"
fi
```

## Quickstart

```bash
zellij                              # Start new session (auto-name)
zellij -s my-session                # Start named session
zellij ls                           # List sessions
zellij attach my-session            # Attach to session
zellij attach -c my-session         # Attach or create
zellij kill-session my-session      # Kill session
```

## Sending Text to Panes

```bash
zellij action write-chars "echo hello"          # Send text
zellij action write-chars $'echo hello\n'       # Send + execute
zellij action write-chars $'\x03'               # Ctrl+C
zellij action write-chars $'\x04'               # Ctrl+D
```

## Capturing Output

```bash
zellij action dump-screen /tmp/output.txt           # Visible content
zellij action dump-screen --full /tmp/output.txt    # Full scrollback
```

## Running Commands in New Panes

```bash
zellij run -- htop                                  # New pane
zellij run --floating -- python3                    # Floating pane
zellij run --direction down -- tail -f log.txt      # Directional
zellij run --close-on-exit -- ls -la                # Auto-close
```

## Pane Management

```bash
zellij action new-pane                              # Auto-place
zellij action new-pane --direction right             # Directional
zellij action new-pane --floating                   # Floating
zellij action close-pane                            # Close focused

zellij action move-focus left|right|up|down         # Navigate
zellij action toggle-floating-panes                 # Toggle floats
zellij action toggle-fullscreen                     # Fullscreen

zellij action resize increase left                  # Resize
zellij action resize decrease right
```

## Tab Management

```bash
zellij action new-tab                               # New tab
zellij action new-tab --name "servers"              # Named tab
zellij action new-tab --name "work" --cwd /path     # With directory

zellij action go-to-tab 1                           # By index (1-based)
zellij action go-to-tab-name "servers"              # By name
zellij action go-to-next-tab                        # Next
zellij action go-to-previous-tab                    # Previous

zellij action rename-tab "new-name"                 # Rename
zellij action close-tab                             # Close
zellij action query-tab-names                       # List all names
```

## Session Management

```bash
zellij list-sessions                                # List with details
zellij ls --short                                   # Short format
zellij action detach                                # Detach
zellij action rename-session "new-name"             # Rename
zellij action switch-session other-session          # Switch
zellij kill-all-sessions --yes                      # Kill all
```

## Mode Switching

```bash
zellij action switch-mode locked      # Disable keybindings
zellij action switch-mode normal      # Default mode
zellij action switch-mode pane        # Pane manipulation
zellij action switch-mode tab         # Tab manipulation
zellij action switch-mode resize      # Resize mode
zellij action switch-mode scroll      # Scroll mode
```

## Layouts

```bash
zellij --layout /path/to/layout.kdl              # Start with layout
zellij --layout compact                           # Built-in compact
zellij action dump-layout > saved.kdl             # Save current
zellij action new-tab --layout /path/to/layout.kdl  # New tab from layout
```

See [references/layouts.md](references/layouts.md) for KDL layout syntax.

## Tips

1. **Session targeting**: Use `-s session-name` when automating across sessions
2. **Newlines**: `$'\n'` executes commands; without it, text is just typed
3. **Control chars**: `$'\x03'` = Ctrl+C, `$'\x04'` = Ctrl+D, `$'\x1a'` = Ctrl+Z
4. **Output capture**: `--full` includes scrollback; without it, only visible content
5. **Floating panes**: Great for temporary tasks — toggle with `toggle-floating-panes`
6. **Tab names**: Use `query-tab-names` to check before creating duplicates

## Reference

- [Actions Reference](references/actions.md) — All `zellij action` commands
- [Layouts Reference](references/layouts.md) — KDL layout syntax
- [Official Docs](https://zellij.dev/documentation/)
