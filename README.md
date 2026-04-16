# Claude Code Status Bar

A configurable status bar for [Claude Code](https://claude.ai/code) that shows model, rate limits, context usage, directory, and git branch at a glance.

```
Opus 4.6  5hr:██░░░░░░░░ 12%  ctx:██░░░░░░░░ 24%  Code/myproject  main
```

## Install

```bash
git clone https://github.com/ashbrener/claude-code-statusbar.git
cd claude-code-statusbar
bash scripts/install.sh
```

Restart Claude Code to see your status bar.

## Configure

Run the interactive configurator to customize your status bar:

```bash
bash scripts/configure.sh
```

You can choose:

| Option | Choices |
|--------|---------|
| **Segments** | `model`, `rate`, `context`, `directory`, `branch` — pick which to show and in what order |
| **Bar style** | `██░░` (default), `■■□□`, `●●○○`, `##--`, or custom characters |
| **Bar width** | Number of characters (default: 10) |
| **Directory** | Relative to `~/` (default), absolute, or strip a custom prefix |
| **Thresholds** | When bars turn yellow/red (default: 50%/80%) |

Configuration is saved to `~/.claude/statusline-config.json`. Without a config file, the default style is used.

### Example configs

**Minimal — model + context only:**
```json
{
  "segments": ["model", "context"]
}
```

**Dots with tight thresholds:**
```json
{
  "segments": ["model", "rate", "context", "branch"],
  "bar": { "filled": "●", "empty": "○", "width": 8 },
  "thresholds": { "warning": 40, "critical": 70 }
}
```

**Everything, wide bars:**
```json
{
  "segments": ["model", "rate", "context", "directory", "branch"],
  "bar": { "filled": "█", "empty": "░", "width": 15 }
}
```

## What it shows

| Segment | Source | Default Color |
|---------|--------|---------------|
| Model | `model.display_name` | Cyan |
| Rate limit | Auto-detected window (`five_hour`→`5hr`, etc.) | Magenta |
| Context window | `context_window.used_percentage` | Blue |
| Directory | `workspace.current_dir` relative to `$HOME` | Dim |
| Git branch | Current branch via `git symbolic-ref` | Green |

Colors shift at configurable thresholds (default **50%** yellow, **80%** red).

## Requirements

- [Claude Code](https://claude.ai/code) v2.1+
- [jq](https://jqlang.github.io/jq/)
- `disableAllHooks` must be `false` in `~/.claude/settings.json`

## Uninstall

```bash
bash scripts/uninstall.sh
```

Uninstall restores your previous status bar configuration if one existed before install.

## Files

```
claude-code-statusbar/
├── scripts/
│   ├── install.sh        # Backs up existing config, installs statusline
│   ├── uninstall.sh      # Restores previous config from backup
│   ├── configure.sh      # Interactive style configurator
│   ├── statusline.sh     # The status bar script
│   └── defaults.json     # Default configuration
└── README.md
```

After install, these are created in `~/.claude/`:
- `statusline-command.sh` — the active script
- `statusline-config.json` — your customizations (if configured)
- `.statusbar-backup/` — backup of previous statusline (if any)

## License

MIT
