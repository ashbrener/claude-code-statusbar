# Claude Code Status Bar

A configurable status bar for [Claude Code](https://claude.ai/code) that shows model, rate limits, context usage, directory, and git branch at a glance.

```
Opus 4.6  5hr:██░░░░░░░░ 12%  ctx:██░░░░░░░░ 24%  Code/myproject  main
```

## Install

```bash
npx claude-code-statusbar
```

Restart Claude Code to see your status bar.

## Configure

Customize your status bar interactively:

```bash
npx claude-code-statusbar configure
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

## Uninstall

```bash
npx claude-code-statusbar uninstall
```

Uninstall restores your previous status bar configuration if one existed before install.

## Requirements

- [Claude Code](https://claude.ai/code) v2.1+
- Node.js 16+ (for npx install/configure)
- `disableAllHooks` must be `false` in `~/.claude/settings.json`

## How it works

The `npx` installer copies a bash script to `~/.claude/statusline-command.sh` and adds the `statusLine` config to `~/.claude/settings.json`. Claude Code runs the script on each render, piping session JSON to stdin.

The script reads an optional `~/.claude/statusline-config.json` for customization, falling back to sensible defaults.

## License

MIT
