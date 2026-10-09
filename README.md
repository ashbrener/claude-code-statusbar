# Claude Code Statusbar

A configurable statusbar for [Claude Code](https://claude.ai/code) that keeps you informed without breaking your flow.

```
● Claude Opus 5  ***  2h14m:███░░░░░░░ 31%  7d:64%  ctx:████░░░░░░ 42%  cache:47m  Code/myproject  ᚦ main !?
```

## Why?

Claude Code doesn't show you how close you are to hitting rate limits or running out of context window — two things that directly affect your session. You find out when it's too late: a rate limit error kills your momentum, or context gets compacted and Claude loses track of what you were doing.

This statusbar gives you a persistent, at-a-glance view of:

- **Rate limits** — how much you've burned, labelled with the time left until the window resets
- **Weekly limit** — the seven-day window alongside the five-hour one, so it doesn't surprise you
- **Context window** — measured against your auto-compact window, turning red as compaction approaches
- **Prompt cache** — how long the cached conversation stays warm, and what the next message costs once it goes cold
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
| **Segments** | `model`, `thinking_stars`, `rate`, `weekly`, `context`, `cache`, `directory`, `branch` (default set) plus opt-in `vpn` and `thinking` — pick which to show and in what order |
| **Rate label** | `countdown` (time to reset, e.g. `4h35m`, the default), `auto` (window name, e.g. `5hr`), or custom text |
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

**Window name instead of the countdown to reset:**
```json
{
  "labels": { "rate": "auto" }
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
  "segments": ["vpn", "model", "thinking_stars", "rate", "context", "thinking", "directory", "branch"],
  "bar": { "filled": "█", "empty": "░", "width": 15 }
}
```

**Weekly limit instead of the 5-hour one:**
```json
{
  "rate": { "window": "seven_day" }
}
```

## What it shows

| Segment | Source | Default Color |
|---------|--------|---------------|
| VPN | macOS `scutil --nc list` (◉ connected / ○ disconnected) | Green |
| Model | `model.display_name`, prefixed with `●` | Cyan |
| Thinking (stars) | 1–5 asterisks for the session's reasoning effort | Yellow ramp |
| Rate limit | `rate_limits.<window>.used_percentage` | Magenta |
| Weekly limit | `rate_limits.seven_day.used_percentage`, text only | Magenta |
| Context window | Tokens in context as a share of the auto-compact window | Blue, red near compaction |
| Prompt cache | `prompt_cache` — time left while warm, re-cache cost when cold | Teal, red when cold |
| Directory | `workspace.current_dir` relative to `$HOME` | Dim |
| Git branch | Current branch with `ᚦ` glyph + dirty-state indicators | Green |

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
| `countdown` *(default)* | `4h35m`, `47m`, `<1m`, `3d04h` | Time until the window resets |
| `auto` | `5hr`, `7d`, … | Derived from the window name |
| *any other string* | that string | e.g. `"quota"` |

Countdown reads `resets_at` — a Unix timestamp Claude Code supplies per window — and formats the remaining time. Hours are dropped under an hour (`47m`); minutes are zero-padded when hours are shown (`9h05m`) so the field doesn't change width as it counts down. A day or more out, which only the weekly window reaches, it shows days and hours (`3d04h`). Time is truncated, never rounded up, so it is never optimistic. If a window carries no usable `resets_at`, the label falls back to the window name.

> **Note**: the countdown recomputes on each statusbar render. Claude Code renders on activity, and the installer also sets `"refreshInterval": 60` on the `statusLine` block in `~/.claude/settings.json`, so the bar re-runs every 60 seconds while the session is idle. If you installed before that was added, reinstall or add the key yourself; without it the countdown reads stale when idle and jumps when you next interact.

The whole segment is omitted when `rate_limits` is absent, which is the case before the first API response of a session and for non-subscription auth.

### Weekly limit segment

`weekly` shows the seven-day window as plain text (`7d:64%`) next to the main rate gauge. The `rate` segment picks the window that will throttle you first, which is normally the five-hour one, so without this the weekly limit stays out of sight until it is spent.

It follows the same thresholds, display mode and colour as the rate gauge. It is omitted when the payload has no seven-day window, and when `rate` is already showing that window.

```json
{
  "weekly": { "bar": true },
  "labels": { "weekly": "countdown" }
}
```

`weekly.bar` draws a full gauge instead of text only. `labels.weekly` takes the same three modes as `labels.rate`.

### Context segment

Claude Code reports context usage as a share of the model's **full** window. If you compact earlier than that — say a 250k auto-compact window on a 1M model — that figure reads 25% at the moment your conversation is compacted, and the gauge never reaches its warning colours.

So the gauge measures tokens in context against the **auto-compact window** instead: 100% means compaction is due. At 80% it turns red, whatever colour ramp you use.

The window is found in this order:

1. `context.compact_at` in the statusbar config, if it is a token count
2. the `CLAUDE_CODE_AUTO_COMPACT_WINDOW` environment variable
3. `modelSettings.<model>.autoCompactWindow`, then `autoCompactWindow`, in `~/.claude/settings.json` — what `/autocompact` saves

If none of those gives a number, the gauge falls back to the full window as before. A window set only in project settings or with the `--autocompact` flag is not detected; set `context.compact_at` yourself in that case.

```json
{
  "context": { "compact_at": 250000, "alert_at": 70 }
}
```

| Key | Default | Meaning |
|---|---|---|
| `context.compact_at` | `"auto"` | `"auto"`, a token count, or `"off"` to measure against the full window |
| `context.alert_at` | `80` | Percentage at which the gauge turns red; `0` disables it |

### Prompt cache segment

Claude Code caches the conversation so each message only pays full price for what is new. The cache expires after five minutes or an hour of inactivity; Claude Code chooses the lifetime. Once it has expired, the next message re-processes the whole conversation.

| Renders | Meaning |
|---|---|
| `cache:47m` | Warm. 47 minutes until it expires. Turns yellow in the last 5 minutes. |
| `cache:cold 412k` | Expired. The next message re-caches about 412k tokens. |
| `cache:47m 2miss` | Two requests this session re-processed content the cache already held. |

A long session left idle past the expiry is the expensive case: one message then costs a full re-read. `cold` with a large number is the cue to compact or start a fresh session instead of carrying on.

Requires Claude Code 2.1.251 or later. The segment is omitted on older versions, before the first API response, and on providers that don't report cache usage. Subagent requests are not counted. `cache.warn_minutes` sets when the countdown turns yellow; `labels.cache` renames it.

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

An additional `thinking` segment renders a single colored `·` (magenta ramp) at any chosen position in the bar — useful if you want the indicator anchored mid-bar instead of (or alongside) the stars. Opt-in via config:

```json
{
  "segments": ["model", "thinking_stars", "rate", "context", "thinking", "directory", "branch"]
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

The installer copies a bash script to `~/.claude/statusbar-command.sh` and adds the `statusLine` config to `~/.claude/settings.json`. Claude Code runs the script on each render and once a minute, piping [session JSON](https://code.claude.com/docs/en/statusline) to stdin.

The script reads an optional `~/.claude/statusbar-config.json` for customization, falling back to sensible defaults. Both the script and the config are re-read on every render, so **configuration changes take effect immediately** — no restart needed. Only install and uninstall, which touch `settings.json`, require restarting Claude Code.

## Codex version

Using OpenAI Codex? See [Codex Statusbar](https://github.com/eitanlevinai-stack/codex-statusbar), a standalone companion project that brings quota bars, reset countdowns, context, directory, and Git state to the Codex CLI.

## License

MIT
