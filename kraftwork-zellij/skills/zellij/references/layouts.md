# Zellij Layouts Reference

Layouts define pane/tab arrangement in KDL format.

## Using Layouts

```bash
zellij --layout /path/to/my-layout.kdl          # Start with layout
zellij --layout compact                          # Built-in layout
zellij action new-tab --layout /path/to/layout.kdl  # Add as new tab
zellij action dump-layout > saved-layout.kdl     # Save current
```

## Basic Examples

### Single Pane

```kdl
layout {
    pane
}
```

### Horizontal Split

```kdl
layout {
    pane split_direction="vertical" {
        pane
        pane
    }
}
```

### Vertical Split

```kdl
layout {
    pane split_direction="horizontal" {
        pane
        pane
    }
}
```

### IDE-like (sidebar + editor + terminal)

```kdl
layout {
    pane split_direction="vertical" {
        pane size="20%"
        pane split_direction="horizontal" {
            pane
            pane size="30%"
        }
    }
}
```

### Multiple Tabs

```kdl
layout {
    tab name="main" {
        pane
    }
    tab name="servers" {
        pane split_direction="horizontal" {
            pane command="htop"
            pane command="tail" {
                args "-f" "/var/log/syslog"
            }
        }
    }
}
```

## Pane Configuration

```kdl
pane size="50%"                                  // Percentage
pane size=20                                     // Fixed rows/columns
pane command="htop"                              // Run command
pane command="tail" {                            // Command with args
    args "-f" "/var/log/syslog"
}
pane command="npm" cwd="/path/to/project" {      // With working dir
    args "run" "dev"
}
pane name="editor" focus=true                    // Name and focus
pane command="task" start_suspended=true          // Start suspended
pane command="ls" close_on_exit=true              // Auto-close
pane borderless=true                             // No border
pane edit="/path/to/file.txt"                    // Open in $EDITOR
pane edit="/path/to/file.txt" line_number=42     // At specific line
```

## Tab Configuration

```kdl
tab name="my-tab" { pane }
tab name="project" cwd="/path/to/project" { pane }
tab name="main" focus=true { pane }
```

## Floating Panes

```kdl
layout {
    pane
    floating_panes {
        pane command="htop" {
            x 10
            y 10
            width "50%"
            height "50%"
        }
        pane {
            x "10%"
            y "10%"
            width "80%"
            height "80%"
            pinned true
        }
    }
}
```

## Templates

### Pane Templates

```kdl
layout {
    pane_template name="shell" { command "zsh" }
    pane_template name="editor" { command "nvim" }

    tab {
        shell
        editor focus=true
    }
}
```

### Tab Templates

```kdl
layout {
    tab_template name="dev-tab" {
        pane split_direction="vertical" {
            pane size="30%" command="nvim"
            pane
        }
    }

    dev-tab name="frontend" cwd="/path/to/frontend"
    dev-tab name="backend" cwd="/path/to/backend"
}
```

### Default Tab Template

```kdl
layout {
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=2 borderless=true {
            plugin location="zellij:status-bar"
        }
    }

    tab name="main" { pane }
}
```

## Built-in Layouts

| Layout | Description |
|--------|-------------|
| `default` | Tab bar + status bar |
| `compact` | Minimal compact bar |
| `disable-status-bar` | No bars |

## Plugins in Layouts

```kdl
pane size=1 borderless=true { plugin location="zellij:tab-bar" }
pane size=2 borderless=true { plugin location="zellij:status-bar" }
pane size="20%" { plugin location="zellij:strider" }          // File browser
pane { plugin location="file:/path/to/plugin.wasm" {
    config_key "config_value"
}}
```

## Layout Directory

- **macOS:** `~/Library/Application Support/org.Zellij-Contributors.Zellij/layouts/`
- **Linux:** `~/.config/zellij/layouts/`

Place `.kdl` files here to use by name: `zellij --layout my-dev`
