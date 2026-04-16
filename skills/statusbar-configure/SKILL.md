---
name: statusbar-configure
description: Customize the Claude Code statusbar — segments, order, colors, bar style, thresholds
---

# Statusbar: Configure

Customize the Claude Code statusbar by modifying `~/.claude/statusbar-config.json` and `~/.claude/statusline-command.sh`.

## Step 1: Show current configuration

Read `~/.claude/statusbar-config.json` if it exists. If not, show the defaults:

| Setting | Default |
|---------|---------|
| Segments | model, rate, context, directory, branch |
| Bar style | `██░░░░░░░░` |
| Bar width | 10 |
| Directory | Relative to `~/` |
| Warning threshold | 50% |
| Critical threshold | 80% |
| Rate color | Bright magenta |
| Context color | Bright blue |
| Branch color | Bright green |

Show a preview of the current statusbar appearance.

## Step 2: Ask what the user wants to change

Present the options and ask which they'd like to modify. They can change one thing or several:

### Segments
- **Available:** `model`, `rate`, `context`, `directory`, `branch`
- User can pick which to show and in what order
- Example: "just model and context" → `["model", "context"]`

### Bar style
- `██░░` (default blocks)
- `■■□□` (squares)
- `●●○○` (circles)
- `##--` (ASCII)
- Custom characters

### Bar width
- Number of characters (default 10)

### Directory display
- Relative to `~/` (default)
- Full absolute path
- Relative to a custom prefix (e.g. strip `~/Code/`)

### Display mode
- **used** (default): shows percentage consumed (e.g. `ctx: 24%` = 24% used)
- **remaining**: shows percentage left (e.g. `ctx: 76%` = 76% available)
- This affects both the bar fill and the percentage number
- Color always tracks usage — high usage = brighter/hotter regardless of display mode

### Color ramp
- **same** (default): gauge stays its own color, brightening as usage increases (dim → normal → bold)
- **red**: traditional approach — shifts from base color to yellow at warning, red at critical

### Labels
- **Rate limit label:** `auto` (default — derived from the rate limit window, e.g. `5hr`) or a custom string
- **Context label:** `ctx` (default) or a custom string like `window`, `tokens`, etc.
- Example: user says "change ctx to window" → set `labels.context` to `window`

### Color thresholds
- Warning (yellow): default 50%
- Critical (red): default 80%

### Colors (ANSI codes)
- Model: 96 (bright cyan)
- Rate: 95 (bright magenta)
- Context: 94 (bright blue)
- Directory: 2 (dim)
- Branch: 92 (bright green)
- Warning: 93 (bright yellow)
- Critical: 91 (bright red)

## Step 3: Update the config

Save the updated configuration to `~/.claude/statusbar-config.json`:

```json
{
  "segments": ["model", "rate", "context", "directory", "branch"],
  "colors": {
    "model": "96",
    "rate": "95",
    "context": "94",
    "directory": "2",
    "branch": "92",
    "warning": "93",
    "critical": "91",
    "label": "2"
  },
  "thresholds": {
    "warning": 50,
    "critical": 80
  },
  "bar": {
    "filled": "█",
    "empty": "░",
    "width": 10
  },
  "directory": {
    "relative_to": "home"
  }
}
```

Only include keys the user has customized. Omitted keys fall back to defaults.

## Step 4: Update the statusbar script

Read the current `~/.claude/statusline-command.sh`. If it's the config-driven version (checks for `statusbar-config.json`), no script update is needed.

If it's the older hardcoded version, replace it with the config-driven version from `/statusbar-install`.

## Step 5: Preview and confirm

Show what the statusbar will look like with the new settings. Remind the user to restart Claude Code.

If they want to reset to defaults, delete `~/.claude/statusbar-config.json` — the script falls back to built-in defaults automatically.
