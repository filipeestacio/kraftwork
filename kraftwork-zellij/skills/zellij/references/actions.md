# Zellij Actions Reference

Complete reference for all `zellij action` commands.

## Text Input

### write-chars

```bash
zellij action write-chars "text to send"
zellij action write-chars $'echo hello\n'       # With newline (executes)
zellij action write-chars $'\x03'               # Ctrl+C (SIGINT)
zellij action write-chars $'\x04'               # Ctrl+D (EOF)
zellij action write-chars $'\x1a'               # Ctrl+Z (SIGTSTP)
zellij action write-chars $'\x1b'               # Escape
```

### write

```bash
zellij action write 104 101 108 108 111         # "hello" in ASCII
```

## Screen Capture

### dump-screen

```bash
zellij action dump-screen /path/to/output.txt
zellij action dump-screen --full /path/to/output.txt    # Full scrollback
```

### dump-layout

```bash
zellij action dump-layout > my-layout.kdl
```

### edit-scrollback

```bash
zellij action edit-scrollback                   # Opens in $EDITOR
```

## Pane Actions

### new-pane

```bash
zellij action new-pane
zellij action new-pane --direction right|down|left|up
zellij action new-pane --floating
zellij action new-pane --floating --x 10 --y 10 --width 50% --height 50%
zellij action new-pane --in-place
zellij action new-pane -- htop                  # With command
zellij action new-pane --floating -- python3
zellij action new-pane --close-on-exit -- ls -la
zellij action new-pane --start-suspended -- long-command
zellij action new-pane --stacked
```

### close-pane

```bash
zellij action close-pane
```

### rename-pane

```bash
zellij action rename-pane "my-pane-name"
zellij action undo-rename-pane
```

### toggle-pane-embed-or-floating

```bash
zellij action toggle-pane-embed-or-floating     # Float ↔ tiled
```

### toggle-floating-panes

```bash
zellij action toggle-floating-panes
```

### toggle-fullscreen

```bash
zellij action toggle-fullscreen
```

### toggle-pane-frames

```bash
zellij action toggle-pane-frames
```

### toggle-pane-pinned

```bash
zellij action toggle-pane-pinned                # Always on top
```

### stack-panes

```bash
zellij action stack-panes -- terminal_1 terminal_2 plugin_1
```

## Tab Actions

### new-tab

```bash
zellij action new-tab
zellij action new-tab --name "servers"
zellij action new-tab --layout /path/to/layout.kdl
zellij action new-tab --cwd /path/to/dir
```

### close-tab

```bash
zellij action close-tab
```

### go-to-tab

```bash
zellij action go-to-tab 1                       # 1-based index
```

### go-to-tab-name

```bash
zellij action go-to-tab-name "servers"
zellij action go-to-tab-name --create "new-tab" # Create if missing
```

### Navigation

```bash
zellij action go-to-next-tab
zellij action go-to-previous-tab
```

### rename-tab

```bash
zellij action rename-tab "new-name"
zellij action undo-rename-tab
```

### move-tab

```bash
zellij action move-tab left|right
```

### toggle-active-sync-tab

```bash
zellij action toggle-active-sync-tab            # Sync input to all panes
```

### query-tab-names

```bash
zellij action query-tab-names                   # Outputs to stdout
```

## Focus & Navigation

```bash
zellij action move-focus left|right|up|down
zellij action move-focus-or-tab left|right      # Switch tab at edge
zellij action focus-next-pane
zellij action focus-previous-pane
zellij action move-pane                         # Rotate position
zellij action move-pane right|down
zellij action move-pane-backwards
```

## Resize Actions

```bash
zellij action resize increase left|right|up|down
zellij action resize decrease left|right|up|down
zellij action change-floating-pane-coordinates \
  --pane-id terminal_1 --x 10% --y 10% --width 80% --height 80%
```

## Scroll Actions

```bash
zellij action scroll-up
zellij action scroll-down
zellij action scroll-to-top
zellij action scroll-to-bottom
zellij action page-scroll-up
zellij action page-scroll-down
zellij action half-page-scroll-up
zellij action half-page-scroll-down
```

## Mode Switching

```bash
zellij action switch-mode normal|locked|pane|tab|resize|scroll|session
```

## Session Actions

```bash
zellij action detach
zellij action rename-session "new-name"
zellij action switch-session other-session
zellij action switch-session other-session --tab-position 2 --pane-id terminal_1
zellij action list-clients
```

## Plugin Actions

```bash
zellij action launch-plugin zellij:strider
zellij action launch-plugin --floating file:/path/to/plugin.wasm
zellij action launch-or-focus-plugin zellij:strider
zellij action start-or-reload-plugin zellij:status-bar
zellij action pipe --plugin file:/path/to/plugin.wasm --name my_pipe -- "data"
```

## Layout Actions

```bash
zellij action previous-swap-layout
zellij action next-swap-layout
```

## Utility

```bash
zellij action clear                             # Clear pane buffers
```

## Targeting Specific Sessions

All actions accept `-s session-name`:

```bash
zellij -s my-session action write-chars "hello"
zellij -s my-session action dump-screen /tmp/out.txt
zellij -s my-session action new-pane --floating
```

## Control Character Reference

| Character | Code | Description |
|-----------|------|-------------|
| Ctrl+C | `$'\x03'` | Interrupt (SIGINT) |
| Ctrl+D | `$'\x04'` | EOF |
| Ctrl+Z | `$'\x1a'` | Suspend (SIGTSTP) |
| Escape | `$'\x1b'` | Escape key |
| Enter | `$'\n'` | Newline |
| Tab | `$'\t'` | Tab |
| Backspace | `$'\x7f'` | Delete previous char |
