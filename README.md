# Claude Code Statusbar

A configurable statusbar for [Claude Code](https://claude.ai/code) that keeps you informed without breaking your flow.

```
● Claude Opus 4.7  5hr:███░░░░░░░ 31%  ctx:████░░░░░░ 42%  Code/myproject   main !?
```

## Why?

Claude Code doesn't show you how close you are to hitting rate limits or running out of context window — two things that directly affect your session. You find out when it's too late: a rate limit error kills your momentum, or context gets compacted and Claude loses track of what you were doing.

This statusbar gives you a persistent, at-a-glance view of:

- **Rate limits** — so you can pace yourself or wrap up before you're throttled
- **Context window** — so you know when to `/compact` or start a new session
- **Model, directory, branch** — so you always know where you are
- **Git status indicators** — modified, staged, untracked, ahead/behind, and more
- **VPN indicator** (optional, macOS) — see at a glance whether your VPN is connected

It's configurable — choose which segments to show, customize labels and bar styles, display as "used" or "remaining", and pick your own color scheme.

## Install

```bash
npx github:ashbrener/claude-code-statusbar
```

Restart Claude Code to see your statusbar.

## Configure

### Option 1: Inside Claude Code (recommended)

Install the skill, then use `/statusbar` to configure interactively:

```bash
npx skills add ashbrener/claude-code-statusbar
```

Then inside Claude Code, type `/statusbar` to install, configure, reset, or uninstall.

### Option 2: From the terminal

```bash
npx github:ashbrener/claude-code-statusbar configure
```

You can choose:

| Option | Choices |
|--------|---------|
| **Segments** | `vpn`, `model`, `rate`, `context`, `directory`, `branch` — pick which to show and in what order |
| **Bar style** | `██░░` (default), `■■□□`, `●●○○`, `##--`, or custom characters |
| **Bar width** | Number of characters (default: 10) |
| **Directory** | Relative to `~/` (default), absolute, or strip a custom prefix |
| **Display mode** | `used` (24% consumed) or `remaining` (76% available) |
| **Color ramp** | `same` (brightens in gauge color) or `red` (shifts to yellow/red) |
| **Labels** | Rename gauges — e.g. `ctx` → `window`, or override rate label |
| **Thresholds** | When bars change intensity (default: 50%/80%) |

Configuration is saved to `~/.claude/statusbar-config.json`. Without a config file, the default style is used.

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
| VPN | macOS `scutil --nc list` (◉ connected / ○ disconnected) | Green |
| Model | `model.display_name`, prefixed with `●` | Cyan |
| Rate limit | Auto-detected window (`five_hour`→`5hr`, etc.) | Magenta |
| Context window | `context_window.used_percentage` | Blue |
| Directory | `workspace.current_dir` relative to `$HOME` | Dim |
| Git branch | Current branch with Nerd Font  glyph + dirty-state indicators | Green |

Colors shift at configurable thresholds (default **50%** yellow, **80%** red).

### Git status indicators

When the working tree is dirty, the branch segment appends indicators:

| Symbol | Meaning |
|--------|---------|
| `+` | Staged changes |
| `!` | Modified (unstaged) |
| `?` | Untracked files |
| `✘` | Deleted |
| `×` | Merge conflicts |
| `⚑` | Stashed changes |
| `⇡` | Ahead of upstream |
| `⇣` | Behind upstream |
| `⇕` | Diverged (both ahead and behind) |

Example: ` main !+⇡` means you're on `main` with modified files, staged changes, and unpushed commits.

> The branch glyph `` requires a [Nerd Font](https://www.nerdfonts.com/). If you don't have one installed, edit `scripts/statusbar.sh` and swap it for `ᚦ` or `⎇`.

## Uninstall

```bash
npx github:ashbrener/claude-code-statusbar uninstall
```

Uninstall restores your previous statusbar configuration if one existed before install.

## How it works

The installer copies a bash script to `~/.claude/statusbar-command.sh` and adds the `statusLine` config to `~/.claude/settings.json`. Claude Code runs the script on each render, piping session JSON to stdin.

The script reads an optional `~/.claude/statusbar-config.json` for customization, falling back to sensible defaults.

## License

MIT
