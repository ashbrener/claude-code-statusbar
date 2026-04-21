#!/usr/bin/env bash
# Claude Code Statusbar — https://github.com/ashbrener/claude-code-statusbar
#
# Displays a configurable statusbar with model, rate limits, context, directory, and git branch.
# Colors shift based on usage thresholds.
#
# Receives JSON on stdin from Claude Code's statusLine command runner.
# Configuration: ~/.claude/statusbar-config.json (falls back to built-in defaults)

input=$(cat)

# --- Load config ---
USER_CONFIG="${HOME}/.claude/statusbar-config.json"
if [ -f "$USER_CONFIG" ]; then
  config=$(cat "$USER_CONFIG")
else
  config='{}'
fi

cfg() { echo "$config" | jq -r "$1 // \"$2\""; }

# --- Parse input ---
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // ""')
used_ctx=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Rate limit — detect first available window dynamically
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

# --- Config values ---
SEGMENTS=$(echo "$config" | jq -r '.segments // ["model","rate","context","directory","branch"] | .[]')
C_MODEL=$(cfg '.colors.model' '96')
C_RATE=$(cfg '.colors.rate' '95')
C_CTX=$(cfg '.colors.context' '94')
C_DIR=$(cfg '.colors.directory' '2')
C_BRANCH=$(cfg '.colors.branch' '92')
C_VPN=$(cfg '.colors.vpn' '92')
C_WARN=$(cfg '.colors.warning' '93')
C_CRIT=$(cfg '.colors.critical' '91')
C_LABEL=$(cfg '.colors.label' '2')
T_WARN=$(cfg '.thresholds.warning' '50')
T_CRIT=$(cfg '.thresholds.critical' '80')
BAR_FILL=$(cfg '.bar.filled' '█')
BAR_EMPTY=$(cfg '.bar.empty' '░')
BAR_WIDTH=$(cfg '.bar.width' '10')
L_RATE=$(cfg '.labels.rate' 'auto')
L_CTX=$(cfg '.labels.context' 'ctx')
DISPLAY_MODE=$(cfg '.display.mode' 'used')
COLOR_RAMP=$(cfg '.display.color_ramp' 'same')
DIR_REL=$(cfg '.directory.relative_to' 'home')

RESET="\033[0m"

color() { printf "\033[%sm" "$1"; }

threshold_color() {
  local val=$(printf "%.0f" "$1") base="$2"
  if [ "$COLOR_RAMP" = "same" ]; then
    [ "$val" -ge "$T_CRIT" ] && printf "\033[1;%sm" "$base" && return
    [ "$val" -ge "$T_WARN" ] && color "$base" && return
    printf "\033[2;%sm" "$base"
  else
    [ "$val" -ge "$T_CRIT" ] && color "$C_CRIT" && return
    [ "$val" -ge "$T_WARN" ] && color "$C_WARN" && return
    color "$base"
  fi
}

display_pct() {
  local used="$1"
  if [ "$DISPLAY_MODE" = "remaining" ]; then
    echo "$(( 100 - $(printf "%.0f" "$used") ))"
  else
    printf "%.0f" "$used"
  fi
}

color_pct() { printf "%.0f" "$1"; }

bar() {
  local pct=$(printf "%.0f" "$1")
  local filled=$(( pct * BAR_WIDTH / 100 ))
  local empty=$(( BAR_WIDTH - filled ))
  local b="" i
  for (( i=0; i<filled; i++ )); do b="${b}${BAR_FILL}"; done
  for (( i=0; i<empty; i++ )); do b="${b}${BAR_EMPTY}"; done
  echo "$b"
}

short_dir() {
  local d="$1"
  case "$DIR_REL" in
    home) d="${d#$HOME/}" ;;
    none) ;;
    *)    d="${d#$DIR_REL/}" ;;
  esac
  echo "$d"
}

# --- Build output from segments ---
out=""
sep=""

for seg in $SEGMENTS; do
  case "$seg" in
    vpn)
      if [[ "$OSTYPE" == darwin* ]]; then
        vpn_active=$(scutil --nc list 2>/dev/null | grep -c '(Connected)')
        if [ "$vpn_active" -gt 0 ]; then
          out="${out}${sep}$(printf "%b" "$(color "$C_VPN")◉${RESET}")"
        else
          out="${out}${sep}$(printf "%b" "\033[2;${C_VPN}m○${RESET}")"
        fi
        sep="  "
      fi
      ;;
    model)
      out="${out}${sep}$(printf "%b" "$(color "$C_MODEL")● ${model}${RESET}")"
      sep="  "
      ;;
    rate)
      if [ -n "$rate_pct" ]; then
        col=$(threshold_color "$(color_pct "$rate_pct")" "$C_RATE")
        show_pct=$(display_pct "$rate_pct")
        display_label="$rate_label"
        [ "$L_RATE" != "auto" ] && display_label="$L_RATE"
        out="${out}${sep}$(printf "%b" "$(color "$C_LABEL")${display_label}:${RESET}${col}$(bar "$show_pct") ${show_pct}%${RESET}")"
        sep="  "
      fi
      ;;
    context)
      if [ -n "$used_ctx" ]; then
        col=$(threshold_color "$(color_pct "$used_ctx")" "$C_CTX")
        show_pct=$(display_pct "$used_ctx")
        out="${out}${sep}$(printf "%b" "$(color "$C_LABEL")${L_CTX}:${RESET}${col}$(bar "$show_pct") ${show_pct}%${RESET}")"
        sep="  "
      fi
      ;;
    directory)
      if [ -n "$cwd" ]; then
        out="${out}${sep}$(printf "%b" "$(color "$C_DIR")$(short_dir "$cwd")${RESET}")"
        sep="  "
      fi
      ;;
    branch)
      branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
      if [ -n "$branch" ]; then
        # Git status indicators
        indicators=""
        git_status=$(git -C "$cwd" --no-optional-locks status --porcelain=v1 2>/dev/null)
        if [ -n "$git_status" ]; then
          # Staged (index has changes)
          echo "$git_status" | grep -q '^[MARCDU]' && indicators="${indicators}+"
          # Modified (unstaged changes)
          echo "$git_status" | grep -q '^.[MD]' && indicators="${indicators}!"
          # Untracked
          echo "$git_status" | grep -q '^??' && indicators="${indicators}?"
          # Deleted
          echo "$git_status" | grep -q '^[[:space:]]D\|^D' && indicators="${indicators}✘"
          # Conflicts
          echo "$git_status" | grep -q '^UU\|^AA\|^DD' && indicators="${indicators}×"
        fi
        # Stashed
        git -C "$cwd" --no-optional-locks stash list 2>/dev/null | grep -q . && indicators="${indicators}⚑"
        # Ahead / behind / diverged
        counts=$(git -C "$cwd" --no-optional-locks rev-list --left-right --count "@{upstream}...HEAD" 2>/dev/null)
        if [ -n "$counts" ]; then
          behind=$(echo "$counts" | awk '{print $1}')
          ahead=$(echo "$counts" | awk '{print $2}')
          [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ] && indicators="${indicators}⇕" ||
          { [ "$ahead" -gt 0 ] && indicators="${indicators}⇡"; [ "$behind" -gt 0 ] && indicators="${indicators}⇣"; }
        fi
        # Render
        branch_str="${branch}"
        [ -n "$indicators" ] && branch_str="${branch} ${indicators}"
        out="${out}${sep}$(printf "%b" "$(color "$C_BRANCH")ᚦ ${branch_str}${RESET}")"
        sep="  "
      fi
      ;;
  esac
done

printf "%b\n" "$out"
