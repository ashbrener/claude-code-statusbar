---
name: statusbar
description: Install, configure, or remove the Claude Code statusbar — model, rate limits, context window, directory, git branch
---

# Statusbar

A single command to manage the Claude Code statusbar. Detect current state and act accordingly.

## Step 1: Detect current state

Check if the statusbar is installed:
- Does `~/.claude/statusline-command.sh` exist?
- Does `~/.claude/settings.json` contain a `statusLine` key?
- Does `~/.claude/statusbar-config.json` exist?

## Step 2: Route based on state

### If NOT installed

Tell the user the statusbar is not installed and show what it looks like:

```
Opus 4.6  5hr:██░░░░░░░░ 12%  ctx:██░░░░░░░░ 24%  Code/myproject  main
```

Ask: **Install now?**

If yes, follow the install steps from `/statusbar-install`.

### If already installed

Show current configuration and a live preview of what the statusbar looks like.

Then ask what they'd like to do:

1. **Configure** — change segments, order, bar style, labels, display mode, thresholds
2. **Reset** — delete config and restore defaults
3. **Uninstall** — remove statusbar and restore previous config

#### Configure

Walk through options interactively. Only ask about what the user wants to change — don't force them through every option.

Available settings:

| Setting | Default | Options |
|---------|---------|---------|
| Segments | model, rate, context, directory, branch | Pick which to show and reorder |
| Display mode | used | `used` (24% consumed) or `remaining` (76% available) |
| Color ramp | same | `same` (brightens in gauge color) or `red` (shifts to yellow/red) |
| Bar style | `██░░` | `■■□□`, `●●○○`, `##--`, or custom characters |
| Bar width | 10 | Any number |
| Labels | rate: auto, context: ctx | Custom strings (e.g. ctx → window) |
| Thresholds | 50% / 80% | When colors shift |
| Directory | relative to ~/ | Absolute, or strip custom prefix |

Save changes to `~/.claude/statusbar-config.json`. Only include keys the user customized.

#### Reset

Delete `~/.claude/statusbar-config.json`. The statusbar script falls back to built-in defaults.

#### Uninstall

Follow the steps from `/statusbar-uninstall`. Restore any backed-up configuration.

## Important

- The statusbar script is installed at `~/.claude/statusline-command.sh` (Claude's expected filename)
- The config is at `~/.claude/statusbar-config.json` (our config)
- The settings.json key is `statusLine` (Claude's key name)
- After any changes, remind the user to restart Claude Code
- `jq` is required at runtime for the statusbar script
