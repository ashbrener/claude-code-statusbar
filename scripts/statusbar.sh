#!/usr/bin/env bash
# Claude Code Statusbar — https://github.com/ashbrener/claude-code-statusbar
#
# Displays a configurable statusbar with model, rate limits, context, directory, and git branch.
# Colors shift based on usage thresholds.
#
# Receives JSON on stdin from Claude Code's statusLine command runner.
# Configuration: ~/.claude/statusbar-config.json (falls back to built-in defaults)

input=$(cat)

# Every field below is a jq lookup against stdin. If stdin isn't valid JSON,
# each lookup fails independently and the bar renders half-built (e.g. a bare
# "●" with no model). Degrade to an empty object so defaults apply cleanly.
echo "$input" | jq -e . >/dev/null 2>&1 || input='{}'

# --- Load config ---
USER_CONFIG="${HOME}/.claude/statusbar-config.json"
if [ -f "$USER_CONFIG" ]; then
  config=$(cat "$USER_CONFIG")
  # Same hazard, worse blast radius: a malformed config makes the `.segments`
  # lookup fail, which empties the render loop and blanks the whole statusbar
  # with no visible cause. Fall back to built-in defaults instead.
  echo "$config" | jq -e . >/dev/null 2>&1 || config='{}'
else
  config='{}'
fi

cfg() { echo "$config" | jq -r "$1 // \"$2\""; }

# --- Parse input ---
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // ""')
used_ctx=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')

# Rate limit — pick the window to display.
# `rate.window` config: a literal key (five_hour, seven_day, …) or "auto".
# Auto prefers the shortest-horizon window, since that's the one that will
# throttle you first; falls back to whatever key exists.
rate_window=$(echo "$config" | jq -r '.rate.window // "auto"')
if [ "$rate_window" = "auto" ]; then
  rate_key=$(echo "$input" | jq -r '
    (.rate_limits // {}) as $r
    | ["one_hour","five_hour","daily","seven_day"]
    | map(select(. as $k | $r | has($k)))
    | .[0] // ($r | keys[0]) // empty')
else
  rate_key=$(echo "$input" | jq -r --arg w "$rate_window" \
    '.rate_limits // {} | if has($w) then $w else (keys[0] // empty) end')
fi
rate_pct=""
rate_resets=""
rate_label="rate"
if [ -n "$rate_key" ]; then
  rate_pct=$(echo "$input" | jq -r ".rate_limits.${rate_key}.used_percentage // empty")
  rate_resets=$(echo "$input" | jq -r ".rate_limits.${rate_key}.resets_at // empty")
  case "$rate_key" in
    five_hour)  rate_label="5hr" ;;
    one_hour)   rate_label="1hr" ;;
    daily)      rate_label="day" ;;
    seven_day)  rate_label="7d" ;;
    *)          rate_label="$rate_key" ;;
  esac
fi

# --- Config values ---
SEGMENTS=$(echo "$config" | jq -r '.segments // ["model","thinking_stars","rate","context","directory","branch"] | .[]')
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

# Render seconds-until-reset as a compact duration, e.g. 4h35m / 47m / <1m.
# `resets_at` is a Unix epoch timestamp supplied by Claude Code per rate-limit
# window. Returns empty on missing/non-numeric input so callers can fall back
# to the static window label.
format_countdown() {
  local target="$1" now remain h m
  case "$target" in
    ''|*[!0-9]*) return ;;
  esac
  now=$(date +%s)
  remain=$(( target - now ))
  # Past the reset instant, the window has rolled over but the payload may not
  # have refreshed yet — show 0m rather than a negative duration.
  [ "$remain" -le 0 ] && { echo "0m"; return; }
  h=$(( remain / 3600 ))
  m=$(( (remain % 3600) / 60 ))
  if [ "$h" -gt 0 ]; then
    printf "%dh%02dm" "$h" "$m"
  elif [ "$m" -gt 0 ]; then
    printf "%dm" "$m"
  else
    printf "<1m"
  fi
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

# Legacy fallback: infer a tier from thinking keywords in the latest prompt.
# Only used when `.effort.level` is absent from the payload — i.e. Claude Code
# older than the effort field, or a model that doesn't support the effort
# parameter. Maps onto the same low|medium|high|xhigh|max scale.
detect_thinking_legacy() {
  local tp="$1"
  if [ -z "$tp" ] || [ ! -f "$tp" ]; then
    echo "low"
    return
  fi
  # Scan only the tail of the transcript for performance (most-recent event
  # is at the bottom of the JSONL stream).
  local prompt
  prompt=$(tail -n 200 "$tp" 2>/dev/null | grep '"type":"last-prompt"' | tail -1 \
           | jq -r '.lastPrompt // empty' 2>/dev/null)
  if [ -z "$prompt" ]; then
    echo "low"
    return
  fi
  local p
  p=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')
  # Longest-keyword-first match (specificity wins over breadth).
  if echo "$p" | grep -qE '(ultrathink|ultra-think|megathink|mega-think)'; then
    echo "max"
  elif echo "$p" | grep -qE '(think really hard|think very hard|think a lot)'; then
    echo "xhigh"
  elif echo "$p" | grep -qE '(think harder|think hard|think more)'; then
    echo "high"
  elif echo "$p" | grep -qE '\bthink\b'; then
    echo "medium"
  else
    echo "low"
  fi
}

# Reasoning-effort tier, read straight from the payload Claude Code supplies.
# `.effort.level` is authoritative: it tracks the live session value including
# mid-session /effort changes, and reports ultracode as `xhigh`. The field is
# absent when the model doesn't support the effort parameter, in which case we
# fall back to keyword-sniffing the transcript.
# Pre-computed once — both 'thinking' and 'thinking_stars' segments read it.
thinking_level=$(echo "$input" | jq -r '.effort.level // empty')
case "$thinking_level" in
  low|medium|high|xhigh|max) ;;
  *) thinking_level=$(detect_thinking_legacy "$transcript_path") ;;
esac

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
        # Label modes: "auto" = window name (5hr), "countdown" = time until
        # reset (4h35m), anything else = that literal string. Countdown falls
        # back to the window name if the payload carries no resets_at.
        display_label="$rate_label"
        case "$L_RATE" in
          auto) ;;
          countdown)
            countdown=$(format_countdown "$rate_resets")
            [ -n "$countdown" ] && display_label="$countdown"
            ;;
          *) display_label="$L_RATE" ;;
        esac
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
    thinking)
      # Always-visible dot anchor. Color encodes effort intensity.
      case "$thinking_level" in
        max)    tcol="\033[1;95m" ;;
        xhigh)  tcol="\033[95m"   ;;
        high)   tcol="\033[35m"   ;;
        medium) tcol="\033[2;95m" ;;
        low)    tcol="\033[2m"    ;;
        *)      tcol=""            ;;
      esac
      if [ -n "$tcol" ]; then
        out="${out}${sep}$(printf "%b" "${tcol}·${RESET}")"
        sep="  "
      fi
      ;;
    thinking_stars)
      # Asterisk-count effort indicator. One star per effort level:
      # 1=low, 2=medium, 3=high (default), 4=xhigh, 5=max.
      # Yellow ramp: dim below the default, bright at or above it,
      # bold-bright at the ceiling.
      case "$thinking_level" in
        max)    stars="*****"; tcol="\033[1;93m" ;;
        xhigh)  stars="****";  tcol="\033[93m"   ;;
        high)   stars="***";   tcol="\033[93m"   ;;
        medium) stars="**";    tcol="\033[2;33m" ;;
        low)    stars="*";     tcol="\033[2;33m" ;;
        *)      stars="";      tcol=""            ;;
      esac
      if [ -n "$stars" ]; then
        out="${out}${sep}$(printf "%b" "${tcol}${stars}${RESET}")"
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
      # `git -C ""` silently operates on the process's own working directory,
      # which would report an unrelated repo's branch when the payload carries
      # no current_dir. Require a directory before asking git anything.
      branch=""
      [ -n "$cwd" ] && branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
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
