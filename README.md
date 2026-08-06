# Claude Code Statusbar

A configurable statusbar for [Claude Code](https://claude.ai/code) that keeps you informed without breaking your flow.

```
● Claude Opus 5  4h35m:███░░░░░░░ 31%  ctx:████░░░░░░ 42%  Code/myproject  ᚦ main !?  ***
```

## Why?

Claude Code doesn't show you how close you are to hitting rate limits or running out of context window — two things that directly affect your session. You find out when it's too late: a rate limit error kills your momentum, or context gets compacted and Claude loses track of what you were doing.

This statusbar gives you a persistent, at-a-glance view of:

- **Rate limits** — how much you've burned, and optionally a live countdown to when the window resets
- **Context window** — so you know when to `/compact` or start a new session
- **Reasoning effort** — which effort level the session is actually running at
- **Model, directory, branch** — so you always know where you are
- **Git status indicators** — modified, staged, untracked, ahead/behind, and more
- **VPN indicator** (optional, macOS) — see at a glance whether your VPN is connected

It's configurable — choose which segments to show, customize labels and bar styles, display as "used" or "remaining", and pick your own color scheme.

## Install

```bash
npx github:ashbrener/claude-code-statusbar
```

Restart Claude Code to see your statusbar.

Requires `jq` at runtime (`brew install jq` / `apt install jq`).

## Configure

### Option 1: Inside Claude Code (recommended)

The installer also drops a `/statusbar` skill into `~/.claude/skills/`. After restarting Claude Code, just type:

```
/statusbar
```

…to install, configure, reset, or uninstall interactively.

### Option 2: From the terminal

```bash
npx github:ashbrener/claude-code-statusbar configure
```

You can choose:

| Option | Choices |
|--------|---------|
| **Segments** | `model`, `rate`, `context`, `directory`, `branch`, `thinking_stars` (default set) plus opt-in `vpn` and `thinking` — pick which to show and in what order |
| **Rate label** | `auto` (window name, e.g. `5hr`), `countdown` (time to reset, e.g. `4h35m`), or custom text |
| **Rate window** | `auto` (shortest horizon available) or an explicit window (`five_hour`, `seven_day`, …) |
| **Bar style** | `██░░` (default), `■■□□`, `●●○○`, `##--`, or custom characters |
| **Bar width** | Number of characters (default: 10) |
| **Directory** | Relative to `~/` (default), absolute, or strip a custom prefix |
| **Display mode** | `used` (24% consumed) or `remaining` (76% available) |
| **Color ramp** | `same` (brightens in gauge color) or `red` (shifts to yellow/red) |
| **Labels** | Rename the context gauge — e.g. `ctx` → `window` |
| **Thresholds** | When bars change intensity (default: 50%/80%) |

Configuration is saved to `~/.claude/statusbar-config.json`. Every key is optional; anything you omit falls back to a built-in default, so **no config file at all is a perfectly valid setup**. If the file is present but malformed, the statusbar ignores it and renders defaults rather than disappearing.

### Example configs

**Minimal — model + context only:**
```json
{
  "segments": ["model", "context"]
}
```

**Countdown to rate-limit reset instead of the window name:**
```json
{
  "labels": { "rate": "countdown" }
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

**Everything including the opt-in dot anchor + wide bars:**
```json
{
  "segments": ["vpn", "model", "rate", "context", "thinking", "directory", "branch", "thinking_stars"],
  "bar": { "filled": "█", "empty": "░", "width": 15 }
}
```

**Weekly limit instead of the 5-hour one:**
```json
{
  "rate": { "window": "seven_day" },
  "labels": { "rate": "countdown" }
}
```

## What it shows

| Segment | Source | Default Color |
|---------|--------|---------------|
| VPN | macOS `scutil --nc list` (◉ connected / ○ disconnected) | Green |
| Model | `model.display_name`, prefixed with `●` | Cyan |
| Rate limit | `rate_limits.<window>.used_percentage` | Magenta |
| Context window | `context_window.used_percentage` | Blue |
| Directory | `workspace.current_dir` relative to `$HOME` | Dim |
| Git branch | Current branch with `ᚦ` glyph + dirty-state indicators | Green |
| Thinking (stars) | 1–5 asterisks for the session's reasoning effort | Yellow ramp |

Colors shift at configurable thresholds (default **50%**, **80%**).

### Rate limit segment

Claude Code reports rate-limit usage per window — typically `five_hour` and `seven_day` for Claude.ai subscribers. The segment picks a window, draws a gauge, and labels it.

**Window selection** defaults to `auto`, which prefers the shortest horizon present (`one_hour` → `five_hour` → `daily` → `seven_day`) on the grounds that the nearest limit is the one that will throttle you first. Override it explicitly:

```json
{ "rate": { "window": "seven_day" } }
```

**The label** has three modes, set via `labels.rate`:

| Mode | Renders | Notes |
|---|---|---|
| `auto` *(default)* | `5hr`, `7d`, … | Derived from the window name |
| `countdown` | `4h35m`, `47m`, `<1m` | Time until the window resets |
| *any other string* | that string | e.g. `"quota"` |

Countdown reads `resets_at` — a Unix timestamp Claude Code supplies per window — and formats the remaining time. Hours are dropped under an hour (`47m`); minutes are zero-padded when hours are shown (`9h05m`) so the field doesn't change width as it counts down. Time is truncated, never rounded up, so it is never optimistic. If a window carries no usable `resets_at`, the label falls back to the window name.

> **Note**: the countdown recomputes on each statusbar render, which Claude Code triggers on activity — not on a timer. It is accurate whenever you're working, but will read stale if you leave the session idle, then jump when you next interact.

The whole segment is omitted when `rate_limits` is absent, which is the case before the first API response of a session and for non-subscription auth.

### Reasoning-effort indicator

`thinking_stars` renders **1–5 asterisks** showing the effort level the session is running at. It reads `effort.level` from the payload Claude Code provides, so it reflects the live value — including mid-session `/effort` changes.

| `effort.level` | Stars | Color |
|---|---|---|
| `low` | `*` | Dim yellow |
| `medium` | `**` | Dim yellow |
| `high` *(default on most models)* | `***` | Bright yellow |
| `xhigh` | `****` | Bright yellow |
| `max` | `*****` | Bold bright yellow |

`ultracode` is a Claude Code setting rather than a model effort level and reports as `xhigh`, so it shows four stars.

**History.** This segment originally worked by parsing the session transcript and keyword-matching your prompt for `think` / `think hard` / `ultrathink`, because the `statusLine` JSON contract didn't expose the thinking budget ([claude-code#23929](https://github.com/anthropics/claude-code/issues/23929)). That was always an approximation: it guessed from your wording rather than reading the real setting, so it reported five stars for a prompt containing "ultrathink" even when effort was actually `low`, and it could never see an `/effort` change.

Claude Code now provides `effort.level` directly, and the segment reads it. The keyword parser is retained only as a fallback for when the field is absent — older Claude Code versions, or models that don't support the effort parameter — mapped onto the same five-level scale.

#### Optional: `thinking` (dot) segment

An additional `thinking` segment renders a single colored `·` (magenta ramp) at any chosen position in the bar — useful if you want the indicator anchored mid-bar instead of (or alongside) the right-edge stars. Opt-in via config:

```json
{
  "segments": ["model", "rate", "context", "thinking", "directory", "branch", "thinking_stars"]
}
```

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

Example: `ᚦ main !+⇡` means you're on `main` with modified files, staged changes, and unpushed commits.

> The branch glyph is `ᚦ`, which renders in most fonts. If you have a [Nerd Font](https://www.nerdfonts.com/) installed, you can swap it for the branch symbol at `U+E0A0` by editing `scripts/statusbar.sh`.

## Uninstall

```bash
npx github:ashbrener/claude-code-statusbar uninstall
```

Uninstall restores your previous statusbar configuration if one existed before install.

## How it works

The installer copies a bash script to `~/.claude/statusbar-command.sh` and adds the `statusLine` config to `~/.claude/settings.json`. Claude Code runs the script on each render, piping [session JSON](https://code.claude.com/docs/en/statusline) to stdin.

The script reads an optional `~/.claude/statusbar-config.json` for customization, falling back to sensible defaults. Both the script and the config are re-read on every render, so **configuration changes take effect immediately** — no restart needed. Only install and uninstall, which touch `settings.json`, require restarting Claude Code.

## License

MIT
