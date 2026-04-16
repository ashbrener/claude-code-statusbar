---
name: statusbar-install
description: Install the Claude Code statusbar — copies statusline script and configures settings.json
---

# Statusbar: Install

Install the Claude Code statusbar with sensible defaults.

## Steps

### 1. Check prerequisites

- Verify `~/.claude/` directory exists (Claude Code is installed)
- Check that `jq` is available (needed by the statusline script at runtime)
- If `jq` is missing, tell the user: `brew install jq` (macOS) or `sudo apt install jq` (Linux)

### 2. Backup existing statusline

If `~/.claude/statusline-command.sh` already exists:
- Create `~/.claude/.statusbar-backup/` directory
- Copy the existing script there

If `~/.claude/settings.json` has a `statusLine` key:
- Save `{"statusLine": <current value>}` to `~/.claude/.statusbar-backup/statusline-settings.json`

Tell the user what was backed up so they know uninstall will restore it.

### 3. Install the statusline script

Write the following script to `~/.claude/statusline-command.sh` and make it executable (`chmod +x`):

```bash
#!/usr/bin/env bash
input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // ""')
used_ctx=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

rate_key=$(echo "$input" | jq -r '.rate_limits | keys[0] // empty')
rate_pct=""
rate_label="rate"
if [ -n "$rate_key" ]; then
  rate_pct=$(echo "$input" | jq -r ".rate_limits.${rate_key}.used_percentage // empty")
  case "$rate_key" in
    five_hour)  rate_label="5hr" ;;
    one_hour)   rate_label="1hr" ;;
    daily)      rate_label="day" ;;
    seven_day)  rate_label="7d" ;;
    *)          rate_label="$rate_key" ;;
  esac
fi

RESET="\033[0m"; DIM="\033[2m"
CYAN="\033[96m"; B_GREEN="\033[92m"; B_MAGENTA="\033[95m"
B_BLUE="\033[94m"; B_YELLOW="\033[93m"; B_RED="\033[91m"

threshold_color() {
  local val=$(printf "%.0f" "$1") base="$2"
  [ "$val" -ge 80 ] && printf "$B_RED" && return
  [ "$val" -ge 50 ] && printf "$B_YELLOW" && return
  printf "\033[${base}m"
}

bar() {
  local filled=$(( $(printf "%.0f" "$1") / 10 )) empty=$(( 10 - filled ))
  local b="" i
  for (( i=0; i<filled; i++ )); do b="${b}█"; done
  for (( i=0; i<empty; i++ )); do b="${b}░"; done
  echo "$b"
}

out="$(printf "%b" "${CYAN}${model}${RESET}")"

if [ -n "$rate_pct" ]; then
  col=$(threshold_color "$rate_pct" "95")
  out="${out}$(printf "  %b" "${DIM}${rate_label}:${RESET}${col}$(bar "$rate_pct") $(printf '%.0f' "$rate_pct")%${RESET}")"
fi

if [ -n "$used_ctx" ]; then
  col=$(threshold_color "$used_ctx" "94")
  out="${out}$(printf "  %b" "${DIM}ctx:${RESET}${col}$(bar "$used_ctx") $(printf '%.0f' "$used_ctx")%${RESET}")"
fi

branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
[ -n "$cwd" ] && out="${out}$(printf "  %b" "${DIM}${cwd#$HOME/}${RESET}")"
[ -n "$branch" ] && out="${out}$(printf "  %b" "${B_GREEN}${branch}${RESET}")"

printf "%b\n" "$out"
```

### 4. Update settings.json

Read `~/.claude/settings.json` and add or update the `statusLine` key:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

Do not overwrite other settings — merge the key in.

### 5. Check for disableAllHooks

If `disableAllHooks` is `true` in settings.json, warn the user:

> **Warning:** `disableAllHooks` is set to `true`. The statusbar won't display until this is set to `false`. Want me to change it?

If the user agrees, set it to `false`.

### 6. Done

Tell the user to restart Claude Code. Show the expected output:

```
Opus 4.6  5hr:██░░░░░░░░ 12%  ctx:██░░░░░░░░ 24%  Code/myproject  main
```

Mention they can run `/statusbar-configure` to customize or `/statusbar-uninstall` to remove.
